from sqlalchemy import Column, Integer, String, Float, TIMESTAMP
from sqlalchemy.sql import func

from models.base import Base


class InvestmentAsset(Base):
    __tablename__ = "investment_assets"

    id = Column(Integer, primary_key=True, index=True)
    asset_name = Column(String(255), nullable=False, index=True)
    asset_type = Column(String(100), nullable=False, index=True)
    risk_level = Column(String(20), nullable=False)
    expected_return = Column(Float, nullable=False)
    price = Column(Float, nullable=True)
    last_updated = Column(TIMESTAMP, server_default=func.now(), onupdate=func.now(), nullable=False)
