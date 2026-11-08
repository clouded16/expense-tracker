from datetime import date

from pydantic import BaseModel, Field


class PortfolioAddRequest(BaseModel):
    asset_type: str
    asset_name: str
    invested_amount: float = Field(..., gt=0)
    expected_return: float | None = None
    risk_level: str | None = None
    start_date: date | None = None


class PortfolioItemOut(BaseModel):
    id: int
    asset_type: str
    asset_name: str
    invested_amount: float
    expected_return: float | None = None
    risk_level: str | None = None
    start_date: date


class PortfolioSummaryOut(BaseModel):
    total_invested_amount: float
    expected_yearly_return: float
    items: list[PortfolioItemOut]
    allocation_by_type: list[dict]
