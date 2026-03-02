import logging
from typing import Any, Dict, Optional
from fastapi import HTTPException
from sqlalchemy.orm import Session
from services.ingestion_v2.engine import IngestionEngineV2
from models.ingestion_log_orm import IngestionLog
from services.parsers.manual import ManualParser
from services.parsers.ocr import OCRParser
from services.ingestion import create_expense_from_input
from models.merchant_category_learning_orm import MerchantCategoryLearning

logger = logging.getLogger("expense-tracker.ingestion_service")

PARSERS = {
    "manual": ManualParser(),
    "ocr": OCRParser(),
}

AUTO_CREATE_THRESHOLD = 0.8


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
        # 1️⃣ Create ingestion log
        log = IngestionLog(
            user_id=user.id,
            input_type=input_type,
            raw_payload=raw_payload,
            status="pending",
        )
        db.add(log)
        db.flush()

        # 2️⃣ Select parser
        parser = PARSERS.get(input_type)
        if not parser:
            raise HTTPException(status_code=400, detail="Unsupported input_type")

        parsed = parser.parse(raw_text, payload, metadata)

        # -------------------------
        # V2 ENGINE (Parallel Run)
        # -------------------------
        v2_engine = IngestionEngineV2()
        v2_result = v2_engine.process(raw_text or "")

        logger.info(
            "ingestion_v2.compare user_id=%s "
            "v1_amount=%s v2_amount=%s "
            "v1_merchant=%s v2_merchant=%s "
            "v1_conf=%s v2_conf=%s",
            user.id,
            parsed.get("amount"),
            v2_result.amount,
            parsed.get("merchant_name"),
            v2_result.merchant_name,
            parsed.get("confidence_score"),
            v2_result.confidence,
        )

        amount = parsed.get("amount")
        transaction_date = parsed.get("transaction_date")
        category_name = parsed.get("category_name")
        merchant_name = parsed.get("merchant_name")
        confidence = float(parsed.get("confidence_score") or 0.0)

        # Apply per-user learned merchant -> category mappings (exact normalized match only)
        if merchant_name:
            try:
                merchant_key = merchant_name.lower().strip()
                learned = (
                    db.query(MerchantCategoryLearning)
                    .filter(
                        MerchantCategoryLearning.user_id == getattr(user, "id", None),
                        MerchantCategoryLearning.merchant_key == merchant_key,
                    )
                    .first()
                )
                if learned:
                    category_name = learned.category_name
                    # boost confidence but do not exceed 1.0
                    confidence = min(1.0, confidence + 0.2)
            except Exception:
                # Do not allow learning lookup failures to crash ingestion
                logger.exception("ingestion_service.learning_lookup_failed user_id=%s merchant=%s", getattr(user, "id", None), merchant_name)

        log.parsed_amount = amount
        log.parsed_category = category_name
        log.parsed_merchant = merchant_name
        log.confidence_score = confidence

        # 3️⃣ Auto-create expense only if confidence high
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

        # 🔥 Single commit at end
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