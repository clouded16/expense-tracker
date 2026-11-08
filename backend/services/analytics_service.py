from __future__ import annotations

from datetime import date
from decimal import Decimal
from typing import Any

from sqlalchemy import func
from sqlalchemy.orm import Session

from models.budget_orm import Budget
from models.category_orm import Category
from models.expense_orm import Expense
from models.merchant_orm import Merchant


def _to_float(value: Decimal | float | int | None) -> float:
    if value is None:
        return 0.0
    return float(value)


def _month_label(value: date) -> str:
    return value.strftime("%b %Y")


def get_monthly_expenses(db: Session, user_id: int, months: int = 12) -> list[dict[str, Any]]:
    rows = (
        db.query(
            func.date_trunc("month", Expense.transaction_date).label("month_bucket"),
            func.sum(Expense.amount).label("total"),
        )
        .filter(Expense.user_id == user_id)
        .group_by(func.date_trunc("month", Expense.transaction_date))
        .order_by(func.date_trunc("month", Expense.transaction_date).desc())
        .limit(months)
        .all()
    )
    return [
        {"month": _month_label(row.month_bucket.date()), "total": _to_float(row.total)}
        for row in reversed(rows)
    ]


def get_category_breakdown(db: Session, user_id: int) -> list[dict[str, Any]]:
    rows = (
        db.query(
            func.coalesce(Category.name, "Uncategorized").label("category"),
            func.sum(Expense.amount).label("amount"),
        )
        .outerjoin(Category, Category.id == Expense.category_id)
        .filter(Expense.user_id == user_id)
        .group_by(func.coalesce(Category.name, "Uncategorized"))
        .order_by(func.sum(Expense.amount).desc())
        .all()
    )
    return [{"category": row.category, "amount": _to_float(row.amount)} for row in rows]


def get_savings_trend(db: Session, user_id: int, months: int = 12) -> list[dict[str, Any]]:
    budget = db.query(Budget).filter(Budget.user_id == user_id).first()
    monthly_budget = float(budget.monthly_amount) if budget and budget.monthly_amount is not None else 0.0
    monthly_expenses = get_monthly_expenses(db, user_id, months=months)
    return [
        {
            "month": row["month"],
            "budget": monthly_budget,
            "expense": row["total"],
            "savings": round(monthly_budget - row["total"], 2),
        }
        for row in monthly_expenses
    ]


def get_top_merchants(db: Session, user_id: int, limit: int = 5) -> list[dict[str, Any]]:
    rows = (
        db.query(
            func.coalesce(Merchant.name, "Unknown merchant").label("merchant"),
            func.sum(Expense.amount).label("amount"),
        )
        .outerjoin(Merchant, Merchant.id == Expense.merchant_id)
        .filter(Expense.user_id == user_id)
        .group_by(func.coalesce(Merchant.name, "Unknown merchant"))
        .order_by(func.sum(Expense.amount).desc())
        .limit(limit)
        .all()
    )
    return [{"merchant": row.merchant, "amount": _to_float(row.amount)} for row in rows]


def get_financial_summary(db: Session, user_id: int) -> dict[str, float | str]:
    budget = db.query(Budget).filter(Budget.user_id == user_id).first()
    monthly_budget = float(budget.monthly_amount) if budget and budget.monthly_amount is not None else 0.0

    today = date.today()
    current_month_start = date(today.year, today.month, 1)
    next_month_start = date(today.year + (1 if today.month == 12 else 0), 1 if today.month == 12 else today.month + 1, 1)
    spent = (
        db.query(func.coalesce(func.sum(Expense.amount), 0))
        .filter(
            Expense.user_id == user_id,
            Expense.transaction_date >= current_month_start,
            Expense.transaction_date < next_month_start,
        )
        .scalar()
    )
    total_spent = _to_float(spent)
    budget_remaining = monthly_budget - total_spent
    total_saved = budget_remaining if monthly_budget > 0 else 0.0
    return {
        "month_name": today.strftime("%B %Y"),
        "total_spent": round(total_spent, 2),
        "total_saved": round(total_saved, 2),
        "budget_remaining": round(budget_remaining, 2),
        "monthly_budget": round(monthly_budget, 2),
    }


# Backward-compatible summary endpoint
def get_analytics_summary(db: Session, user_id: int) -> dict[str, Any]:
    category_breakdown = get_category_breakdown(db, user_id)
    total_amount = sum(item["amount"] for item in category_breakdown)
    category_totals = [
        {
            "category": item["category"],
            "amount": item["amount"],
            "percentage": (item["amount"] / total_amount * 100) if total_amount > 0 else 0.0,
        }
        for item in category_breakdown
    ]

    monthly_expenses = get_monthly_expenses(db, user_id)

    daily_rows = (
        db.query(Expense.transaction_date.label("date"), func.sum(Expense.amount).label("amount"))
        .filter(Expense.user_id == user_id)
        .group_by(Expense.transaction_date)
        .order_by(Expense.transaction_date)
        .all()
    )
    daily_spending = [{"date": row.date.isoformat(), "amount": _to_float(row.amount)} for row in daily_rows]

    return {
        "category_totals": category_totals,
        "monthly_trend": [{"month": row["month"], "total": row["total"]} for row in monthly_expenses],
        "daily_spending": daily_spending,
        "top_merchants": get_top_merchants(db, user_id),
        "category_comparison": [],
        "insights": [],
    }
