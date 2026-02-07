from datetime import date, datetime
from pydantic import BaseModel


class GoalCreate(BaseModel):
    name: str
    target_amount: float
    target_date: date
    priority: int = 1


class GoalResponse(BaseModel):
    id: int
    name: str
    target_amount: float
    target_date: date
    priority: int
    created_at: datetime
