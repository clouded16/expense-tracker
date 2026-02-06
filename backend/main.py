from fastapi import FastAPI
from models.expense import ExpenseCreate, ExpenseResponse


app = FastAPI()

@app.get("/")
def root():
    return {"message": "Hello, the server is running"}


@app.post("/expenses")
def create_expense(expense: ExpenseCreate):
    return {
        "status": "received",
        "expense": expense
    }


@app.get("/expenses", response_model=list[ExpenseResponse])
def get_expenses():
    return [
        {
            "amount": 120.0,
            "category": "Transport",
            "description": "Bus ticket",
            "date": "2026-02-05"
        },
        {
            "amount": 300.0,
            "category": "Food",
            "description": "Dinner",
            "date": "2026-02-06"
        }
    ]
