from sqlalchemy import Column, Float, Integer, String, TIMESTAMP
from sqlalchemy.sql import func

from models.base import Base


class GoldPrice(Base):
    __tablename__ = "gold_prices"

    id = Column(Integer, primary_key=True, index=True)
    live_price = Column(Float, nullable=False)
    daily_change = Column(Float, nullable=True)
    one_year_return = Column(Float, nullable=True)
    risk_level = Column(String(32), nullable=True)
    last_updated = Column(TIMESTAMP, server_default=func.now(), onupdate=func.now(), nullable=False)
