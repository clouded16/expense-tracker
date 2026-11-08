from datetime import date
from pydantic import BaseModel, Field


class InvestmentRecommendation(BaseModel):
    id: int
    type: str
    name: str
    risk: str
    expected_return: str
    price: float | None = None
    recommended_amount: float


class InvestmentRecommendationResponse(BaseModel):
    recommendations: list[InvestmentRecommendation]
    allocation: dict[str, int] = {}
    monthly_expenses: float
    estimated_income: float
    monthly_income: float | None = None
    monthly_savings: float
    savings_ratio: float
    insights: list[str]


class InvestmentOptionOut(BaseModel):
    id: int
    type: str
    name: str
    risk_level: str
    expected_return: float
    lock_in_period: str | None = None
    minimum_investment: float
    description: str | None = None


class PortfolioCreateRequest(BaseModel):
    investment_id: int
    invested_amount: float = Field(..., gt=0)
    start_date: date | None = None


class PortfolioItemOut(BaseModel):
    portfolio_id: int
    investment_id: int
    name: str
    type: str
    invested_amount: float
    expected_return: float
    start_date: date


class PortfolioSummaryOut(BaseModel):
    total_invested_amount: float
    expected_yearly_return: float
    breakdown: list[PortfolioItemOut]
    allocation_by_type: list[dict]
