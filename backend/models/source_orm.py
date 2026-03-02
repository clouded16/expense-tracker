from sqlalchemy import Column, Integer, String, TIMESTAMP
from sqlalchemy.sql import func

from models.base import Base

class Source(Base):
    __tablename__ = "source"

    id = Column(Integer, primary_key=True)
    name = Column(String(100), nullable=False, unique=True, index=True)
    created_at = Column(TIMESTAMP, server_default=func.now())
