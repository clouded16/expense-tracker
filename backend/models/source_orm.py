from sqlalchemy import Column, Integer, Text, TIMESTAMP
from sqlalchemy.sql import func

from models.base import Base

class Source(Base):
    __tablename__ = "source"

    id = Column(Integer, primary_key=True)
    name = Column(Text, nullable=False)
    created_at = Column(TIMESTAMP, server_default=func.now())
