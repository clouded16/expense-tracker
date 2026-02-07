from sqlalchemy import Column, Integer, Float, String, Date, DateTime
from sqlalchemy.sql import func

from .base import Base

class Expense(Base):
    __tablename__ = "expenses"
    id = Column(Integer, primary_key=True, index=True)

    amount = Column(Float, nullable=False)
    currency = Column(String, default="INR", nullable=False)

    category = Column(String, nullable=False)
    merchant_raw = Column(String, nullable=True)

    source = Column(String, nullable=False)

    transaction_date = Column(Date, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
