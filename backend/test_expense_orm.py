from datetime import date

from database import SessionLocal
from models.expense_orm import Expense

def test_expense_insert():
    db = SessionLocal()
    try:
        expense = Expense(
            user_id=1,
            amount=100.50,
            transaction_date=date.today()
        )
        db.add(expense)
        db.commit()
        db.refresh(expense)

        print("Inserted expense ID:", expense.id)

        fetched = db.query(Expense).first()
        print("Fetched amount:", fetched.amount)

    finally:
        db.close()

if __name__ == "__main__":
    test_expense_insert()
