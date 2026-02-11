from fastapi import FastAPI, Depends, HTTPException
from sqlalchemy.orm import Session

from database import get_db
from models.expense_orm import Expense

from datetime import date
from pydantic import BaseModel

from services.feasibility import analyze_goal_feasibility
from models.feasibility import GoalFeasibilityResponse

from models.expense import ExpenseCreate, ExpenseResponse
from models.expense_orm import Expense
from models.goal import GoalCreate, GoalResponse
from models.goal_orm import Goal
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

import logging

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s"
)

logger = logging.getLogger("expense-tracker")

from sqlalchemy import text
from database import engine




app = FastAPI()

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




class ExpenseCreate(BaseModel):
    user_id: int
    amount: float
    transaction_date: date

@app.post("/expenses")
def create_expense(expense: ExpenseCreate, db: Session = Depends(get_db)):
    try:
        db_expense = Expense(
            user_id=expense.user_id,
            amount=expense.amount,
            transaction_date=expense.transaction_date
        )
        db.add(db_expense)
        db.commit()
        db.refresh(db_expense)
        return db_expense
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=str(e))




@app.get("/expenses")
def get_expenses(db: Session = Depends(get_db)):
    return db.query(Expense).all()



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
