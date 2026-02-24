from pydantic import BaseModel, ConfigDict
from datetime import date , datetime
from typing import Optional

class ExpenseCreate(BaseModel):
    amount: float
    transaction_date: date
    category_name: Optional[str] = None
    merchant_name: Optional[str] = None
    source_name: Optional[str] = "manual"


class ExpenseResponse(BaseModel):
    id: int
    amount: float
    transaction_date: date
    category_name: Optional[str] = None
    merchant_name: Optional[str] = None
    source_name: Optional[str] = None
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)
