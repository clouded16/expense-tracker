from typing import Dict, Literal

from pydantic import BaseModel


class Insight(BaseModel):
    type: Literal["overspend", "recurring", "feasibility", "frequency"]
    priority: Literal["low", "medium", "high"]
    title: str
    message: str
    metadata: Dict[str, object]
    score: int
