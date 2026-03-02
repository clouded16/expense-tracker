import re
import difflib
from dataclasses import dataclass
from typing import Any, Dict, List, Optional, Tuple
from datetime import datetime, date

from .base import ParserBase


@dataclass
class AmountCandidate:
    value: float
    start: int
    end: int
    raw_token: str
    contains_decimal: bool
    digit_length: int
    near_hint: bool


class OCRParser(ParserBase):
    """
    Production-ready OCR parser (pure parsing, no DB access).
    """

    MERCHANT_CATEGORY_MAP: Dict[str, str] = {
        "swiggy": "Food",
        "zomato": "Food",
        "amazon": "Shopping",
        "flipkart": "Shopping",
        "uber": "Transport",
        "ola": "Transport",
        "netflix": "Entertainment",
        "bookmyshow": "Entertainment",
    }

    KEYWORD_CATEGORY_MAP: Dict[str, str] = {
        "restaurant": "Food",
        "pizza": "Food",
        "cafe": "Food",
        "grocery": "Groceries",
        "fuel": "Transport",
        "petrol": "Transport",
        "movie": "Entertainment",
        "subscription": "Entertainment",
        "rent": "Housing",
    }

    AMOUNT_HINT_KEYWORDS: Tuple[str, ...] = (
        "total",
        "grand total",
        "amount",
        "net amount",
        "balance",
        "subtotal",
    )

    # Patterns to capture numeric tokens (group 1 contains numeric part)
    AMOUNT_PATTERNS: Tuple[re.Pattern, ...] = (
        # Currency symbol followed by number
        re.compile(r"(?:₹|Rs\.?|INR|\$|€|£)\s*([0-9]{1,3}(?:[,\d]*)(?:\.\d{1,2})?)", re.IGNORECASE),
        # Hint keyword followed by number
        re.compile(
            r"(?:total|amount|grand total|net amount|balance|subtotal)[:\s]*([0-9]+(?:[,\d]*)(?:\.\d{1,2})?)",
            re.IGNORECASE,
        ),
        # Plain numeric token
        re.compile(r"\b([0-9]+(?:[,\d]*)(?:\.\d{1,2})?)\b"),
    )

    DATE_PATTERNS: Tuple[re.Pattern, ...] = (
        re.compile(r"\b(\d{4}-\d{2}-\d{2})\b"),  # YYYY-MM-DD
        re.compile(r"\b(\d{2}-\d{2}-\d{4})\b"),  # DD-MM-YYYY
        re.compile(r"\b(\d{2}/\d{2}/\d{4})\b"),  # DD/MM/YYYY
    )

    MIN_REASONABLE_AMOUNT: float = 1.0
    MAX_REASONABLE_AMOUNT: float = 1_000_000.0
    YEAR_MIN: int = 1900
    YEAR_MAX: int = 2100

    FUZZY_CUTOFF: float = 0.85
    FUZZY_MIN_TOKEN_LEN: int = 4

    NEAR_HINT_WINDOW: int = 40  # characters after hint keyword considered 'near'

    # ---------------------------
    # Normalization helpers
    # ---------------------------
    def _normalize(self, raw_text: Optional[str]) -> str:
        s = raw_text or ""
        # remove non-printable / non-utf characters, normalize whitespace and newlines
        s = re.sub(r"[^\x20-\x7E\n\r\t]", " ", s)
        s = s.replace("\r\n", "\n").replace("\r", "\n")
        s = re.sub(r"[ \t]+", " ", s)
        s = s.strip()
        return s

    def _lower(self, text: str) -> str:
        return text.lower() if text else ""

    # ---------------------------
    # Date extraction helpers
    # ---------------------------
    def _find_date_spans(self, text: str) -> List[Tuple[int, int]]:
        spans: List[Tuple[int, int]] = []
        for rx in self.DATE_PATTERNS:
            for m in rx.finditer(text):
                spans.append((m.start(1), m.end(1)))
        return spans

    def _overlaps_date(self, start: int, end: int, date_spans: List[Tuple[int, int]]) -> bool:
        for ds, de in date_spans:
            if not (end <= ds or start >= de):
                return True
        return False

    # ---------------------------
    # Amount extraction (new subsystem)
    # ---------------------------
    def _extract_amount_candidates(self, text: str) -> List[AmountCandidate]:
        """
        Extract numeric token candidates from text with metadata for scoring.
        """
        candidates: List[AmountCandidate] = []
        try:
            text_lower = self._lower(text)

            # find hint keyword positions
            hint_positions: List[int] = []
            for kw in self.AMOUNT_HINT_KEYWORDS:
                for m in re.finditer(re.escape(kw), text_lower):
                    hint_positions.append(m.start())

            # date spans to avoid overlapping tokens
            date_spans = self._find_date_spans(text)

            for pattern in self.AMOUNT_PATTERNS:
                for m in pattern.finditer(text):
                    raw = m.group(1)
                    if not raw:
                        continue
                    start = m.start(1)
                    end = m.end(1)
                    raw_token = raw.strip()

                    # prepare numeric cleaned string
                    cleaned = raw_token.strip()

                    # Handle comma as decimal separator (e.g., 2000,00 → 2000.00)
                    if "," in cleaned and "." not in cleaned:
                        if re.search(r",[0-9]{2}$", cleaned):
                            cleaned = cleaned.replace(",", ".")
                        else:
                            cleaned = cleaned.replace(",", "")

                    # Remove remaining thousands separators
                    cleaned = cleaned.replace(",", "")

                    # Remove currency symbols or stray chars at start
                    cleaned = re.sub(r"^[^\d\-\.]+", "", cleaned)

                    try:
                        value = float(cleaned)
                    except Exception:
                        continue

                    contains_decimal = "." in cleaned
                    digit_length = len(re.sub(r"[^\d]", "", cleaned))

                    # near_hint: within NEAR_HINT_WINDOW characters after a hint keyword
                    near = False
                    for hp in hint_positions:
                        if 0 <= (start - hp) <= self.NEAR_HINT_WINDOW:
                            near = True
                            break

                    # ignore tokens overlapping dates immediately
                    if self._overlaps_date(start, end, date_spans):
                        continue

                    candidates.append(
                        AmountCandidate(
                            value=value,
                            start=start,
                            end=end,
                            raw_token=raw_token,
                            contains_decimal=contains_decimal,
                            digit_length=digit_length,
                            near_hint=near,
                        )
                    )
        except Exception:
            # safe failure: return what we have (possibly empty)
            return candidates

        return candidates

    def _is_reasonable_amount(self, val: float, digit_length: int) -> bool:
        """
        Basic sanity checks for monetary values.
        """
        try:
            if val < self.MIN_REASONABLE_AMOUNT:
                return False
            if val > self.MAX_REASONABLE_AMOUNT:
                return False
            # reject likely year
            if int(val) >= self.YEAR_MIN and int(val) <= self.YEAR_MAX:
                return False
            # otherwise reasonable (further integer checks happen in scoring)
            return True
        except Exception:
            return False

    def _prefer_amount(self, text: str, candidates: List[AmountCandidate]) -> Optional[float]:
        try:
            if not text:
                return None

            lines = text.splitlines()
            if not lines:
                return None

            total_lines = len(lines)

            # Keywords
            strong_total_keywords = ["grand total", "net amount", "amount payable"]
            total_keywords = ["total", "sale"]
            ignore_keywords = ["subtotal", "rate", "price", "volume", "qty", "kg", "ltr", "litre", "density"]

            line_scores = []

            for idx, line in enumerate(lines):
                line_lower = line.lower().strip()

                if not line_lower:
                    continue

                # Extract numeric values from this specific line only
                numbers = re.findall(r"[0-9]+(?:[,\d]*)(?:\.\d{1,2})?", line_lower)
                if not numbers:
                    continue

                # Convert numbers safely
                numeric_values = []
                for n in numbers:
                    cleaned = n.replace(",", "")
                    try:
                        numeric_values.append(float(cleaned))
                    except:
                        continue

                if not numeric_values:
                    continue

                # Base score
                score = 0

                # Bottom bias
                bottom_ratio = idx / max(1, total_lines)
                if bottom_ratio > 0.6:
                    score += 2
                if bottom_ratio > 0.75:
                    score += 3

                # Strong total override
                if any(k in line_lower for k in strong_total_keywords):
                    score += 10

                # Normal total boost
                elif any(k in line_lower for k in total_keywords):
                    score += 5

                # Penalize measurement/unit lines
                if any(k in line_lower for k in ignore_keywords):
                    score -= 5

                # Choose the largest number in that line
                max_value = max(numeric_values)

                line_scores.append((score, max_value))

            if not line_scores:
                return None

            # Sort by score first, then by amount
            line_scores.sort(key=lambda x: (x[0], x[1]), reverse=True)

            best_score, best_amount = line_scores[0]

            if best_score <= 0:
                return None

            return round(float(best_amount), 2)

        except Exception:
            return None

    # ---------------------------
    # Date extraction
    # ---------------------------
    def _extract_date(self, raw_text: Optional[str]) -> Tuple[Optional[date], bool]:
        """
        Return (date_or_None, detected_flag)
        """
        try:
            text = self._normalize(raw_text)
            for rx in self.DATE_PATTERNS:
                m = rx.search(text)
                if not m:
                    continue
                s = m.group(1)
                for fmt in ("%Y-%m-%d", "%d-%m-%Y", "%d/%m/%Y"):
                    try:
                        return datetime.strptime(s, fmt).date(), True
                    except Exception:
                        continue
            return None, False
        except Exception:
            return None, False

    # ---------------------------
    # Merchant detection
    # ---------------------------
    def _detect_merchant(self, raw_text: Optional[str]) -> Tuple[Optional[str], Optional[str]]:
        try:
            text = self._normalize(raw_text)
            text = self._normalize_ocr_errors(text)
            text_lower = self._lower(text)
            lines = [ln for ln in text.splitlines() if ln.strip()]

            # Direct substring match
            for key in self.MERCHANT_CATEGORY_MAP.keys():
                if key in text_lower:
                    for ln in lines:
                        if key in ln.lower():
                            return key, ln.strip()
                    return key, key.capitalize()

            # Fuzzy matching
            head = " ".join(lines[:10]).lower() if lines else text_lower
            tokens = [t for t in re.split(r"[^\w]+", head) if t and len(t) >= self.FUZZY_MIN_TOKEN_LEN]

            if tokens:
                merchant_keys = list(self.MERCHANT_CATEGORY_MAP.keys())
                for token in tokens:
                    matches = difflib.get_close_matches(token, merchant_keys, n=1, cutoff=self.FUZZY_CUTOFF)
                    if matches:
                        matched_key = matches[0]
                        for ln in lines:
                            if token in ln.lower() or matched_key in ln.lower():
                                return matched_key, ln.strip()
                        return matched_key, matched_key.capitalize()
            # Try combining first two lines if both look like header
            if len(lines) >= 2:
                first = lines[0].strip()
                second = lines[1].strip()

                combined = f"{first} {second}"

                uppercase_ratio = sum(1 for c in combined if c.isupper()) / max(1, len(combined))

                if (
                    len(combined) < 60
                    and uppercase_ratio > 0.4
                    and not any(rx.search(combined) for rx in self.DATE_PATTERNS)
                ):
                    return combined.lower(), combined

            # ✅ Fallback heuristic (NOW CORRECTLY PLACED)
            fallback_keywords_rx = re.compile(
                r"\b(invoice|invoice no|inv no|bill no|gst|gstin|tax|tax id|receipt no|order no|ord no)\b",
                re.IGNORECASE,
            )

            for ln in lines[:6]:
                ln_str = ln.strip()
                if not ln_str:
                    continue
                if len(ln_str) > 60:
                    continue
                if len(re.findall(r"[A-Za-z]", ln_str)) < 3:
                    continue

                # Skip date-like lines
                if any(rx.search(ln_str) for rx in self.DATE_PATTERNS):
                    continue

                # Skip invoice/gst lines
                if fallback_keywords_rx.search(ln_str):
                    continue

                # Skip mostly numeric lines
                alnum = re.findall(r"[A-Za-z0-9]", ln_str)
                if not alnum:
                    continue

                digits = len(re.findall(r"\d", ln_str))
                if digits / max(1, len(alnum)) > 0.6:
                    continue

                if re.fullmatch(r"[\d\W]+", ln_str):
                    continue

                clean_line = re.sub(r"\s+", " ", ln_str).strip()
                

                # Prefer lines with mostly uppercase (common in headers)
                uppercase_ratio = sum(1 for c in clean_line if c.isupper()) / max(1, len(clean_line))

                if uppercase_ratio > 0.4:
                    merchant_key = clean_line.lower()
                    return merchant_key, clean_line
                

            return None, None

        except Exception:
            return None, None
    # ---------------------------
    # Category inference
    # ---------------------------
    def _infer_category(self, raw_text: Optional[str], merchant_key: Optional[str]) -> Optional[str]:
        try:
            if merchant_key:
                mapped = self.MERCHANT_CATEGORY_MAP.get(merchant_key)
                if mapped:
                    return mapped
            text_lower = self._lower(self._normalize(raw_text))
            for kw, cat in self.KEYWORD_CATEGORY_MAP.items():
                if kw in text_lower:
                    return cat
            return None
        except Exception:
            return None

    # ---------------------------
    # Confidence computation
    # ---------------------------
    def _compute_confidence(self, amount_found: bool, merchant_found: bool, category_found: bool, date_detected: bool) -> float:
        if not amount_found:
            return 0.0
        score = 0.0
        if amount_found:
            score += 0.4
        if merchant_found:
            score += 0.3
        if category_found:
            score += 0.2
        if date_detected:
            score += 0.1
        if score > 1.0:
            score = 1.0
        return round(score, 2)

    # ---------------------------
    # Main parse entrypoint
    # ---------------------------
    def parse(self, raw_text: Optional[str], payload: Dict[str, Any] | None, metadata: Dict[str, Any] | None) -> Dict[str, Any]:
        """
        Parse raw_text into structured fields. Safe: catches exceptions and returns fallback.
        """
        try:
            text = raw_text or ""
            normalized_text = self._normalize(text)

            # Extract amount candidates and select best
            candidates = self._extract_amount_candidates(normalized_text)
            amount = None
            if candidates:
                amount = self._prefer_amount(normalized_text, candidates)

            # Extract date (with detection flag)
            tx_date, date_detected = self._extract_date(normalized_text)
            if tx_date is None:
                tx_date = date.today()

            # Merchant detection
            merchant_key, merchant_display = self._detect_merchant(text)

            # Category inference
            category_name = self._infer_category(text, merchant_key)

            # Confidence calculation
            amount_found = amount is not None
            merchant_found = merchant_key is not None
            category_found = category_name is not None
            confidence = self._compute_confidence(amount_found, merchant_found, category_found, date_detected)

            return {
                "amount": float(amount) if amount is not None else None,
                "transaction_date": tx_date,
                "category_name": category_name,
                "merchant_name": merchant_display if merchant_display else (merchant_key.capitalize() if merchant_key else None),
                "confidence_score": float(confidence),
            }
        except Exception:
            return {
                "amount": None,
                "transaction_date": date.today(),
                "category_name": None,
                "merchant_name": None,
                "confidence_score": 0.0,
            }
        
    def _normalize_ocr_errors(self, text: str) -> str:
        replacements = {
            "SRVICE": "SERVICE",
            "SRVCE": "SERVICE",
            "CENTRE_": "CENTRE",
            "SRVICEE": "SERVICE",
        }

        for wrong, correct in replacements.items():
            text = text.replace(wrong, correct)

        return text