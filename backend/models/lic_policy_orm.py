from sqlalchemy import Column, Float, Integer, String, Text, TIMESTAMP
from sqlalchemy.sql import func

from models.base import Base


class LICPolicy(Base):
    __tablename__ = "lic_policies"

    id = Column(Integer, primary_key=True, index=True)
    policy_name = Column(String(255), nullable=False, unique=True, index=True)
    lock_in_period = Column(String(128), nullable=True)
    minimum_investment = Column(Float, nullable=True)
    policy_benefits = Column(Text, nullable=True)
    maturity_rules = Column(Text, nullable=True)
    risk_level = Column(String(32), nullable=True)
    source_url = Column(String(512), nullable=True)
    last_updated = Column(TIMESTAMP, server_default=func.now(), onupdate=func.now(), nullable=False)
