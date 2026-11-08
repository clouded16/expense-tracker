from typing import Any

from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy.orm import Session

from database import get_db
from models.user_orm import User
from services.analytics_service import get_analytics_insights, get_analytics_summary
from services.auth import get_current_user


class CategoryTotalOut(BaseModel):
    category: str
    amount: float
    percentage: float


class MonthlyTrendOut(BaseModel):
    month: str
    total: float


class DailySpendingOut(BaseModel):
    date: str
    amount: float


class TopMerchantOut(BaseModel):
    merchant: str
    amount: float


class CategoryComparisonOut(BaseModel):
    category: str
    this_month: float
    last_month: float
    change_percentage: float


class AnalyticsSummaryOut(BaseModel):
    category_totals: list[CategoryTotalOut]
    monthly_trend: list[MonthlyTrendOut]
    daily_spending: list[DailySpendingOut]
    top_merchants: list[TopMerchantOut]
    category_comparison: list[CategoryComparisonOut]
    insights: list[str]


class AnalyticsInsightsOut(BaseModel):
    insights: list[str]


router = APIRouter(prefix="/analytics", tags=["analytics"])


@router.get("/summary", response_model=AnalyticsSummaryOut)
def analytics_summary(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> dict[str, Any]:
    return get_analytics_summary(db=db, user_id=current_user.id)


@router.get("/insights", response_model=AnalyticsInsightsOut)
def analytics_insights(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> dict[str, list[str]]:
    return get_analytics_insights(db=db, user_id=current_user.id)
