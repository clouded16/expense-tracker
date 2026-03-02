# services/ingestion_v2/receipt_model.py

from dataclasses import dataclass, field
from typing import List, Optional


@dataclass
class ReceiptLine:
    index: int
    raw: str
    normalized: str


@dataclass
class ReceiptStructure:
    all_lines: List[ReceiptLine] = field(default_factory=list)
    header_lines: List[ReceiptLine] = field(default_factory=list)
    body_lines: List[ReceiptLine] = field(default_factory=list)
    total_lines: List[ReceiptLine] = field(default_factory=list)
    footer_lines: List[ReceiptLine] = field(default_factory=list)

    

@dataclass
class ExtractedFields:
    amount: Optional[float] = None
    transaction_date: Optional[str] = None
    merchant_name: Optional[str] = None
    category_name: Optional[str] = None
    confidence: float = 0.0