from fastapi import FastAPI, Depends
from sqlalchemy.orm import Session

from database import get_db, create_tables
from models.expense import ExpenseCreate, ExpenseResponse
from models.expense_orm import Expense




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

