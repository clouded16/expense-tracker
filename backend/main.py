from fastapi import FastAPI, Depends, HTTPException
from sqlalchemy.orm import Session
from models.refresh_token_orm import RefreshToken
from database import get_db, engine
from models.expense_orm import Expense
from models.auth import RegisterRequest, AuthResponse, RefreshRequest, LoginRequest
from models.user_orm import User
from services.auth import hash_password, create_access_token, create_refresh_token, verify_password,get_current_user,decode_token
from datetime import date,datetime
from pydantic import BaseModel
from services.feasibility import analyze_goal_feasibility
from models.feasibility import GoalFeasibilityResponse
from models.category_orm import Category
from models.merchant_orm import Merchant
from models.source_orm import Source
from models.expense import ExpenseCreate, ExpenseResponse
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

from models.budget_orm import Budget
from models.budget import BudgetRequest

from sqlalchemy import text
from sqlalchemy import and_
from datetime import datetime, timezone
from passlib.context import CryptContext
from models.base import Base
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")



app = FastAPI()

Base.metadata.create_all(bind=engine)

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

    try:
        user_id = current_user.id


        # ---- Resolve Category (user-specific) ----
        category = None
        if expense.category_name:
            category = db.query(Category).filter(
                Category.user_id == user_id,
                Category.name == expense.category_name
            ).first()

            if not category:
                category = Category(
                    user_id=user_id,
                    name=expense.category_name
                )
                db.add(category)
                db.commit()
                db.refresh(category)

        # ---- Resolve Merchant (global) ----
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

        # ---- Resolve Source (fixed) ----
        source = db.query(Source).filter(
            Source.name == expense.source_name
        ).first()

        if not source:
            raise HTTPException(status_code=400, detail="Invalid source")

        # ---- Create Expense ----
        db_expense = Expense(
            user_id=user_id,
            amount=expense.amount,
            transaction_date=expense.transaction_date,
            category_id=category.id if category else None,
            merchant_id=merchant.id if merchant else None,
            source_id=source.id
        )

        db.add(db_expense)
        db.commit()
        db.refresh(db_expense)

        return ExpenseResponse(
            id=db_expense.id,
            amount=db_expense.amount,
            transaction_date=db_expense.transaction_date,
            category_name=category.name if category else None,
            merchant_name=merchant.name if merchant else None,
            source_name=source.name if source else None,
            created_at=db_expense.created_at
        )

    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=str(e))



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

    db.delete(db_expense)
    db.commit()

    return {"message": "Expense deleted"}

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


