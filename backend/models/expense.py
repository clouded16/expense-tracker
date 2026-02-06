from pydantic import BaseModel
from datetime import date

class ExpenseCreate(BaseModel):
    amount: float
    category: str
    description: str
    date: date


class ExpenseResponse(BaseModel):
    amount: float
    category: str
    description: str
    date: date
