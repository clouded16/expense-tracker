from sqlalchemy import Column, Date, Float, ForeignKey, Integer, String, TIMESTAMP
from sqlalchemy.sql import func

from models.base import Base


class GoalsPortfolio(Base):
    __tablename__ = "goals_portfolio"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    asset_type = Column(String(64), nullable=False, index=True)
    asset_name = Column(String(255), nullable=False)
    invested_amount = Column(Float, nullable=False)
    expected_return = Column(Float, nullable=True)
    risk_level = Column(String(32), nullable=True)
    start_date = Column(Date, nullable=False)
    created_at = Column(TIMESTAMP, server_default=func.now(), nullable=False)
