from __future__ import annotations

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from database import get_db
from models.user_orm import User
from services.analytics_ai_service import get_ai_insights
from services.analytics_service import (
    get_analytics_summary,
    get_category_breakdown,
    get_financial_summary,
    get_monthly_expenses,
    get_savings_trend,
    get_top_merchants,
)
from services.auth import get_current_user

router = APIRouter(prefix="/api/analytics", tags=["analytics"])


@router.get("/summary")
def analytics_summary(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return {
        "financial_summary": get_financial_summary(db, current_user.id),
        **get_analytics_summary(db, current_user.id),
    }


@router.get("/monthly-expenses")
def monthly_expenses(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return get_monthly_expenses(db, current_user.id)


@router.get("/category-breakdown")
def category_breakdown(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return get_category_breakdown(db, current_user.id)


@router.get("/savings-trend")
def savings_trend(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return get_savings_trend(db, current_user.id)


@router.get("/top-merchants")
def top_merchants(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return get_top_merchants(db, current_user.id)


@router.get("/ai-insights")
def ai_insights(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return get_ai_insights(db, current_user.id)
