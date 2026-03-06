import logging
import re
from typing import Any, Dict, Optional
from datetime import date, datetime

from fastapi import HTTPException
from sqlalchemy.orm import Session
from sqlalchemy.exc import IntegrityError

from services.ingestion_v2.engine import IngestionEngineV2
from models.ingestion_log_orm import IngestionLog
from models.merchant_orm import Merchant
from services.ingestion import create_expense_from_input
from models.merchant_category_learning_orm import MerchantCategoryLearning

logger = logging.getLogger("expense-tracker.ingestion_service")

AUTO_CREATE_THRESHOLD = 0.8


def _normalize_merchant_key(name: str) -> str:
    """
    Deterministic normalization:
    - Uppercase
    - Remove non letters
    """
    return re.sub(r"[^A-Z]", "", name.upper())


def _resolve_or_create_merchant(db: Session, merchant_name: str) -> Optional[str]:
    if not merchant_name:
        return None

    normalized_key = _normalize_merchant_key(merchant_name)

    # 1️⃣ Try fetch existing
    merchant = (
        db.query(Merchant)
        .filter(Merchant.normalized_key == normalized_key)
        .first()
    )

    if merchant:
        return merchant.name

    # 2️⃣ Create new (race-safe)
    new_merchant = Merchant(
        name=merchant_name.strip(),
        normalized_key=normalized_key,
    )

    db.add(new_merchant)

    try:
        db.flush()  # Try insert
        return new_merchant.name

    except IntegrityError:
        # Another request inserted same normalized_key concurrently
        db.rollback()

        merchant = (
            db.query(Merchant)
            .filter(Merchant.normalized_key == normalized_key)
            .first()
        )
        return merchant.name if merchant else merchant_name


def process_ingestion(
    db: Session,
    user,
    input_type: str,
    raw_text: Optional[str] = None,
    payload: Optional[Dict[str, Any]] = None,
    metadata: Optional[Dict[str, Any]] = None,
) -> IngestionLog:

    input_type = (input_type or "").strip().lower()

    raw_payload = {
        "raw_text": raw_text,
        "structured_payload": payload,
        "metadata": metadata,
    }

    try:
        log = IngestionLog(
            user_id=user.id,
            input_type=input_type,
            raw_payload=raw_payload,
            status="pending",
        )
        db.add(log)
        db.flush()

        # 🔥 V2 Engine
        v2_engine = IngestionEngineV2()
        fields = v2_engine.process(raw_text or "")

        amount = fields.amount
        transaction_date = fields.transaction_date
        category_name = fields.category_name
        merchant_name = fields.merchant_name
        confidence = float(fields.confidence or 0.0)

        # Normalize date
        if isinstance(transaction_date, str):
            try:
                transaction_date = datetime.fromisoformat(transaction_date).date()
            except Exception:
                transaction_date = date.today()
        elif transaction_date is None:
            transaction_date = date.today()

        # 🔥 Production Merchant Resolution
        merchant_name = _resolve_or_create_merchant(db, merchant_name)

        # Optional learned mapping
        if merchant_name:
            try:
                merchant_key = merchant_name.lower().strip()
                learned = (
                    db.query(MerchantCategoryLearning)
                    .filter(
                        MerchantCategoryLearning.user_id == user.id,
                        MerchantCategoryLearning.merchant_key == merchant_key,
                    )
                    .first()
                )
                if learned:
                    category_name = learned.category_name
                    confidence = min(1.0, confidence + 0.2)
            except Exception:
                logger.exception("learning_lookup_failed user_id=%s", user.id)

        log.parsed_amount = amount
        log.parsed_category = category_name
        log.parsed_merchant = merchant_name
        log.confidence_score = confidence

        if confidence >= AUTO_CREATE_THRESHOLD:
            expense_payload = {
                "amount": amount,
                "transaction_date": transaction_date,
                "category_name": category_name,
                "merchant_name": merchant_name,
            }

            expense = create_expense_from_input(
                db=db,
                user=user,
                input_type=input_type,
                payload=expense_payload,
            )

            log.expense_id = expense.id
            log.status = "parsed"
        else:
            log.status = "needs_review"

        db.commit()
        db.refresh(log)
        return log

    except HTTPException:
        db.rollback()
        raise
    except Exception:
        db.rollback()
        logger.exception("ingestion_service.failure user_id=%s", user.id)
        raise HTTPException(status_code=500, detail="Internal ingestion error")