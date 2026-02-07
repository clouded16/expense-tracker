from sqlalchemy import Column, Integer, String, DateTime
from datetime import datetime

from database import Base


class Feedback(Base):
    __tablename__ = "feedback"

    id = Column(Integer, primary_key=True, index=True)
    insight_type = Column(String, nullable=False)
    insight_reference = Column(String, nullable=False)
    action = Column(String, nullable=False)  # accept / ignore / snooze
    created_at = Column(DateTime, default=datetime.utcnow)
