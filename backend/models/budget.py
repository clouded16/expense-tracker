from pydantic import BaseModel

class BudgetRequest(BaseModel):
    amount: float