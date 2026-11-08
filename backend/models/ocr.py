from typing import Optional

from pydantic import BaseModel


class OCRScanResponse(BaseModel):
    merchant: Optional[str] = None
    amount: Optional[float] = None
    date: Optional[str] = None
    raw_text: str
