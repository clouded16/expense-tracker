from sqlalchemy import Column, Integer, Numeric, Date, ForeignKey, TIMESTAMP
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from models.base import Base


class Expense(Base):
    __tablename__ = "expense"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, nullable=False)
    amount = Column(Numeric, nullable=False)
    transaction_date = Column(Date, nullable=False)

    merchant_id = Column(Integer, ForeignKey("merchant.id"), nullable=True)
    category_id = Column(Integer, ForeignKey("category.id"), nullable=True)
    source_id = Column(Integer, ForeignKey("source.id"), nullable=True)

    created_at = Column(TIMESTAMP, server_default=func.now())

    # 🔥 ADD THESE RELATIONSHIPS
    category = relationship("Category")
    merchant = relationship("Merchant")
    source = relationship("Source")
