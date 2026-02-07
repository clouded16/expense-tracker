from pydantic import BaseModel


class FeedbackCreate(BaseModel):
    insight_type: str
    insight_reference: str
    action: str
