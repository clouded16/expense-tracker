from pydantic import BaseModel


class GoalFeasibilityResponse(BaseModel):
    goal_id: int
    months_remaining: int
    required_monthly_savings: float | None
    observed_avg_monthly_spend: float | None
    feasibility_status: str
    message: str
