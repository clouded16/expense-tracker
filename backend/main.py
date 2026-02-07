from fastapi import FastAPI, Depends
from sqlalchemy.orm import Session
from datetime import date

from services.feasibility import analyze_goal_feasibility
from models.feasibility import GoalFeasibilityResponse
from database import get_db, create_tables
from models.expense import ExpenseCreate, ExpenseResponse
from models.expense_orm import Expense
from models.goal import GoalCreate, GoalResponse
from models.goal_orm import Goal





app = FastAPI()
create_tables()


@app.get("/")
def root():
    return {"message": "Hello, the server is running"}


@app.post("/expenses", response_model=ExpenseResponse)
def create_expense(
    expense: ExpenseCreate,
    db: Session = Depends(get_db)
):
    db_expense = Expense(
        amount=expense.amount,
        currency="INR",
        category=expense.category,
        merchant_raw=expense.description,
        source="manual",
        transaction_date=expense.date
    )

    db.add(db_expense)
    db.commit()
    db.refresh(db_expense)

    return ExpenseResponse(
    id=db_expense.id,
    amount=db_expense.amount,
    category=db_expense.category,
    description=db_expense.merchant_raw,
    date=db_expense.transaction_date
)




@app.get("/expenses", response_model=list[ExpenseResponse])
def get_expenses(db: Session = Depends(get_db)):
    expenses = db.query(Expense).all()
    return [
        ExpenseResponse(
            id=e.id,
            amount=e.amount,
            category=e.category,
            description=e.merchant_raw,
            date=e.transaction_date
        )
        for e in expenses
    ]


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
