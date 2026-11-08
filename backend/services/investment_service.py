from __future__ import annotations

import asyncio
import json
import math
from pathlib import Path
import re
from datetime import date, datetime, timedelta, timezone
from typing import Any

import httpx
import numpy as np
import pandas as pd
import yfinance as yf
from bs4 import BeautifulSoup
from sqlalchemy import func
from sqlalchemy.orm import Session

from config import INVESTMENT_API_TIMEOUT_SECONDS, TWELVEDATA_API_KEY
from models.expense_orm import Expense
from models.budget_orm import Budget
from models.fd_rate_orm import FDRate
from models.gold_price_orm import GoldPrice
from models.goals_portfolio_orm import GoalsPortfolio
from models.investment_asset_orm import InvestmentAsset
from models.investment_option_orm import InvestmentOption
from models.lic_policy_orm import LICPolicy
from models.mutual_fund_orm import MutualFund
from models.stock_orm import Stock
from models.user_portfolio_orm import UserPortfolio

CACHE_TTL_HOURS = 6
MF_SCHEME_LIST_URL = "https://api.mfapi.in/mf"
AMFI_NAV_URL = "https://portal.amfiindia.com/spages/NAVOpen.txt"
TWELVEDATA_STOCKS_LIST_URL = "https://api.twelvedata.com/stocks"
TWELVEDATA_QUOTE_URL = "https://api.twelvedata.com/quote"
TWELVEDATA_PRICE_URL = "https://api.twelvedata.com/price"
GOLD_SPOT_URL = "https://api.metals.live/v1/spot/gold"

FD_SOURCES: dict[str, str] = {
    "SBI": "https://sbi.co.in/web/interest-rates/deposit-rates/retail-domestic-term-deposits",
    "HDFC": "https://www.hdfcbank.com/personal/save/deposits/fixed-deposit-interest-rate",
    "ICICI": "https://www.icicibank.com/personal-banking/deposits/fixed-deposit/fd-interest-rates.page",
    "Axis Bank": "https://www.axisbank.com/retail/deposits/fixed-deposits/fixed-deposit-interest-rate",
}

LIC_PRODUCTS_URLS = [
    "https://licindia.in/web/guest/insurance-plan",
    "https://licindia.in/web/guest/endowment-plans",
    "https://licindia.in/web/guest/term-assurance-plans",
]

MARKET_BASKETS: dict[str, list[str]] = {
    "index_funds": ["^NSEI"],
    "government_bonds": ["^TNX"],
    "etfs": ["NIFTYBEES.NS", "BANKBEES.NS"],
}

LEGACY_OPTION_TYPE_MAP = {"fixed_deposit": "fixed_deposits"}
LIC_DATA_PATH = Path(__file__).resolve().parents[1] / "data" / "lic_policies.json"


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


def _is_risky(volatility: float) -> str:
    # Accept either decimal (0.24) or percentage (24.0) volatility input.
    vol_pct = volatility * 100 if volatility <= 1.5 else volatility
    if vol_pct > 40:
        return "High"
    if vol_pct >= 20:
        return "Medium"
    return "Low"


def _to_pct(change_ratio: float) -> float:
    return round(change_ratio * 100, 2)


def _safe_float(value: Any) -> float | None:
    try:
        if value is None:
            return None
        if isinstance(value, str):
            cleaned = value.replace(",", "").replace("%", "").strip()
            if not cleaned:
                return None
            return float(cleaned)
        return float(value)
    except (TypeError, ValueError):
        return None


def _safe_int(value: Any) -> int | None:
    try:
        if value is None:
            return None
        if isinstance(value, str):
            cleaned = value.replace(",", "").strip()
            if not cleaned:
                return None
            return int(float(cleaned))
        return int(value)
    except (TypeError, ValueError):
        return None


def _is_fresh(ts: datetime | None) -> bool:
    if ts is None:
        return False
    normalized = ts.replace(tzinfo=timezone.utc) if ts.tzinfo is None else ts.astimezone(timezone.utc)
    return normalized >= _utcnow() - timedelta(hours=CACHE_TTL_HOURS)


async def _fetch_json(url: str, *, params: dict[str, Any] | None = None) -> Any:
    timeout = httpx.Timeout(INVESTMENT_API_TIMEOUT_SECONDS)
    async with httpx.AsyncClient(timeout=timeout) as client:
        response = await client.get(url, params=params)
        response.raise_for_status()
        return response.json()


async def _fetch_html(url: str) -> str:
    timeout = httpx.Timeout(INVESTMENT_API_TIMEOUT_SECONDS)
    async with httpx.AsyncClient(timeout=timeout, follow_redirects=True) as client:
        response = await client.get(url)
        response.raise_for_status()
        return response.text


def _calc_return_and_vol(history: pd.DataFrame) -> tuple[float | None, float | None, float | None]:
    if history.empty:
        return None, None, None
    close = history["Close"].dropna()
    if close.empty:
        return None, None, None
    start = float(close.iloc[0])
    end = float(close.iloc[-1])
    expected_return = _to_pct((end - start) / start) if start > 0 else None
    daily_returns = close.pct_change().dropna()
    volatility = float(daily_returns.std() * math.sqrt(252)) if not daily_returns.empty else None
    latest = float(close.iloc[-1])
    return expected_return, volatility, latest


def _upsert_asset_cache(
    db: Session,
    *,
    asset_name: str,
    asset_type: str,
    risk_level: str | None,
    expected_return: float | None,
    price: float | None,
) -> None:
    row = (
        db.query(InvestmentAsset)
        .filter(
            InvestmentAsset.asset_name == asset_name,
            InvestmentAsset.asset_type == asset_type,
        )
        .first()
    )
    risk = risk_level or "Unknown"
    exp = expected_return if expected_return is not None else 0.0
    if row:
        row.risk_level = risk
        row.expected_return = exp
        row.price = price
        row.last_updated = _utcnow()
        return

    db.add(
        InvestmentAsset(
            asset_name=asset_name,
            asset_type=asset_type,
            risk_level=risk,
            expected_return=exp,
            price=price,
            last_updated=_utcnow(),
        )
    )


def _sync_legacy_options_from_assets(db: Session) -> None:
    assets = db.query(InvestmentAsset).all()
    grouped: dict[str, list[InvestmentAsset]] = {}
    for asset in assets:
        grouped.setdefault(asset.asset_type, []).append(asset)

    for asset_type, rows in grouped.items():
        if not rows:
            continue
        option_type = LEGACY_OPTION_TYPE_MAP.get(asset_type, asset_type)
        best = max(rows, key=lambda r: r.expected_return or 0)
        options = db.query(InvestmentOption).filter(InvestmentOption.type == option_type).all()
        for option in options:
            option.expected_return = float(best.expected_return or 0)
            option.risk_level = best.risk_level or "Unknown"
    db.commit()


def _extract_percentages(text: str) -> list[float]:
    matches = re.findall(r"(\d{1,2}(?:\.\d{1,2})?)\s*%", text)
    return [float(v) for v in matches if 0 < float(v) < 20]


def _extract_currency(text: str) -> float | None:
    matches = re.findall(r"(?:Rs\.?|INR|\u20B9)\s*([\d,]+(?:\.\d+)?)", text, flags=re.IGNORECASE)
    if not matches:
        return None
    values = []
    for token in matches:
        parsed = _safe_float(token)
        if parsed is not None:
            values.append(parsed)
    return min(values) if values else None


def _is_real_stock_symbol(symbol: str) -> bool:
    normalized = symbol.strip().upper()
    if not normalized:
        return False
    if "TEST" in normalized:
        return False
    if len(normalized) > 15:
        return False
    return bool(re.match(r"^[A-Z0-9.\-_/]+$", normalized))


def _to_yf_symbol(symbol: str) -> str:
    normalized = symbol.strip().upper()
    if normalized.endswith(".NSE"):
        return f"{normalized[:-4]}.NS"
    if normalized.endswith(".NS"):
        return normalized
    return f"{normalized}.NS"


def _parse_gold_spot(payload: Any) -> float | None:
    try:
        if isinstance(payload, list) and payload:
            first = payload[0]
            if isinstance(first, dict):
                for key in ("gold", "price", "xau"):
                    value = _safe_float(first.get(key))
                    if value is not None:
                        return value
            if isinstance(first, (list, tuple)) and len(first) > 1:
                return _safe_float(first[1])
        if isinstance(payload, dict):
            for key in ("gold", "price", "xau"):
                value = _safe_float(payload.get(key))
                if value is not None:
                    return value
    except Exception:
        return None
    return None


def _asset_profile(asset_type: str) -> dict[str, str]:
    profiles = {
        "mutual_funds": {
            "description": "Professionally managed pooled investments across diversified securities.",
            "benefits": "Diversification, disciplined investing, and liquidity in open-ended plans.",
            "who_should_invest": "Investors seeking diversified long-term growth with managed risk.",
            "lock_in_period": "Varies by scheme",
        },
        "stocks": {
            "description": "Direct equity participation in listed companies with market-linked returns.",
            "benefits": "High long-term growth potential and ownership in businesses.",
            "who_should_invest": "Investors comfortable with volatility and long-term horizons.",
            "lock_in_period": "No mandatory lock-in",
        },
        "gold": {
            "description": "Market-linked exposure to gold as a portfolio diversifier.",
            "benefits": "Inflation hedge and diversification against equity volatility.",
            "who_should_invest": "Investors seeking diversification and defensive allocation.",
            "lock_in_period": "No mandatory lock-in",
        },
        "fixed_deposit": {
            "description": "Bank deposit product with predefined tenure and fixed interest rate.",
            "benefits": "Capital stability and predictable returns.",
            "who_should_invest": "Conservative investors prioritizing stability over high growth.",
            "lock_in_period": "As per bank tenure",
        },
        "government_bonds": {
            "description": "Debt securities issued by government with periodic interest payments.",
            "benefits": "Lower credit risk and stable income profile.",
            "who_should_invest": "Risk-aware investors seeking relatively stable fixed-income exposure.",
            "lock_in_period": "As per bond maturity",
        },
        "index_funds": {
            "description": "Funds designed to track benchmark indices passively.",
            "benefits": "Low-cost diversification aligned with broad market performance.",
            "who_should_invest": "Long-term investors preferring passive, diversified strategies.",
            "lock_in_period": "Varies by fund",
        },
        "etfs": {
            "description": "Exchange-traded funds offering market exposure with intraday liquidity.",
            "benefits": "Diversification, transparency, and exchange-traded flexibility.",
            "who_should_invest": "Investors seeking low-cost market exposure with trading flexibility.",
            "lock_in_period": "No mandatory lock-in",
        },
        "lic": {
            "description": "Insurance-linked long-term savings plans offered by LIC.",
            "benefits": "Life cover and long-term savings discipline.",
            "who_should_invest": "Investors prioritizing life cover with structured savings.",
            "lock_in_period": "As per policy terms",
        },
    }
    return profiles.get(
        asset_type,
        {
            "description": "Market-linked investment instrument.",
            "benefits": "Portfolio diversification potential.",
            "who_should_invest": "Investors aligned with product risk and time horizon.",
            "lock_in_period": "Varies",
        },
    )


def _enrich_asset_row(
    *,
    asset_type: str,
    asset_name: str,
    risk_level: str | None,
    expected_return: float | None,
    minimum_investment: float | None,
    data_source: str,
    lock_in_period: str | None = None,
    price: float | None = None,
) -> dict[str, Any]:
    profile = _asset_profile(asset_type)
    return {
        "asset_name": asset_name,
        "price": price if price is not None else 0.0,
        "risk_level": risk_level or "Unknown",
        "expected_return": expected_return if expected_return is not None else 0.0,
        "description": profile["description"],
        "benefits": profile["benefits"],
        "who_should_invest": profile["who_should_invest"],
        "lock_in_period": lock_in_period or profile["lock_in_period"],
        "minimum_investment": minimum_investment if minimum_investment is not None else 0.0,
        "data_source": data_source,
    }


def _mutual_fund_payload_from_row(row: MutualFund, *, source: str, data_source: str) -> dict[str, Any]:
    return {
        "scheme_code": row.scheme_code,
        "scheme_name": row.scheme_name,
        "latest_nav": row.nav,
        "one_year_return": row.one_year_return,
        "risk_level": row.risk_level,
        "source": source,
        **_enrich_asset_row(
            asset_type="mutual_funds",
            asset_name=row.scheme_name,
            risk_level=row.risk_level,
            expected_return=row.one_year_return,
            minimum_investment=None,
            data_source=data_source,
            price=row.nav,
        ),
    }


def _lic_payload_from_row(row: LICPolicy, *, source: str, data_source: str, expected_return: float) -> dict[str, Any]:
    return {
        "policy_name": row.policy_name,
        "lock_in_period": row.lock_in_period,
        "minimum_investment": row.minimum_investment,
        "policy_benefits": row.policy_benefits,
        "maturity_rules": row.maturity_rules,
        "risk_level": row.risk_level,
        "source_url": row.source_url,
        "source": source,
        **_enrich_asset_row(
            asset_type="lic",
            asset_name=row.policy_name,
            risk_level=row.risk_level,
            expected_return=expected_return,
            minimum_investment=row.minimum_investment,
            data_source=data_source,
            lock_in_period=row.lock_in_period,
            price=0.0,
        ),
    }


async def _fetch_text(url: str) -> str:
    timeout = httpx.Timeout(INVESTMENT_API_TIMEOUT_SECONDS)
    async with httpx.AsyncClient(timeout=timeout, follow_redirects=True) as client:
        response = await client.get(url)
        response.raise_for_status()
        return response.text


def _upsert_mutual_fund(
    db: Session,
    *,
    scheme_code: str,
    scheme_name: str,
    latest_nav: float | None,
    one_year_return: float | None,
    risk_level: str,
) -> MutualFund:
    row = db.query(MutualFund).filter(MutualFund.scheme_code == scheme_code).first()
    if row:
        row.scheme_name = scheme_name
        row.nav = latest_nav
        row.one_year_return = one_year_return
        row.risk_level = risk_level
        row.last_updated = _utcnow()
        return row

    row = MutualFund(
        scheme_code=scheme_code,
        scheme_name=scheme_name,
        nav=latest_nav,
        one_year_return=one_year_return,
        risk_level=risk_level,
        last_updated=_utcnow(),
    )
    db.add(row)
    return row


def _parse_amfi_nav_rows(text: str, *, limit: int) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    seen_codes: set[str] = set()
    for raw_line in text.splitlines():
        line = raw_line.strip()
        if not line or ";" not in line:
            continue
        parts = [part.strip() for part in line.split(";")]
        if len(parts) < 6:
            continue
        scheme_code = parts[0]
        scheme_name = parts[3]
        latest_nav = _safe_float(parts[4])
        if not scheme_code.isdigit() or not scheme_name or latest_nav is None:
            continue
        if scheme_code in seen_codes:
            continue
        seen_codes.add(scheme_code)
        rows.append(
            {
                "scheme_code": scheme_code,
                "scheme_name": scheme_name,
                "latest_nav": latest_nav,
                "one_year_return": None,
                "risk_level": "Unknown",
                "source": "amfi",
                "data_source": AMFI_NAV_URL,
            }
        )
        if len(rows) >= limit:
            break
    return rows


async def _fetch_lic_candidates(limit: int) -> list[dict[str, Any]]:
    candidates: list[dict[str, Any]] = []
    seen_names: set[str] = set()

    for url in LIC_PRODUCTS_URLS:
        try:
            html = await _fetch_html(url)
        except Exception:
            continue

        soup = BeautifulSoup(html, "lxml")
        for table in soup.find_all("table"):
            rows = table.find_all("tr")
            if not rows:
                continue

            headers = [cell.get_text(" ", strip=True).lower() for cell in rows[0].find_all(["th", "td"])]
            product_index = next((idx for idx, header in enumerate(headers) if "product name" in header), None)
            if product_index is None:
                continue

            for tr in rows[1:]:
                cells = tr.find_all(["td", "th"])
                if len(cells) <= product_index:
                    continue
                policy_name = cells[product_index].get_text(" ", strip=True)
                if not policy_name or policy_name in seen_names:
                    continue

                seen_names.add(policy_name)
                candidates.append(
                    {
                        "policy_name": policy_name,
                        "lock_in_period": None,
                        "minimum_investment": None,
                        "policy_benefits": "Official LIC plan listing sourced from LIC India.",
                        "maturity_rules": "Refer to the official LIC product page for brochure, policy document, and terms.",
                        "risk_level": "Low",
                        "source_url": url,
                        "expected_return": 0.0,
                    }
                )
                if len(candidates) >= limit:
                    return candidates

    return candidates

async def get_mutual_funds(db: Session, limit: int = 30) -> list[dict[str, Any]]:
    recent = db.query(MutualFund).order_by(MutualFund.last_updated.desc()).all()
    if recent and all(_is_fresh(row.last_updated) for row in recent):
        return [_mutual_fund_payload_from_row(row, source="cache", data_source="MFAPI (cached)") for row in recent[:limit]]

    output: list[dict[str, Any]] = []
    try:
        schemes = await _fetch_json(MF_SCHEME_LIST_URL)
    except Exception:
        schemes = None

    if isinstance(schemes, list):
        candidates = [s for s in schemes if isinstance(s, dict) and s.get("schemeCode")][: max(limit * 6, 100)]
        for scheme in candidates:
            if len(output) >= limit:
                break
            code = str(scheme.get("schemeCode"))
            name = str(scheme.get("schemeName", "Unknown Scheme"))
            try:
                detail = await _fetch_json(f"{MF_SCHEME_LIST_URL}/{code}")
            except Exception:
                continue

            rows = detail.get("data", []) if isinstance(detail, dict) else []
            if not rows:
                continue

            latest_nav = _safe_float(rows[0].get("nav"))
            latest_date_raw = rows[0].get("date")
            latest_date = datetime.strptime(latest_date_raw, "%d-%m-%Y").date() if latest_date_raw else None
            one_year_nav = None
            if latest_date:
                target = latest_date - timedelta(days=365)
                for row in rows:
                    d_raw = row.get("date")
                    if not d_raw:
                        continue
                    try:
                        d_val = datetime.strptime(d_raw, "%d-%m-%Y").date()
                    except ValueError:
                        continue
                    if d_val <= target:
                        one_year_nav = _safe_float(row.get("nav"))
                        break

            one_year_return = None
            if latest_nav is not None and one_year_nav and one_year_nav > 0:
                one_year_return = _to_pct((latest_nav - one_year_nav) / one_year_nav)
                volatility_proxy = abs(one_year_return) / 100
                risk_level = _is_risky(volatility_proxy)
            else:
                risk_level = "Unknown"

            row = _upsert_mutual_fund(
                db,
                scheme_code=code,
                scheme_name=name,
                latest_nav=latest_nav,
                one_year_return=one_year_return,
                risk_level=risk_level,
            )
            _upsert_asset_cache(
                db,
                asset_name=name,
                asset_type="mutual_funds",
                risk_level=risk_level,
                expected_return=one_year_return,
                price=latest_nav,
            )
            output.append(_mutual_fund_payload_from_row(row, source="mfapi", data_source="MFAPI"))

    if not output:
        try:
            amfi_text = await _fetch_text(AMFI_NAV_URL)
            amfi_rows = _parse_amfi_nav_rows(amfi_text, limit=limit)
        except Exception:
            amfi_rows = []

        for item in amfi_rows:
            row = _upsert_mutual_fund(
                db,
                scheme_code=item["scheme_code"],
                scheme_name=item["scheme_name"],
                latest_nav=item["latest_nav"],
                one_year_return=item["one_year_return"],
                risk_level=item["risk_level"],
            )
            _upsert_asset_cache(
                db,
                asset_name=item["scheme_name"],
                asset_type="mutual_funds",
                risk_level=item["risk_level"],
                expected_return=item["one_year_return"],
                price=item["latest_nav"],
            )
            output.append(_mutual_fund_payload_from_row(row, source=item["source"], data_source=item["data_source"]))

    if output:
        db.commit()
        return output[:limit]

    db.rollback()
    return [
        _mutual_fund_payload_from_row(row, source="cache-fallback", data_source="MFAPI/AMFI (stale cache)")
        for row in recent[:limit]
    ]


async def get_stocks(db: Session, limit: int = 50) -> list[dict[str, Any]]:
    recent = db.query(Stock).order_by(Stock.last_updated.desc()).all()
    valid_cached = [row for row in recent if _is_real_stock_symbol(row.symbol or "")]
    if valid_cached and all(_is_fresh(row.last_updated) for row in valid_cached):
        return [
            {
                "symbol": row.symbol,
                "company_name": row.name,
                "live_price": row.price,
                "change_percent": row.change_percent,
                "volume": row.volume,
                "market_cap": row.market_cap,
                "expected_return": row.expected_return,
                "risk_level": row.risk_level,
                "source": "cache",
                **_enrich_asset_row(
                    asset_type="stocks",
                    asset_name=row.name or row.symbol,
                    risk_level=row.risk_level,
                    expected_return=row.expected_return,
                    minimum_investment=None,
                    data_source="TwelveData + yfinance (cached)",
                    price=row.price,
                ),
            }
            for row in valid_cached[:limit]
        ]

    if not TWELVEDATA_API_KEY:
        return []

    list_params = [
        {"exchange": "NSE", "country": "India", "apikey": TWELVEDATA_API_KEY},
        {"exchange": "NSE", "apikey": TWELVEDATA_API_KEY},
        {"country": "India", "apikey": TWELVEDATA_API_KEY},
    ]
    stock_rows: list[dict[str, Any]] = []
    seen_symbols: set[str] = set()
    for params in list_params:
        try:
            list_payload = await _fetch_json(TWELVEDATA_STOCKS_LIST_URL, params=params)
        except Exception:
            continue
        rows = list_payload.get("data", []) if isinstance(list_payload, dict) else []
        for row in rows:
            symbol = str(row.get("symbol") or "").strip().upper()
            if not symbol or symbol in seen_symbols:
                continue
            seen_symbols.add(symbol)
            stock_rows.append(row)
        if len(stock_rows) >= max(limit * 3, 100):
            break
    # Remove synthetic/test-like symbols and keep practical equity candidates.
    filtered_rows = []
    for row in stock_rows:
        symbol = str(row.get("symbol") or "").strip().upper()
        if not _is_real_stock_symbol(symbol):
            continue
        filtered_rows.append(row)

    output: list[dict[str, Any]] = []
    for row in filtered_rows:
        if len(output) >= limit:
            break
        symbol = str(row.get("symbol") or "").strip()
        if not symbol:
            continue
        company_name = str(row.get("name") or symbol)
        quote = {}
        try:
            quote = await _fetch_json(TWELVEDATA_QUOTE_URL, params={"symbol": symbol, "apikey": TWELVEDATA_API_KEY})
        except Exception:
            quote = {}

        price = _safe_float(quote.get("close") or quote.get("price"))
        if price is None:
            try:
                price_payload = await _fetch_json(
                    TWELVEDATA_PRICE_URL,
                    params={"symbol": symbol, "apikey": TWELVEDATA_API_KEY},
                )
                price = _safe_float(price_payload.get("price"))
            except Exception:
                price = None
        change_percent = _safe_float(quote.get("percent_change"))
        volume = _safe_int(quote.get("volume"))
        market_cap = _safe_float(quote.get("market_cap"))

        yf_symbol = _to_yf_symbol(symbol)
        try:
            history = await asyncio.to_thread(lambda s=yf_symbol: yf.Ticker(s).history(period="1y"))
        except Exception:
            history = pd.DataFrame()
        ticker_info: dict[str, Any] = {}
        if history.empty or price is None:
            try:
                ticker_info = await asyncio.to_thread(lambda s=yf_symbol: yf.Ticker(s).get_info())
            except Exception:
                ticker_info = {}
        expected_return, volatility, latest_price = _calc_return_and_vol(history)
        if price is None and latest_price is not None:
            price = latest_price
        if price is None:
            price = _safe_float(ticker_info.get("currentPrice") or ticker_info.get("regularMarketPrice"))
        if market_cap is None:
            market_cap = _safe_float(ticker_info.get("marketCap"))
        if volume is None:
            volume = _safe_int(ticker_info.get("volume") or ticker_info.get("regularMarketVolume"))

        price_1_year_ago = None
        if not history.empty and "Close" in history.columns:
            close = history["Close"].dropna()
            if not close.empty:
                price_1_year_ago = float(close.iloc[0])
                if price is not None and price_1_year_ago > 0:
                    expected_return = _to_pct((price - price_1_year_ago) / price_1_year_ago)

        risk_level = _is_risky(volatility) if volatility is not None else "Unknown"
        company_name = str(
            quote.get("name")
            or ticker_info.get("longName")
            or ticker_info.get("shortName")
            or company_name
        ).strip() or symbol

        if price is None:
            continue

        cached = db.query(Stock).filter(Stock.symbol == symbol).first()
        if cached:
            cached.name = company_name
            cached.price = price
            cached.change_percent = change_percent
            cached.volume = volume
            cached.market_cap = market_cap
            cached.expected_return = expected_return
            cached.risk_level = risk_level
            cached.last_updated = _utcnow()
        else:
            db.add(
                Stock(
                    symbol=symbol,
                    name=company_name,
                    price=price,
                    change_percent=change_percent,
                    volume=volume,
                    market_cap=market_cap,
                    expected_return=expected_return,
                    risk_level=risk_level,
                    last_updated=_utcnow(),
                )
            )

        _upsert_asset_cache(
            db,
            asset_name=company_name,
            asset_type="stocks",
            risk_level=risk_level,
            expected_return=expected_return,
            price=price,
        )

        output.append(
            {
                "asset_name": company_name,
                "symbol": symbol if ".NSE" in symbol else symbol.replace(".NS", ".NSE"),
                "company_name": company_name,
                "price": price,
                "live_price": price,
                "change_percent": change_percent,
                "volume": volume,
                "market_cap": market_cap,
                "price_1_year_ago": price_1_year_ago,
                "volatility": (volatility * 100) if volatility is not None else 0.0,
                "expected_return": expected_return,
                "risk_level": risk_level,
                "source": "twelvedata+yfinance",
                **_enrich_asset_row(
                    asset_type="stocks",
                    asset_name=company_name,
                    risk_level=risk_level,
                    expected_return=expected_return,
                    minimum_investment=None,
                    data_source="TwelveData + yfinance",
                    price=price,
                ),
            }
        )

    if len(output) < limit:
        existing = db.query(Stock).order_by(Stock.last_updated.desc()).all()
        existing_map = {str(item.get("symbol")) for item in output}
        for row in existing:
            if len(output) >= limit:
                break
            if not _is_real_stock_symbol(row.symbol or ""):
                continue
            symbol = row.symbol
            display_symbol = symbol if ".NSE" in symbol else symbol.replace(".NS", ".NSE")
            if display_symbol in existing_map:
                continue
            output.append(
                {
                    "asset_name": row.name or display_symbol,
                    "symbol": display_symbol,
                    "company_name": row.name or display_symbol,
                    "price": row.price,
                    "live_price": row.price,
                    "change_percent": row.change_percent,
                    "volume": row.volume,
                    "market_cap": row.market_cap,
                    "price_1_year_ago": None,
                    "volatility": 0.0,
                    "expected_return": row.expected_return,
                    "risk_level": row.risk_level or "Unknown",
                    "source": "cache-fallback",
                    **_enrich_asset_row(
                        asset_type="stocks",
                        asset_name=row.name or display_symbol,
                        risk_level=row.risk_level,
                        expected_return=row.expected_return,
                        minimum_investment=None,
                        data_source="TwelveData + yfinance (cached)",
                        price=row.price,
                    ),
                }
            )
            existing_map.add(display_symbol)

    db.commit()
    return output


async def get_gold_price(db: Session) -> dict[str, Any]:
    last_row = db.query(GoldPrice).order_by(GoldPrice.last_updated.desc()).first()
    if last_row and _is_fresh(last_row.last_updated):
        return {
            "live_gold_price": last_row.live_price,
            "price": last_row.live_price,
            "daily_change": last_row.daily_change,
            "one_year_return": last_row.one_year_return,
            "expected_return": last_row.one_year_return if last_row.one_year_return is not None else 0.0,
            "risk_level": last_row.risk_level,
            "source": "cache",
            **_enrich_asset_row(
                asset_type="gold",
                asset_name="Gold",
                risk_level=last_row.risk_level,
                expected_return=last_row.one_year_return,
                minimum_investment=None,
                data_source="TwelveData XAU/USD + yfinance (cached)",
                price=last_row.live_price,
            ),
        }

    live_price = None
    if TWELVEDATA_API_KEY:
        try:
            price_payload = await _fetch_json(
                TWELVEDATA_PRICE_URL,
                params={"symbol": "XAU/USD", "apikey": TWELVEDATA_API_KEY},
            )
            live_price = _safe_float(price_payload.get("price"))
        except Exception:
            live_price = None
    if live_price is None:
        try:
            spot_payload = await _fetch_json(GOLD_SPOT_URL)
        except Exception:
            spot_payload = None
        live_price = _parse_gold_spot(spot_payload)
    if live_price is None and last_row:
        live_price = last_row.live_price

    history = await asyncio.to_thread(lambda: yf.Ticker("GC=F").history(period="1y"))
    close = history["Close"].dropna() if not history.empty else pd.Series(dtype=np.float64)
    one_year_return = None
    daily_change = None
    risk_level = "Unknown"
    if not close.empty:
        start = float(close.iloc[0])
        end = float(close.iloc[-1])
        prev = float(close.iloc[-2]) if len(close) > 1 else end
        one_year_return = _to_pct((end - start) / start) if start > 0 else None
        daily_change = _to_pct((end - prev) / prev) if prev > 0 else None
        returns = close.pct_change().dropna()
        vol = float(returns.std() * math.sqrt(252)) if not returns.empty else None
        risk_level = _is_risky(vol) if vol is not None else "Unknown"

    if live_price is None:
        live_price = float(close.iloc[-1]) if not close.empty else None

    if live_price is None:
        return {
            "live_gold_price": None,
            "price": 0.0,
            "daily_change": daily_change,
            "one_year_return": one_year_return,
            "expected_return": one_year_return if one_year_return is not None else 0.0,
            "risk_level": risk_level,
            "source": "unavailable",
            **_enrich_asset_row(
                asset_type="gold",
                asset_name="Gold",
                risk_level=risk_level,
                expected_return=one_year_return,
                minimum_investment=None,
                data_source="TwelveData XAU/USD + yfinance",
                price=0.0,
            ),
        }

    db.add(
        GoldPrice(
            live_price=live_price,
            daily_change=daily_change,
            one_year_return=one_year_return,
            risk_level=risk_level,
            last_updated=_utcnow(),
        )
    )

    _upsert_asset_cache(
        db,
        asset_name="Gold",
        asset_type="gold",
        risk_level=risk_level,
        expected_return=one_year_return,
        price=live_price,
    )
    db.commit()

    return {
        "live_gold_price": live_price,
        "price": live_price,
        "daily_change": daily_change,
        "one_year_return": one_year_return,
        "expected_return": one_year_return if one_year_return is not None else 0.0,
        "risk_level": risk_level,
        "source": "twelvedata+yfinance",
        **_enrich_asset_row(
            asset_type="gold",
            asset_name="Gold",
            risk_level=risk_level,
            expected_return=one_year_return,
            minimum_investment=None,
            data_source="TwelveData XAU/USD + yfinance",
            price=live_price,
        ),
    }

async def get_fd_rates(db: Session) -> list[dict[str, Any]]:
    recent = db.query(FDRate).order_by(FDRate.last_updated.desc()).all()
    if recent and all(_is_fresh(row.last_updated) for row in recent):
        return [
            {
                "bank_name": row.bank_name,
                "interest_rate": row.interest_rate,
                "minimum_deposit": row.minimum_deposit,
                "lock_in_period": row.lock_in_period,
                "source_url": row.source_url,
                "source": "cache",
                **_enrich_asset_row(
                    asset_type="fixed_deposit",
                    asset_name=f"{row.bank_name} Fixed Deposit",
                    risk_level="Low",
                    expected_return=row.interest_rate,
                    minimum_investment=row.minimum_deposit,
                    data_source=row.source_url or "Bank source (cached)",
                    lock_in_period=row.lock_in_period,
                ),
            }
            for row in recent
        ]

    output: list[dict[str, Any]] = []
    for bank, url in FD_SOURCES.items():
        try:
            html = await _fetch_html(url)
            soup = BeautifulSoup(html, "lxml")
            text = soup.get_text(" ", strip=True)
            rates = _extract_percentages(text)
            interest_rate = max(rates) if rates else None
            minimum_deposit = _extract_currency(text)
            lock_in_period = None
            tenor_match = re.search(r"(\d+\s*(?:year|years|month|months|day|days))", text, flags=re.IGNORECASE)
            if tenor_match:
                lock_in_period = tenor_match.group(1)

            row = db.query(FDRate).filter(FDRate.bank_name == bank).first()
            if row:
                row.interest_rate = interest_rate
                row.minimum_deposit = minimum_deposit
                row.lock_in_period = lock_in_period
                row.source_url = url
                row.last_updated = _utcnow()
            else:
                db.add(
                    FDRate(
                        bank_name=bank,
                        interest_rate=interest_rate,
                        minimum_deposit=minimum_deposit,
                        lock_in_period=lock_in_period,
                        source_url=url,
                        last_updated=_utcnow(),
                    )
                )

            if interest_rate is not None:
                _upsert_asset_cache(
                    db,
                    asset_name=f"{bank} Fixed Deposit",
                    asset_type="fixed_deposit",
                    risk_level="Low",
                    expected_return=interest_rate,
                    price=None,
                )

            output.append(
                {
                    "bank_name": bank,
                    "interest_rate": interest_rate,
                    "minimum_deposit": minimum_deposit,
                    "lock_in_period": lock_in_period,
                    "source_url": url,
                    "source": "bank-web",
                    **_enrich_asset_row(
                        asset_type="fixed_deposit",
                        asset_name=f"{bank} Fixed Deposit",
                        risk_level="Low",
                        expected_return=interest_rate,
                        minimum_investment=minimum_deposit,
                        data_source=url,
                        lock_in_period=lock_in_period,
                    ),
                }
            )
        except Exception:
            continue

    db.commit()
    return output


async def get_lic_policies(db: Session, limit: int = 20) -> list[dict[str, Any]]:
    lic_asset = (
        db.query(InvestmentAsset)
        .filter(InvestmentAsset.asset_type == "lic")
        .order_by(InvestmentAsset.last_updated.desc())
        .first()
    )
    lic_expected_return = float(lic_asset.expected_return) if lic_asset and lic_asset.expected_return is not None else 0.0

    recent = db.query(LICPolicy).order_by(LICPolicy.last_updated.desc()).all()
    if recent and all(_is_fresh(row.last_updated) for row in recent):
        return [
            _lic_payload_from_row(
                row,
                source="cache",
                data_source=row.source_url or "LIC India (cached)",
                expected_return=lic_expected_return,
            )
            for row in recent[:limit]
        ]

    candidates = await _fetch_lic_candidates(limit)
    if not candidates and LIC_DATA_PATH.exists():
        payload = json.loads(LIC_DATA_PATH.read_text(encoding="utf-8"))
        for item in payload[:limit]:
            candidates.append(
                {
                    "policy_name": str(item.get("policy_name", "LIC Policy")),
                    "lock_in_period": item.get("lock_in_period"),
                    "expected_return": _safe_float(item.get("expected_return")) or 0.0,
                    "minimum_investment": _safe_float(item.get("minimum_investment")),
                    "policy_benefits": str(item.get("benefits", item.get("policy_benefits", ""))),
                    "maturity_rules": str(item.get("description", item.get("maturity_rules", ""))),
                    "risk_level": str(item.get("risk_level", "Low")),
                    "source_url": "backend/data/lic_policies.json",
                }
            )

    for item in candidates:
        row = db.query(LICPolicy).filter(LICPolicy.policy_name == item["policy_name"]).first()
        if row:
            row.lock_in_period = item["lock_in_period"]
            row.minimum_investment = item["minimum_investment"]
            row.policy_benefits = item["policy_benefits"]
            row.maturity_rules = item["maturity_rules"]
            row.risk_level = item["risk_level"]
            row.source_url = item["source_url"]
            row.last_updated = _utcnow()
        else:
            db.add(
                LICPolicy(
                    policy_name=item["policy_name"],
                    lock_in_period=item.get("lock_in_period"),
                    minimum_investment=item.get("minimum_investment"),
                    policy_benefits=item.get("policy_benefits"),
                    maturity_rules=item.get("maturity_rules"),
                    risk_level=item.get("risk_level"),
                    source_url=item.get("source_url"),
                    last_updated=_utcnow(),
                )
            )

    if candidates:
        avg_expected = sum(item["expected_return"] for item in candidates) / len(candidates)
        _upsert_asset_cache(
            db,
            asset_name="LIC Policies",
            asset_type="lic",
            risk_level="Low",
            expected_return=avg_expected,
            price=None,
        )
        lic_expected_return = avg_expected

    if candidates:
        db.commit()
    else:
        db.rollback()
    return [
        {
            **row,
            "source": "licindia" if str(row.get("source_url", "")).startswith("https://licindia.in") else "lic-dataset",
            **_enrich_asset_row(
                asset_type="lic",
                asset_name=row["policy_name"],
                risk_level=row.get("risk_level"),
                expected_return=row.get("expected_return", lic_expected_return),
                minimum_investment=row.get("minimum_investment"),
                data_source=row.get("source_url") or "LIC India",
                lock_in_period=row.get("lock_in_period"),
                price=0.0,
            ),
            "description": row.get("maturity_rules", ""),
            "benefits": row.get("policy_benefits", ""),
        }
        for row in candidates
    ] or [
        _lic_payload_from_row(
            row,
            source="cache-fallback",
            data_source=row.source_url or "LIC India (stale cache)",
            expected_return=lic_expected_return,
        )
        for row in recent[:limit]
    ]


async def get_market_assets(db: Session, asset_type: str) -> list[dict[str, Any]]:
    symbols = MARKET_BASKETS.get(asset_type, [])
    if not symbols:
        return []

    cache = (
        db.query(InvestmentAsset)
        .filter(InvestmentAsset.asset_type == asset_type)
        .order_by(InvestmentAsset.last_updated.desc())
        .all()
    )
    if cache and all(_is_fresh(r.last_updated) for r in cache):
        return [
            {
                "asset_name": r.asset_name,
                "asset_type": r.asset_type,
                "price": r.price,
                "expected_return": r.expected_return,
                "risk_level": r.risk_level,
                "source": "cache",
                **_enrich_asset_row(
                    asset_type=asset_type,
                    asset_name=r.asset_name,
                    risk_level=r.risk_level,
                    expected_return=r.expected_return,
                    minimum_investment=None,
                    data_source="yfinance (cached)",
                ),
            }
            for r in cache
        ]

    output: list[dict[str, Any]] = []
    for symbol in symbols:
        history = await asyncio.to_thread(lambda s=symbol: yf.Ticker(s).history(period="1y"))
        expected_return, volatility, latest = _calc_return_and_vol(history)
        risk = _is_risky(volatility) if volatility is not None else "Unknown"
        _upsert_asset_cache(
            db,
            asset_name=symbol,
            asset_type=asset_type,
            risk_level=risk,
            expected_return=expected_return,
            price=latest,
        )
        output.append(
            {
                "asset_name": symbol,
                "asset_type": asset_type,
                "price": latest,
                "expected_return": expected_return,
                "risk_level": risk,
                "source": "yfinance",
                **_enrich_asset_row(
                    asset_type=asset_type,
                    asset_name=symbol,
                    risk_level=risk,
                    expected_return=expected_return,
                    minimum_investment=None,
                    data_source="yfinance",
                ),
            }
        )
    db.commit()
    return output


def _monthly_financial_snapshot(db: Session, user_id: int) -> dict[str, float]:
    budget_row = db.query(Budget).filter(Budget.user_id == user_id).first()
    monthly_income = float(budget_row.monthly_amount) if budget_row and budget_row.monthly_amount is not None else 0.0

    expense_agg = (
        db.query(
            func.coalesce(func.sum(Expense.amount), 0).label("total_expense"),
            func.count(func.distinct(func.date_trunc("month", Expense.transaction_date))).label("month_count"),
        )
        .filter(Expense.user_id == user_id)
        .first()
    )
    total_expense = float(getattr(expense_agg, "total_expense", 0) or 0)
    month_count = int(getattr(expense_agg, "month_count", 0) or 0)
    monthly_expense = (total_expense / month_count) if month_count > 0 else 0.0

    monthly_savings = monthly_income - monthly_expense
    savings_ratio = (monthly_savings / monthly_income) if monthly_income > 0 else 0.0
    return {
        "monthly_income": round(monthly_income, 2),
        "monthly_expenses": round(monthly_expense, 2),
        "monthly_savings": round(monthly_savings, 2),
        "savings_ratio": round(savings_ratio, 4),
    }


async def _ensure_live_assets(db: Session) -> None:
    for loader in (
        lambda: get_mutual_funds(db, limit=30),
        lambda: get_stocks(db, limit=50),
        lambda: get_gold_price(db),
        lambda: get_fd_rates(db),
        lambda: get_lic_policies(db, limit=20),
        lambda: get_market_assets(db, "index_funds"),
        lambda: get_market_assets(db, "government_bonds"),
        lambda: get_market_assets(db, "etfs"),
    ):
        try:
            await loader()
        except Exception:
            db.rollback()
            continue


async def get_best_choice(
    db: Session,
    user_id: int,
    monthly_income: float | None = None,
    monthly_expenses: float | None = None,
) -> dict[str, Any]:
    await _ensure_live_assets(db)

    snapshot = _monthly_financial_snapshot(db, user_id)
    income = monthly_income if monthly_income is not None else snapshot["monthly_income"]
    expense_value = monthly_expenses if monthly_expenses is not None else snapshot["monthly_expenses"]
    monthly_savings = income - expense_value
    savings_ratio = (monthly_savings / income) if income > 0 else 0.0

    if savings_ratio < 0.20:
        suggested_allocation = {
            "fixed_deposit": 40,
            "government_bonds": 30,
            "gold": 20,
            "mutual_funds": 10,
        }
    elif savings_ratio <= 0.40:
        suggested_allocation = {
            "mutual_funds": 35,
            "index_funds": 25,
            "stocks": 20,
            "gold": 10,
            "fixed_deposit": 10,
        }
    else:
        suggested_allocation = {
            "stocks": 45,
            "mutual_funds": 30,
            "etfs": 15,
            "index_funds": 10,
        }

    investment_options: list[dict[str, Any]] = []
    investable_amount = max(monthly_savings, 0.0)
    for idx, (asset_type, percent) in enumerate(suggested_allocation.items(), start=1):
        pool = (
            db.query(InvestmentAsset)
            .filter(InvestmentAsset.asset_type == asset_type)
            .order_by(InvestmentAsset.expected_return.desc(), InvestmentAsset.last_updated.desc())
            .all()
        )
        if not pool:
            continue
        best = pool[0]
        investment_options.append(
            {
                "id": idx,
                "asset_type": asset_type,
                "asset_name": best.asset_name,
                "risk_level": best.risk_level,
                "expected_return": best.expected_return,
                "price": best.price,
                "recommended_monthly_amount": round(investable_amount * percent / 100, 2),
                "allocation_percent": percent,
                **_enrich_asset_row(
                    asset_type=asset_type,
                    asset_name=best.asset_name,
                    risk_level=best.risk_level,
                    expected_return=best.expected_return,
                    minimum_investment=None,
                    data_source="Goals analytics engine",
                ),
            }
        )

    return {
        "monthly_income": round(income, 2),
        "monthly_expense": round(expense_value, 2),
        "monthly_savings": round(monthly_savings, 2),
        "suggested_allocation": suggested_allocation,
        "investment_options": investment_options,
    }

def add_goal_portfolio_item(
    db: Session,
    user_id: int,
    asset_type: str,
    asset_name: str,
    invested_amount: float,
    expected_return: float | None,
    risk_level: str | None,
    start_date: date | None,
) -> GoalsPortfolio:
    row = GoalsPortfolio(
        user_id=user_id,
        asset_type=asset_type,
        asset_name=asset_name,
        invested_amount=invested_amount,
        expected_return=expected_return,
        risk_level=risk_level,
        start_date=start_date or date.today(),
    )
    db.add(row)
    db.commit()
    db.refresh(row)
    return row


def get_goal_portfolio_summary(db: Session, user_id: int) -> dict[str, Any]:
    rows = (
        db.query(GoalsPortfolio)
        .filter(GoalsPortfolio.user_id == user_id)
        .order_by(GoalsPortfolio.start_date.desc(), GoalsPortfolio.id.desc())
        .all()
    )
    total = 0.0
    expected_yearly = 0.0
    by_type: dict[str, float] = {}
    items: list[dict[str, Any]] = []
    for row in rows:
        amount = float(row.invested_amount or 0)
        exp = float(row.expected_return or 0)
        total += amount
        expected_yearly += amount * (exp / 100)
        by_type[row.asset_type] = by_type.get(row.asset_type, 0.0) + amount
        items.append(
            {
                "id": row.id,
                "asset_type": row.asset_type,
                "asset_name": row.asset_name,
                "invested_amount": round(amount, 2),
                "expected_return": row.expected_return,
                "risk_level": row.risk_level,
                "start_date": row.start_date,
            }
        )

    allocation = [{"type": t, "amount": round(v, 2)} for t, v in sorted(by_type.items(), key=lambda kv: kv[1], reverse=True)]
    return {
        "total_invested_amount": round(total, 2),
        "expected_yearly_return": round(expected_yearly, 2),
        "items": items,
        "allocation_by_type": allocation,
    }


def delete_goal_portfolio_item(db: Session, user_id: int, item_id: int) -> bool:
    row = (
        db.query(GoalsPortfolio)
        .filter(
            GoalsPortfolio.id == item_id,
            GoalsPortfolio.user_id == user_id,
        )
        .first()
    )
    if not row:
        return False
    db.delete(row)
    db.commit()
    return True


# Legacy wrappers kept for backward compatibility with old routes.
async def get_live_recommendations(
    db: Session,
    user_id: int,
    monthly_income: float | None = None,
    monthly_expenses: float | None = None,
    savings_ratio: float | None = None,
) -> dict[str, Any]:
    del savings_ratio
    best = await get_best_choice(db, user_id, monthly_income, monthly_expenses)
    options = best.get("investment_options", [])
    return {
        "estimated_income": best["monthly_income"],
        "monthly_income": best["monthly_income"],
        "monthly_expenses": best["monthly_expense"],
        "monthly_savings": best["monthly_savings"],
        "savings_ratio": (best["monthly_savings"] / best["monthly_income"]) if best["monthly_income"] else 0.0,
        "allocation": best.get("suggested_allocation", {}),
        "recommendations": [
            {
                "id": r["id"],
                "type": r["asset_type"],
                "name": r["asset_name"],
                "risk": r["risk_level"],
                "expected_return": f"{(r['expected_return'] or 0):.2f}%",
                "price": r["price"],
                "recommended_amount": r["recommended_monthly_amount"],
            }
            for r in options
        ],
        "insights": [],
    }


def get_recommendations(db: Session, user_id: int) -> dict[str, Any]:
    return asyncio.run(get_live_recommendations(db=db, user_id=user_id))


def get_options_by_type(db: Session, investment_type: str) -> list[InvestmentOption]:
    return (
        db.query(InvestmentOption)
        .filter(func.lower(InvestmentOption.type) == investment_type.lower())
        .order_by(InvestmentOption.expected_return.desc())
        .all()
    )


def add_to_portfolio(
    db: Session,
    user_id: int,
    investment_id: int,
    invested_amount: float,
    start_date: date | None,
) -> UserPortfolio:
    option = db.query(InvestmentOption).filter(InvestmentOption.id == investment_id).first()
    if not option:
        raise ValueError("Investment option not found")
    row = UserPortfolio(
        user_id=user_id,
        investment_id=investment_id,
        invested_amount=invested_amount,
        start_date=start_date or date.today(),
    )
    db.add(row)
    db.commit()
    db.refresh(row)
    return row


def get_portfolio_summary(db: Session, user_id: int) -> dict[str, Any]:
    rows = (
        db.query(
            UserPortfolio.id.label("portfolio_id"),
            InvestmentOption.id.label("investment_id"),
            InvestmentOption.name,
            InvestmentOption.type,
            InvestmentOption.expected_return,
            UserPortfolio.invested_amount,
            UserPortfolio.start_date,
        )
        .join(InvestmentOption, InvestmentOption.id == UserPortfolio.investment_id)
        .filter(UserPortfolio.user_id == user_id)
        .order_by(UserPortfolio.start_date.desc(), UserPortfolio.id.desc())
        .all()
    )
    breakdown = []
    total_invested = 0.0
    expected_yearly_return = 0.0
    by_type: dict[str, float] = {}
    for row in rows:
        amount = float(row.invested_amount or 0)
        exp_return = float(row.expected_return or 0)
        total_invested += amount
        expected_yearly_return += amount * (exp_return / 100)
        by_type[row.type] = by_type.get(row.type, 0.0) + amount
        breakdown.append(
            {
                "portfolio_id": row.portfolio_id,
                "investment_id": row.investment_id,
                "name": row.name,
                "type": row.type,
                "invested_amount": round(amount, 2),
                "expected_return": exp_return,
                "start_date": row.start_date,
            }
        )
    allocation_by_type = [{"type": k, "amount": round(v, 2)} for k, v in sorted(by_type.items(), key=lambda kv: kv[1], reverse=True)]
    return {
        "total_invested_amount": round(total_invested, 2),
        "expected_yearly_return": round(expected_yearly_return, 2),
        "breakdown": breakdown,
        "allocation_by_type": allocation_by_type,
    }


def delete_portfolio_item(db: Session, user_id: int, portfolio_id: int) -> bool:
    row = (
        db.query(UserPortfolio)
        .filter(
            UserPortfolio.id == portfolio_id,
            UserPortfolio.user_id == user_id,
        )
        .first()
    )
    if not row:
        return False
    db.delete(row)
    db.commit()
    return True
