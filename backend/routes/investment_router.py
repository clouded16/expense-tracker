from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from database import get_db
from models.goals import PortfolioAddRequest, PortfolioSummaryOut
from models.user_orm import User
from services.auth import get_current_user
from services.investment_service import (
    add_goal_portfolio_item,
    delete_goal_portfolio_item,
    get_best_choice,
    get_fd_rates,
    get_goal_portfolio_summary,
    get_gold_price,
    get_lic_policies,
    get_market_assets,
    get_mutual_funds,
    get_stocks,
)

router = APIRouter(prefix="/api/goals", tags=["goals"])


@router.get("/mutual-funds")
async def mutual_funds(
    limit: int = Query(default=30, ge=1, le=100),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    del current_user
    try:
        return {"data": await get_mutual_funds(db, limit=limit)}
    except Exception as exc:
        raise HTTPException(status_code=503, detail=f"Unable to fetch mutual fund data: {exc}")


@router.get("/stocks")
async def stocks(
    limit: int = Query(default=50, ge=1, le=100),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    del current_user
    try:
        return {"data": await get_stocks(db, limit=limit)}
    except Exception as exc:
        raise HTTPException(status_code=503, detail=f"Unable to fetch stock data: {exc}")


@router.get("/gold")
async def gold(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    del current_user
    try:
        return {"data": await get_gold_price(db)}
    except Exception as exc:
        raise HTTPException(status_code=503, detail=f"Unable to fetch gold data: {exc}")


@router.get("/fd-rates")
async def fd_rates(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    del current_user
    try:
        return {"data": await get_fd_rates(db)}
    except Exception as exc:
        raise HTTPException(status_code=503, detail=f"Unable to fetch FD rates: {exc}")


@router.get("/lic-policies")
async def lic_policies(
    limit: int = Query(default=20, ge=1, le=100),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    del current_user
    try:
        return {"data": await get_lic_policies(db, limit=limit)}
    except Exception as exc:
        raise HTTPException(status_code=503, detail=f"Unable to fetch LIC policies: {exc}")


@router.get("/assets/{asset_type}")
async def market_assets(
    asset_type: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    del current_user
    try:
        return {"data": await get_market_assets(db, asset_type=asset_type.lower())}
    except Exception as exc:
        raise HTTPException(status_code=503, detail=f"Unable to fetch asset data: {exc}")


@router.get("/best-choice")
async def best_choice(
    monthly_income: float | None = Query(default=None),
    monthly_expenses: float | None = Query(default=None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    try:
        return await get_best_choice(
            db=db,
            user_id=current_user.id,
            monthly_income=monthly_income,
            monthly_expenses=monthly_expenses,
        )
    except Exception as exc:
        raise HTTPException(status_code=503, detail=f"Unable to build best choice recommendations: {exc}")


@router.post("/portfolio/add")
def add_portfolio_item(
    payload: PortfolioAddRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    row = add_goal_portfolio_item(
        db=db,
        user_id=current_user.id,
        asset_type=payload.asset_type,
        asset_name=payload.asset_name,
        invested_amount=payload.invested_amount,
        expected_return=payload.expected_return,
        risk_level=payload.risk_level,
        start_date=payload.start_date,
    )
    return {"id": row.id, "message": "Added to portfolio"}


@router.get("/portfolio", response_model=PortfolioSummaryOut)
def portfolio(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return get_goal_portfolio_summary(db=db, user_id=current_user.id)


@router.delete("/portfolio/{item_id}")
def delete_portfolio_item(
    item_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    deleted = delete_goal_portfolio_item(db=db, user_id=current_user.id, item_id=item_id)
    if not deleted:
        raise HTTPException(status_code=404, detail="Portfolio item not found")
    return {"message": "Portfolio item deleted"}
