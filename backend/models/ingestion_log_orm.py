from sqlalchemy import Column, Integer, String, Float, DateTime, ForeignKey
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import relationship
from datetime import datetime
from models.base import Base


class IngestionLog(Base):
    __tablename__ = "ingestion_log"

    id = Column(Integer, primary_key=True, index=True)

    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    input_type = Column(String, nullable=False)

    raw_payload = Column(JSONB, nullable=True)

  
    parsed_amount = Column(Float, nullable=True)
    parsed_merchant = Column(String, nullable=True)
    parsed_category = Column(String, nullable=True)

    confidence_score = Column(Float, nullable=True)
    status = Column(String, nullable=False)

    expense_id = Column(Integer, ForeignKey("expense.id"), nullable=True)
    error_message = Column(String, nullable=True)

    created_at = Column(DateTime, default=datetime.utcnow)

    user = relationship("User")
    expense = relationship("Expense")