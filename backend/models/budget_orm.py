from sqlalchemy import Column, Integer, Numeric, ForeignKey
from models.base import Base

class Budget(Base):
    __tablename__ = "budget"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    monthly_amount = Column(Numeric, nullable=False)