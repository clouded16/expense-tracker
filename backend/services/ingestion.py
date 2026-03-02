import logging
from typing import Dict
from datetime import datetime, date

from fastapi import HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import func

from models.category_orm import Category
from models.merchant_orm import Merchant
from models.source_orm import Source
from models.expense_orm import Expense as ExpenseORM
from models.expense import ExpenseResponse
from models.user_orm import User
from models.ingestion_log_orm import IngestionLog


logger = logging.getLogger("expense-tracker.ingestion")


ALLOWED_INPUT_TYPES = ("manual", "sms", "email", "ocr", "csv", "api")

INPUT_TYPE_TO_SOURCE = {
    "manual": "manual",
    "sms": "sms",
    "email": "email",
    "ocr": "statement_upload",
    "csv": "csv_import",
    "api": "api",
}


# ----------------------------------------
# Utility: Make JSON safe
# ----------------------------------------
def make_json_safe(value):
    if isinstance(value, (datetime, date)):
        return value.isoformat()
    if isinstance(value, dict):
        return {k: make_json_safe(v) for k, v in value.items()}
    if isinstance(value, list):
        return [make_json_safe(v) for v in value]
    return value


# ----------------------------------------
# Main ingestion service
# ----------------------------------------
def create_expense_from_input(
    db: Session,
    user: User,
    input_type: str,
    payload: Dict,
) -> ExpenseResponse:

    input_type_normalized = (input_type or "").strip().lower()

    if input_type_normalized not in ALLOWED_INPUT_TYPES:
        raise HTTPException(status_code=400, detail=f"Invalid input_type: {input_type}")

    requested_source_name = (
        str(payload.get("source_name")).strip().lower()
        if payload.get("source_name")
        else INPUT_TYPE_TO_SOURCE.get(input_type_normalized, input_type_normalized)
    )

    # Create ingestion log immediately (pending state)
    log = IngestionLog(
        user_id=user.id,
        input_type=input_type_normalized,
        raw_payload=make_json_safe(payload),
        status="pending",
    )

    db.add(log)
    db.flush()  # get log.id

    try:
        # ----------------------------------------
        # Validate Amount
        # ----------------------------------------
        amount_raw = payload.get("amount")
        if amount_raw is None:
            raise HTTPException(status_code=400, detail="'amount' is required")

        try:
            amount_val = float(amount_raw)
        except Exception:
            raise HTTPException(status_code=400, detail="'amount' must be numeric")

        if amount_val <= 0:
            raise HTTPException(status_code=400, detail="'amount' must be greater than 0")

        # ----------------------------------------
        # Validate Transaction Date
        # ----------------------------------------
        td_raw = payload.get("transaction_date")
        if td_raw is None:
            raise HTTPException(status_code=400, detail="'transaction_date' is required")

        if isinstance(td_raw, datetime):
            transaction_date_val = td_raw.date()
        elif isinstance(td_raw, date):
            transaction_date_val = td_raw
        elif isinstance(td_raw, str):
            s = td_raw.strip()
            if s.endswith("Z"):
                s = s[:-1] + "+00:00"
            try:
                transaction_date_val = datetime.fromisoformat(s).date()
            except Exception:
                raise HTTPException(
                    status_code=400,
                    detail="'transaction_date' must be ISO-8601 date string",
                )
        else:
            raise HTTPException(
                status_code=400,
                detail="'transaction_date' must be date/datetime/string",
            )

        # ----------------------------------------
        # Resolve Category (user-scoped)
        # ----------------------------------------
        category_obj = None
        category_name = payload.get("category_name")
        if category_name:
            category_name_clean = category_name.strip()
            category_obj = (
                db.query(Category)
                .filter(
                    Category.user_id == user.id,
                    Category.name == category_name_clean,
                )
                .first()
            )

            if not category_obj:
                category_obj = Category(
                    user_id=user.id,
                    name=category_name_clean,
                )
                db.add(category_obj)
                db.flush()

        # ----------------------------------------
        # Resolve Merchant (global)
        # ----------------------------------------
        merchant_obj = None
        merchant_name = payload.get("merchant_name")
        if merchant_name:
            merchant_name_clean = merchant_name.strip()
            merchant_obj = (
                db.query(Merchant)
                .filter(Merchant.name == merchant_name_clean)
                .first()
            )

            if not merchant_obj:
                merchant_obj = Merchant(name=merchant_name_clean)
                db.add(merchant_obj)
                db.flush()

        # ----------------------------------------
        # Resolve Source
        # ----------------------------------------
        source_obj = (
            db.query(Source)
            .filter(func.lower(Source.name) == requested_source_name.lower())
            .first()
        )

        if not source_obj:
            raise HTTPException(status_code=400, detail="Invalid or unknown source")

        # ----------------------------------------
        # Create Expense
        # ----------------------------------------
        db_expense = ExpenseORM(
            user_id=user.id,
            amount=amount_val,
            transaction_date=transaction_date_val,
            category_id=category_obj.id if category_obj else None,
            merchant_id=merchant_obj.id if merchant_obj else None,
            source_id=source_obj.id,
            ingestion_type=input_type_normalized,
        )

        db.add(db_expense)
        db.flush()

        # ----------------------------------------
        # Update log (success)
        # ----------------------------------------
        log.status = "parsed"
        log.parsed_amount = amount_val
        log.parsed_category = category_name.strip() if category_name else None
        log.parsed_merchant = merchant_name.strip() if merchant_name else None
        log.confidence_score = 1.0
        log.expense_id = db_expense.id

        db.commit()
        db.refresh(db_expense)

        logger.info(
            "ingestion.success user_id=%s expense_id=%s",
            user.id,
            db_expense.id,
        )

        return ExpenseResponse(
            id=db_expense.id,
            amount=db_expense.amount,
            transaction_date=db_expense.transaction_date,
            category_name=category_obj.name if category_obj else None,
            merchant_name=merchant_obj.name if merchant_obj else None,
            source_name=source_obj.name if source_obj else None,
            created_at=db_expense.created_at,
        )

    except HTTPException as e:
        db.rollback()
        log.status = "failed"
        log.error_message = str(e.detail)
        db.add(log)
        db.commit()
        raise

    except Exception as exc:
        db.rollback()
        log.status = "failed"
        log.error_message = str(exc)
        db.add(log)
        db.commit()

        logger.exception(
            "ingestion.failure user_id=%s input_type=%s",
            user.id,
            input_type_normalized,
        )

        raise HTTPException(status_code=500, detail="Internal ingestion error")