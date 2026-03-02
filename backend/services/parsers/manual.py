from typing import Any, Dict
from datetime import datetime, date

from .base import ParserBase


class ManualParser(ParserBase):
    def parse(self, raw_text: str | None, payload: Dict[str, Any] | None, metadata: Dict[str, Any] | None) -> Dict[str, Any]:
        # Manual parser trusts provided structured payload; confidence = 1.0
        data = {
            "amount": None,
            "transaction_date": None,
            "category_name": None,
            "merchant_name": None,
            "confidence_score": 0.5,
        }

        if payload:
            if "amount" in payload:
                data["amount"] = payload.get("amount")
            if "transaction_date" in payload:
                data["transaction_date"] = payload.get("transaction_date")
            if "category_name" in payload:
                data["category_name"] = payload.get("category_name")
            if "merchant_name" in payload:
                data["merchant_name"] = payload.get("merchant_name")

        # if raw_text provided but no payload, try minimal extraction (not implemented)
        return data
