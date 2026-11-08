from sqlalchemy import Column, Integer, Float, Date, ForeignKey, TIMESTAMP
from sqlalchemy.sql import func

from models.base import Base


class UserPortfolio(Base):
    __tablename__ = "user_portfolio"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    investment_id = Column(Integer, ForeignKey("investment_options.id"), nullable=False, index=True)
    invested_amount = Column(Float, nullable=False)
    start_date = Column(Date, nullable=False)
    created_at = Column(TIMESTAMP, server_default=func.now())

