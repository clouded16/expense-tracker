from sqlalchemy import Column, Float, Integer, String, TIMESTAMP
from sqlalchemy.sql import func

from models.base import Base


class MutualFund(Base):
    __tablename__ = "mutual_funds"

    id = Column(Integer, primary_key=True, index=True)
    scheme_code = Column(String(32), nullable=False, unique=True, index=True)
    scheme_name = Column(String(255), nullable=False)
    nav = Column(Float, nullable=True)
    one_year_return = Column(Float, nullable=True)
    risk_level = Column(String(32), nullable=True)
    last_updated = Column(TIMESTAMP, server_default=func.now(), onupdate=func.now(), nullable=False)
