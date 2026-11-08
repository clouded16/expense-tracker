from sqlalchemy import Column, Integer, String, Float, Text

from models.base import Base


class InvestmentOption(Base):
    __tablename__ = "investment_options"

    id = Column(Integer, primary_key=True, index=True)
    type = Column(String(50), nullable=False, index=True)
    name = Column(String(255), nullable=False)
    risk_level = Column(String(50), nullable=False)
    expected_return = Column(Float, nullable=False)
    lock_in_period = Column(String(100), nullable=True)
    minimum_investment = Column(Float, nullable=False)
    description = Column(Text, nullable=True)

