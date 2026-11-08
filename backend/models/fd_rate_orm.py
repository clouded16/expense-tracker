from sqlalchemy import Column, Float, Integer, String, TIMESTAMP
from sqlalchemy.sql import func

from models.base import Base


class FDRate(Base):
    __tablename__ = "fd_rates"

    id = Column(Integer, primary_key=True, index=True)
    bank_name = Column(String(128), nullable=False, unique=True, index=True)
    interest_rate = Column(Float, nullable=True)
    minimum_deposit = Column(Float, nullable=True)
    lock_in_period = Column(String(128), nullable=True)
    source_url = Column(String(512), nullable=True)
    last_updated = Column(TIMESTAMP, server_default=func.now(), onupdate=func.now(), nullable=False)
