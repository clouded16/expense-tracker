from sqlalchemy import BigInteger, Column, Float, Integer, String, TIMESTAMP
from sqlalchemy.sql import func

from models.base import Base


class Stock(Base):
    __tablename__ = "stocks"

    id = Column(Integer, primary_key=True, index=True)
    symbol = Column(String(32), nullable=False, unique=True, index=True)
    name = Column(String(255), nullable=True)
    price = Column(Float, nullable=True)
    change_percent = Column(Float, nullable=True)
    volume = Column(BigInteger, nullable=True)
    market_cap = Column(Float, nullable=True)
    expected_return = Column(Float, nullable=True)
    risk_level = Column(String(32), nullable=True)
    last_updated = Column(TIMESTAMP, server_default=func.now(), onupdate=func.now(), nullable=False)
