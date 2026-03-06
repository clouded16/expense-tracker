from fastapi import FastAPI, Depends, HTTPException
from sqlalchemy.orm import Session
from models.refresh_token_orm import RefreshToken
from database import get_db, engine, SessionLocal
from models.expense_orm import Expense
from models.auth import RegisterRequest, AuthResponse, RefreshRequest, LoginRequest
from models.user_orm import User
from services.auth import hash_password, create_access_token, create_refresh_token, verify_password,get_current_user,decode_token
from datetime import date, datetime, timezone
from services.feasibility import analyze_goal_feasibility
from models.feasibility import GoalFeasibilityResponse
from models.category_orm import Category
from models.merchant_orm import Merchant
from models.merchant_category_learning_orm import MerchantCategoryLearning
from models.source_orm import Source
from models.expense import ExpenseCreate, ExpenseResponse
from pydantic import BaseModel, ConfigDict
from typing import Dict, Any, List, Optional
from models.expense_orm import Expense
from models.goal import GoalCreate, GoalResponse
from models.goal_orm import Goal
from config import SECRET_KEY, ALGORITHM
from services.coaching_feed import build_coaching_feed
from services.opportunities import (
    identify_category_overspend_opportunities,
    identify_high_frequency_expenses,
    identify_recurring_patterns
)
from models.feedback import FeedbackCreate
from models.feedback_orm import Feedback
from services.personalization import apply_personalization
from services.ai_coach import rephrase_insights
from jose import jwt, JWTError
import logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s"
)

logger = logging.getLogger("expense-tracker")

from services.ingestion import create_expense_from_input
from services.ingestion_service import process_ingestion
from models.ingestion_log_orm import IngestionLog
from services.ingestion import INPUT_TYPE_TO_SOURCE
from fastapi import UploadFile, File
from pathlib import Path
import uuid

from services.ocr_utils import save_upload_file, image_from_bytes
import pytesseract
from pdf2image import convert_from_bytes


from models.budget_orm import Budget
from models.budget import BudgetRequest

from sqlalchemy import text, func
from models.base import Base
from PIL import Image , ImageEnhance, ImageFilter
import numpy as np
from routers.google_auth import router as google_auth_router



app = FastAPI()

Base.metadata.create_all(bind=engine)
app.include_router(google_auth_router)
DEFAULT_SOURCE_NAMES = (
    "manual",
    "sms",
    "email",
    "notification",
    "bank_sync",
    "csv_import",
    "statement_upload",
    "api",
    "webhook",
)


def seed_default_sources(db: Session) -> int:
    existing_source_names = {
        name.strip().lower()
        for (name,) in db.query(Source.name).all()
        if name
    }

    missing_source_names = [
        name
        for name in DEFAULT_SOURCE_NAMES
        if name.lower() not in existing_source_names
    ]

    if not missing_source_names:
        return 0

    db.add_all([Source(name=name) for name in missing_source_names])
    db.commit()

    logger.info(
        "Seeded source values: %s",
        ", ".join(missing_source_names)
    )
    return len(missing_source_names)


@app.on_event("startup")
def ensure_source_seed_data():
    db = SessionLocal()
    try:
        seed_default_sources(db)
    except Exception:
        db.rollback()
        logger.exception("Failed to seed source reference data")
        raise
    finally:
        db.close()

@app.get("/health")
def health_check():
    try:
        with engine.connect() as connection:
            connection.execute(text("SELECT 1"))
        logger.info("Health check passed")
        return {
            "status": "ok",
            "database": "connected"
        }
    except Exception as e:
        logger.error("Health check failed", exc_info=True)
        return {
            "status": "error",
            "database": "unreachable"
        }


@app.get("/")
def root():
    return {"message": "Hello, the server is running"}


@app.post("/expenses", response_model=ExpenseResponse)
def create_expense(
    expense: ExpenseCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    # Delegate to ingestion layer; keep endpoint free of business logic
    try:
        return create_expense_from_input(
            db=db,
            user=current_user,
            input_type=(expense.source_name or "manual"),
            payload=expense.model_dump(),
        )
    except HTTPException:
        # pass through HTTP errors from service layer
        raise
    except Exception as exc:
        logger.exception("create_expense.handler_failure user_id=%s", getattr(current_user, "id", None))
        db.rollback()
        raise HTTPException(status_code=500, detail=str(exc))


class IngestionRequest(BaseModel):
    input_type: str
    payload: Dict[str, Any]


class IngestionLogResponse(BaseModel):
    id: int
    input_type: str
    status: str
    confidence_score: Optional[float] = None
    parsed_amount: Optional[float] = None
    parsed_category: Optional[str] = None
    parsed_merchant: Optional[str] = None
    expense_id: Optional[int] = None
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class ApproveRequest(BaseModel):
    merchant_name: Optional[str] = None
    category_name: Optional[str] = None


@app.post("/ingest")
def ingest(
    req: IngestionRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    logger.info("ingest.submit input_type=%s user_id=%s", req.input_type, getattr(current_user, "id", None))

    # create pending log and process synchronously for now
    try:
        log = process_ingestion(
            db=db,
            user=current_user,
            input_type=req.input_type,
            raw_text=req.payload.get("raw_text") if req.payload and "raw_text" in req.payload else None,
            payload=req.payload,
            metadata=None,
        )
        return {"ingestion_id": log.id, "status": log.status}
    except HTTPException:
        raise
    except Exception as exc:
        logger.exception("ingest.failure input_type=%s user_id=%s", req.input_type, getattr(current_user, "id", None))
        raise HTTPException(status_code=500, detail=str(exc))


@app.post("/ingest/ocr", response_model=IngestionLogResponse)
async def ingest_ocr(
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    uploads_dir = Path("uploads") / "receipts"
    uploads_dir.mkdir(parents=True, exist_ok=True)

    try:
        dest_path, file_bytes = save_upload_file(file, uploads_dir)
    except Exception:
        logger.exception("ingest_ocr.save_failure user_id=%s", getattr(current_user, "id", None))
        raise HTTPException(status_code=500, detail="Failed to save upload")

    try:
        # Extract text
        if file.content_type == "application/pdf":
            pages = convert_from_bytes(file_bytes, first_page=1, last_page=1)
            if not pages:
                raise Exception("No pages found in PDF")
            img = pages[0]
        else:
            img = image_from_bytes(file_bytes)

        

        # ----------------------------------------------------
        # STABLE OCR PREPROCESSING (Production-Style)
        # ----------------------------------------------------

        import numpy as np
        import cv2
        from PIL import Image
        import pytesseract

        # Convert PIL to OpenCV
        img_np = np.array(img)

        # 1️⃣ Auto-rotate using Tesseract OSD
        try:
            osd = pytesseract.image_to_osd(img_np)
            rotation = int(re.search(r"Rotate: (\d+)", osd).group(1))
            if rotation != 0:
                img_np = cv2.rotate(
                    img_np,
                    {
                        90: cv2.ROTATE_90_CLOCKWISE,
                        180: cv2.ROTATE_180,
                        270: cv2.ROTATE_90_COUNTERCLOCKWISE
                    }[rotation]
                )
        except Exception:
            pass  # If OSD fails, continue

        # 2️⃣ Convert to grayscale (proper)
        gray = cv2.cvtColor(img_np, cv2.COLOR_BGR2GRAY)

        # 3️⃣ Resize to stable DPI equivalent (~300 DPI height baseline)
        target_height = 2000
        scale = target_height / gray.shape[0]
        gray = cv2.resize(gray, None, fx=scale, fy=scale, interpolation=cv2.INTER_CUBIC)

        # 4️⃣ Adaptive threshold (critical for receipts)
        thresh = cv2.adaptiveThreshold(
            gray,
            255,
            cv2.ADAPTIVE_THRESH_GAUSSIAN_C,
            cv2.THRESH_BINARY,
            31,
            15
        )

        # 5️⃣ Light morphological close to join broken characters
        kernel = np.ones((2,2), np.uint8)
        processed = cv2.morphologyEx(thresh, cv2.MORPH_CLOSE, kernel)

        # OCR config tuned for receipts
        custom_config = r'--oem 3 --psm 6'

        raw_text = pytesseract.image_to_string(processed, config=custom_config)

        raw_text = "\n".join(
            [ln.strip() for ln in raw_text.splitlines() if ln.strip()]
        )

        print("Processed size:", processed.shape)
        print("----- RAW OCR TEXT -----")
        print(raw_text)
        print("------------------------")

    except Exception:
        logger.exception("ingest_ocr.ocr_failure user_id=%s", getattr(current_user, "id", None))
        raise HTTPException(status_code=500, detail="OCR extraction failed")

    try:
        # IMPORTANT: DO NOT use relative_to()
        safe_relative_path = f"receipts/{dest_path.name}"

        log = process_ingestion(
            db=db,
            user=current_user,
            input_type="ocr",
            raw_text=raw_text,
            payload=None,
            metadata={"file_path": safe_relative_path},
        )

        return IngestionLogResponse.from_orm(log)

    except Exception:
        logger.exception("ingest_ocr.processing_failure user_id=%s", getattr(current_user, "id", None))
        raise HTTPException(status_code=500, detail="Ingestion processing failed")


@app.get("/ingestion-logs")
def get_ingestion_logs(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    logs = (
        db.query(IngestionLog)
        .filter(IngestionLog.user_id == current_user.id)
        .order_by(IngestionLog.created_at.desc())
        .all()
    )

    return [
        {
            "id": l.id,
            "input_type": l.input_type,
            "raw_payload": l.raw_payload,
            "parsed_amount": l.parsed_amount,
            "parsed_merchant": l.parsed_merchant,
            "parsed_category": l.parsed_category,
            "confidence_score": l.confidence_score,
            "status": l.status,
            "expense_id": l.expense_id,
            "error_message": l.error_message,
            "created_at": l.created_at,
        }
        for l in logs
    ]


@app.get("/ingestion/{ingestion_id}")
def get_ingestion_log(
    ingestion_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    log = db.query(IngestionLog).filter(IngestionLog.id == ingestion_id, IngestionLog.user_id == current_user.id).first()
    if not log:
        raise HTTPException(status_code=404, detail="Ingestion log not found")

    return {
        "id": log.id,
        "status": log.status,
        "confidence_score": log.confidence_score,
        "parsed_data": {
            "amount": log.parsed_amount,
            "category": log.parsed_category,
            "merchant": log.parsed_merchant,
        },
        "expense_id": log.expense_id,
        "error_message": log.error_message,
    }


@app.patch("/ingestion/{ingestion_id}/approve", response_model=IngestionLogResponse)
def approve_ingestion(
    ingestion_id: int,
    data: ApproveRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    log = (
        db.query(IngestionLog)
        .filter(
            IngestionLog.id == ingestion_id,
            IngestionLog.user_id == current_user.id
        )
        .first()
    )

    if not log:
        raise HTTPException(status_code=404, detail="Ingestion log not found")

    if log.status != "needs_review":
        raise HTTPException(
            status_code=400,
            detail="Only logs with status 'needs_review' can be approved"
        )

    amount = log.parsed_amount
    category_name = data.category_name or log.parsed_category
    merchant_name = data.merchant_name or log.parsed_merchant

    if amount is None:
        raise HTTPException(
            status_code=400,
            detail="No parsed amount available"
        )

    # Determine transaction date
    td_val = date.today()

    try:
        # -----------------------------
        # Resolve / Create Category
        # -----------------------------
        category_obj = None
        if category_name:
            category_name = category_name.strip()
            category_obj = (
                db.query(Category)
                .filter(
                    Category.user_id == current_user.id,
                    Category.name == category_name
                )
                .first()
            )
            if not category_obj:
                category_obj = Category(
                    user_id=current_user.id,
                    name=category_name
                )
                db.add(category_obj)
                db.flush()

        # -----------------------------
        # Resolve / Create Merchant
        # -----------------------------
        merchant_obj = None
        if merchant_name:
            merchant_name = merchant_name.strip()
            merchant_obj = (
                db.query(Merchant)
                .filter(Merchant.name == merchant_name)
                .first()
            )
            if not merchant_obj:
                merchant_obj = Merchant(name=merchant_name)
                db.add(merchant_obj)
                db.flush()

        # -----------------------------
        # Resolve Source
        # -----------------------------
        requested_source_name = INPUT_TYPE_TO_SOURCE.get(
            log.input_type,
            log.input_type
        )

        source_obj = (
            db.query(Source)
            .filter(func.lower(Source.name) == requested_source_name.lower())
            .first()
        )

        if not source_obj:
            raise HTTPException(
                status_code=400,
                detail="Invalid or unknown source"
            )

        # -----------------------------
        # Create Expense
        # -----------------------------
        db_expense = Expense(
            user_id=current_user.id,
            amount=amount,
            transaction_date=td_val,
            category_id=category_obj.id if category_obj else None,
            merchant_id=merchant_obj.id if merchant_obj else None,
            source_id=source_obj.id,
            ingestion_type=log.input_type,
        )

        db.add(db_expense)
        db.flush()

        # -----------------------------
        # Update Log
        # -----------------------------
        log.status = "parsed"
        log.expense_id = db_expense.id
        log.confidence_score = log.confidence_score or 1.0
        db.add(log)

        # -----------------------------
        # Persist Merchant Learning
        # -----------------------------
        if merchant_name and category_name:
            merchant_key = merchant_name.lower().strip()

            exists = (
                db.query(MerchantCategoryLearning)
                .filter(
                    MerchantCategoryLearning.user_id == current_user.id,
                    MerchantCategoryLearning.merchant_key == merchant_key
                )
                .first()
            )

            if not exists:
                learning = MerchantCategoryLearning(
                    user_id=current_user.id,
                    merchant_key=merchant_key,
                    category_name=category_name
                )
                db.add(learning)

        db.commit()
        db.refresh(log)

        return IngestionLogResponse.from_orm(log)

    except HTTPException:
        raise
    except Exception as exc:
        db.rollback()
        logger.exception(
            "approve_ingestion.failure ingestion_id=%s user_id=%s",
            ingestion_id,
            getattr(current_user, "id", None)
        )
        raise HTTPException(status_code=500, detail=str(exc))


@app.patch("/ingestion/{ingestion_id}/reject", response_model=IngestionLogResponse)
def reject_ingestion(
    ingestion_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    log = db.query(IngestionLog).filter(IngestionLog.id == ingestion_id, IngestionLog.user_id == current_user.id).first()
    if not log:
        raise HTTPException(status_code=404, detail="Ingestion log not found")

    if log.status != "needs_review":
        raise HTTPException(status_code=400, detail="Only logs with status 'needs_review' can be rejected")

    try:
        log.status = "rejected"
        db.add(log)
        db.commit()
        db.refresh(log)
        return IngestionLogResponse.from_orm(log)
    except Exception as exc:
        db.rollback()
        logger.exception("reject_ingestion.failure ingestion_id=%s user_id=%s", ingestion_id, getattr(current_user, "id", None))
        raise HTTPException(status_code=500, detail=str(exc))


@app.get("/ingestion")
def list_ingestion_logs(
    status: Optional[str] = None,
    limit: int = 20,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    q = db.query(IngestionLog).filter(IngestionLog.user_id == current_user.id)
    if status:
        q = q.filter(IngestionLog.status == status)

    logs = q.order_by(IngestionLog.created_at.desc()).limit(limit).all()

    class IngestionLogResponse(BaseModel):
        id: int
        input_type: str
        status: str
        confidence_score: Optional[float] = None
        parsed_amount: Optional[float] = None
        parsed_category: Optional[str] = None
        parsed_merchant: Optional[str] = None
        expense_id: Optional[int] = None
        created_at: datetime

        model_config = ConfigDict(from_attributes=True)

    return [IngestionLogResponse.from_orm(l) for l in logs]



@app.get("/expenses", response_model=list[ExpenseResponse])
def get_expenses(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    expenses = ( db.query(Expense).filter(
        Expense.user_id == current_user.id
    )
    .order_by(Expense.created_at.desc())
    .all()
    )
    response = []

    for e in expenses:
        response.append(
            ExpenseResponse(
                id=e.id,
                amount=e.amount,
                transaction_date=e.transaction_date,
                category_name=e.category.name if e.category else None,
                merchant_name=e.merchant.name if e.merchant else None,
                source_name=e.source.name if e.source else None,
                created_at=e.created_at
            )
        )

    return response

@app.put("/expenses/{expense_id}", response_model=ExpenseResponse)
def update_expense(
    expense_id: int,
    expense: ExpenseCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    db_expense = db.query(Expense).filter(
        Expense.id == expense_id,
        Expense.user_id == current_user.id
    ).first()

    if not db_expense:
        raise HTTPException(status_code=404, detail="Expense not found")

    # Update fields
    db_expense.amount = expense.amount
    db_expense.transaction_date = expense.transaction_date

    # Category
    category = None
    if expense.category_name:
        category = db.query(Category).filter(
            Category.user_id == current_user.id,
            Category.name == expense.category_name
        ).first()

        if not category:
            category = Category(
                user_id=current_user.id,
                name=expense.category_name
            )
            db.add(category)
            db.commit()
            db.refresh(category)

    db_expense.category_id = category.id if category else None

    # Merchant
    merchant = None
    if expense.merchant_name:
        merchant = db.query(Merchant).filter(
            Merchant.name == expense.merchant_name
        ).first()

        if not merchant:
            merchant = Merchant(name=expense.merchant_name)
            db.add(merchant)
            db.commit()
            db.refresh(merchant)

    db_expense.merchant_id = merchant.id if merchant else None

    db.commit()
    db.refresh(db_expense)

    return ExpenseResponse(
        id=db_expense.id,
        amount=db_expense.amount,
        transaction_date=db_expense.transaction_date,
        category_name=db_expense.category.name if db_expense.category else None,
        merchant_name=db_expense.merchant.name if db_expense.merchant else None,
        source_name=db_expense.source.name if db_expense.source else None,
        created_at=db_expense.created_at
    )

@app.delete("/expenses/{expense_id}")
def delete_expense(
    expense_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    db_expense = db.query(Expense).filter(
        Expense.id == expense_id,
        Expense.user_id == current_user.id
    ).first()

    if not db_expense:
        raise HTTPException(status_code=404, detail="Expense not found")

    try:
        # Detach ingestion logs first
        db.query(IngestionLog).filter(
            IngestionLog.expense_id == expense_id
        ).update({"expense_id": None})

        db.delete(db_expense)
        db.commit()

        return {"message": "Expense deleted"}

    except Exception:
        db.rollback()
        logger.exception("delete_expense.failure expense_id=%s user_id=%s",
                         expense_id, getattr(current_user, "id", None))
        raise HTTPException(status_code=500, detail="Failed to delete expense")

@app.post("/goals", response_model=GoalResponse)
def create_goal(
    goal: GoalCreate,
    db: Session = Depends(get_db)
):
    db_goal = Goal(
        name=goal.name,
        target_amount=goal.target_amount,
        target_date=goal.target_date,
        priority=goal.priority
    )

    db.add(db_goal)
    db.commit()
    db.refresh(db_goal)

    return GoalResponse(
        id=db_goal.id,
        name=db_goal.name,
        target_amount=db_goal.target_amount,
        target_date=db_goal.target_date,
        priority=db_goal.priority,
        created_at=db_goal.created_at
    )

@app.get("/goals", response_model=list[GoalResponse])
def get_goals(db: Session = Depends(get_db)):
    goals = db.query(Goal).all()

    return [
        GoalResponse(
            id=g.id,
            name=g.name,
            target_amount=g.target_amount,
            target_date=g.target_date,
            priority=g.priority,
            created_at=g.created_at
        )
        for g in goals
    ]

@app.get(
    "/goals/{goal_id}/feasibility",
    response_model=GoalFeasibilityResponse
)
def get_goal_feasibility(
    goal_id: int,
    db: Session = Depends(get_db)
):
    # 1. Fetch goal
    goal = db.query(Goal).filter(Goal.id == goal_id).first()
    if not goal:
        raise HTTPException(status_code=404, detail="Goal not found")

    # 2. Fetch expenses
    expenses = db.query(Expense).all()

    # 3. Adapt data for service layer
    expense_data = [
        {
            "amount": e.amount,
            "date": e.transaction_date
        }
        for e in expenses
    ]

    goal_data = {
        "id": goal.id,
        "target_amount": goal.target_amount,
        "target_date": goal.target_date
    }

    # 4. Call feasibility engine
    result = analyze_goal_feasibility(
        expenses=expense_data,
        goal=goal_data,
        today=date.today()
    )

    return result

@app.get("/coaching-feed/{goal_id}")
def get_coaching_feed(
    goal_id: int,
    db: Session = Depends(get_db)
):
    # Fetch goal
    goal = db.query(Goal).filter(Goal.id == goal_id).first()
    if not goal:
        raise HTTPException(status_code=404, detail="Goal not found")

    # Fetch expenses
    expenses = db.query(Expense).all()

    expense_data = [
        {
            "amount": e.amount,
            "category": e.category,
            "merchant": getattr(e, "merchant", None),
            "date": e.transaction_date
        }
        for e in expenses
    ]

    goal_data = {
        "id": goal.id,
        "target_amount": goal.target_amount,
        "target_date": goal.target_date
    }

    feasibility = analyze_goal_feasibility(
        expenses=expense_data,
        goal=goal_data,
        today=date.today()
    )

    opportunities = []
    opportunities += identify_category_overspend_opportunities(expense_data)
    opportunities += identify_high_frequency_expenses(expense_data)
    opportunities += identify_recurring_patterns(expense_data)

    # Build base coaching feed
    feed = build_coaching_feed(feasibility, opportunities)

    # Fetch all feedback
    feedback_entries = db.query(Feedback).all()

    feedback_data = [
        {
            "insight_type": f.insight_type,
            "insight_reference": f.insight_reference,
            "action": f.action,
            "created_at": f.created_at
        }
        for f in feedback_entries
    ]

    # Apply personalization
    personalized_feed = apply_personalization(feed, feedback_data)

    ai_feed = rephrase_insights(personalized_feed, tone="coach")

    return ai_feed



@app.post("/feedback")
def submit_feedback(
    feedback: FeedbackCreate,
    db: Session = Depends(get_db)
):
    db_feedback = Feedback(
        insight_type=feedback.insight_type,
        insight_reference=feedback.insight_reference,
        action=feedback.action
    )

    db.add(db_feedback)
    db.commit()
    db.refresh(db_feedback)

    return {"status": "feedback recorded"}



@app.post("/auth/register", response_model=AuthResponse)
def register_user(data: RegisterRequest, db: Session = Depends(get_db)):
    

    existing = db.query(User).filter(User.email == data.email).first()
    if existing:
        raise HTTPException(status_code=400, detail="Email already registered")

    hashed = hash_password(data.password)

    user = User(
        email=data.email,
        hashed_password=hashed,
        full_name=data.full_name,
        is_verified=True
    )

    db.add(user)
    db.commit()
    db.refresh(user)

    access_token = create_access_token(user)
    refresh_token, expires_at, jti= create_refresh_token(user.id)

    # 🔐 Hash refresh token before storing
    hashed_refresh = hash_password(refresh_token)

    db_refresh = RefreshToken(
        user_id=user.id,
        jti=jti,
        token_hash=hashed_refresh,
        expires_at=expires_at,
        revoked=False
    )

    db.add(db_refresh)
    db.commit()

    return AuthResponse(
    access_token=access_token,
    refresh_token=refresh_token
    )


@app.post("/auth/refresh", response_model=AuthResponse)
def refresh_token(data: RefreshRequest, db: Session = Depends(get_db)):
    try:
        payload = jwt.decode(
            data.refresh_token,
            SECRET_KEY,
            algorithms=[ALGORITHM]
        )

        if payload.get("type") != "refresh":
            raise HTTPException(status_code=401, detail="Invalid token type")

        user_id = int(payload.get("sub"))
        jti = payload.get("jti")


    except JWTError:
        raise HTTPException(status_code=401, detail="Invalid refresh token")

    # 🔎 Find latest active refresh token for user
    db_token = (
        db.query(RefreshToken)
        .filter(
            RefreshToken.jti == jti,
            RefreshToken.user_id == user_id
        )
        .first()
    )

    print("JWT JTI:", jti)

    if not db_token:
        raise HTTPException(status_code=401, detail="Invalid refresh token")

    # 🚨 REUSE DETECTION
    if db_token.revoked:
        # Revoke ALL active sessions for this user
        db.query(RefreshToken).filter(
            RefreshToken.user_id == user_id,
            RefreshToken.revoked == False
        ).update({"revoked": True})

        db.commit()

        raise HTTPException(
            status_code=401,
            detail="Refresh token reuse detected. All sessions revoked."
        )

    # Verify hashed token
    if not verify_password(data.refresh_token, db_token.token_hash):
        raise HTTPException(status_code=401, detail="Invalid refresh token")

    # Expiry check
    if db_token.expires_at < datetime.now(timezone.utc):
        raise HTTPException(status_code=401, detail="Refresh token expired")

    #Verify user exist 
    user = db.query(User).filter(User.id == user_id).first()

    if not user:
        raise HTTPException(status_code=401, detail="User not found")


    # 🔄 Rotation: revoke old
    db_token.revoked = True
    db.commit()

    # 🔁 Issue new tokens
    new_access = create_access_token(user)
    new_refresh, expires_at , new_jti = create_refresh_token(user_id)

    hashed_refresh = hash_password(new_refresh)

    db_new_refresh = RefreshToken(
        user_id=user_id,
        jti=new_jti,
        token_hash=hashed_refresh,
        expires_at=expires_at,
        revoked=False
    )

    db.add(db_new_refresh)
    db.commit()

    return AuthResponse(
        access_token=new_access,
        refresh_token=new_refresh
    )



@app.post("/auth/logout")
def logout(data: RefreshRequest, db: Session = Depends(get_db)):
    payload = decode_token(data.refresh_token)

    if not payload or payload.get("type") != "refresh":
        raise HTTPException(status_code=401, detail="Invalid refresh token")

    user_id = int(payload.get("sub"))
    jti = payload.get("jti")

    db_token = (
        db.query(RefreshToken)
        .filter(
            RefreshToken.user_id == user_id,
            RefreshToken.jti == jti,
            RefreshToken.revoked == False
        )
        .first()
    )

    if not db_token:
        raise HTTPException(status_code=401, detail="Token not found")

    db_token.revoked = True
    db.commit()

    return {"message": "Logged out successfully"}


@app.post("/auth/logout-all")
def logout_all(data: RefreshRequest, db: Session = Depends(get_db)):
    payload = decode_token(data.refresh_token)

    if not payload or payload.get("type") != "refresh":
        raise HTTPException(status_code=401, detail="Invalid refresh token")

    user_id = int(payload.get("sub"))

    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=401, detail="User not found")

    # 🔐 Invalidate ALL access tokens
    user.token_version += 1

    # 🔐 Revoke ALL refresh tokens
    db.query(RefreshToken).filter(
        RefreshToken.user_id == user_id,
        RefreshToken.revoked == False
    ).update({"revoked": True})

    db.commit()

    return {"message": "Logged out from all devices"}




@app.post("/auth/login", response_model=AuthResponse)
def login(data: LoginRequest, db: Session = Depends(get_db)):

    user = db.query(User).filter(User.email == data.email).first()
   

    if not user:
        raise HTTPException(status_code=401, detail="Invalid credentials")

    if not verify_password(data.password, user.hashed_password):
        raise HTTPException(status_code=401, detail="Invalid credentials")

    # 🔹 Create access token
    access_token = create_access_token(user)
    
    # 🔹 Create refresh token
    refresh_token, expires_at, jti = create_refresh_token(user.id)

    hashed_refresh = hash_password(refresh_token)

    db_refresh = RefreshToken(
        user_id=user.id,
        jti=jti,
        token_hash=hashed_refresh,
        expires_at=expires_at,
        revoked=False
    )

    db.add(db_refresh)
    db.commit()

    return AuthResponse(
        access_token=access_token,
        refresh_token=refresh_token
    )

@app.get("/budget")
def get_budget(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    budget = db.query(Budget).filter(
        Budget.user_id == current_user.id
    ).first()

    if not budget:
        return {"monthly_amount": 50000}  # default

    return {"monthly_amount": float(budget.monthly_amount)}



@app.post("/budget")
def set_budget(
    data: BudgetRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    amount = data.amount

    budget = db.query(Budget).filter(
        Budget.user_id == current_user.id
    ).first()

    if not budget:
        budget = Budget(
            user_id=current_user.id,
            monthly_amount=amount
        )
        db.add(budget)
    else:
        budget.monthly_amount = amount

    db.commit()

    return {"monthly_amount": float(budget.monthly_amount)}

