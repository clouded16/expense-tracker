from sqlalchemy import Column, Integer, Float, String, Date, DateTime
from sqlalchemy.sql import func

from .base import Base

class Goal(Base):
    __tablename__ = "goals"
    id = Column(Integer, primary_key=True, index=True)

    name = Column(String, nullable=False)
    target_amount = Column(Float, nullable=False)
    target_date = Column(Date, nullable=False)

    priority = Column(Integer, default=1, nullable=False)

    created_at = Column(DateTime(timezone=True), server_default=func.now())
