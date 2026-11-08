from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from database import get_db
from models.investment import (
    InvestmentOptionOut,
    InvestmentRecommendationResponse,
    PortfolioCreateRequest,
    PortfolioSummaryOut,
)
from models.user_orm import User
from services.auth import get_current_user
from services.investment_service import (
    add_to_portfolio,
    delete_portfolio_item,
    get_options_by_type,
    get_portfolio_summary,
    get_recommendations,
)


router = APIRouter(prefix="/investment", tags=["investment"])


@router.get("/recommendations", response_model=InvestmentRecommendationResponse)
def investment_recommendations(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return get_recommendations(db=db, user_id=current_user.id)


@router.get("/options/{investment_type}", response_model=list[InvestmentOptionOut])
def investment_options_by_type(
    investment_type: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    del current_user
    return get_options_by_type(db=db, investment_type=investment_type)


@router.post("/portfolio")
def create_portfolio_item(
    payload: PortfolioCreateRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    try:
        row = add_to_portfolio(
            db=db,
            user_id=current_user.id,
            investment_id=payload.investment_id,
            invested_amount=payload.invested_amount,
            start_date=payload.start_date,
        )
    except ValueError as exc:
        raise HTTPException(status_code=404, detail=str(exc))

    return {"id": row.id, "message": "Added to portfolio"}


@router.get("/portfolio", response_model=PortfolioSummaryOut)
def portfolio_summary(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return get_portfolio_summary(db=db, user_id=current_user.id)


@router.delete("/portfolio/{portfolio_id}")
def remove_portfolio_item(
    portfolio_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    deleted = delete_portfolio_item(db=db, user_id=current_user.id, portfolio_id=portfolio_id)
    if not deleted:
        raise HTTPException(status_code=404, detail="Portfolio item not found")
    return {"message": "Portfolio item deleted"}

