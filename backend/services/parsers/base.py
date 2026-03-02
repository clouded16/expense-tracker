from abc import ABC, abstractmethod
from typing import Any, Dict


class ParserBase(ABC):
    @abstractmethod
    def parse(self, raw_text: str | None, payload: Dict[str, Any] | None, metadata: Dict[str, Any] | None) -> Dict[str, Any]:
        """Return a dict with keys: amount, transaction_date, category_name, merchant_name, confidence_score"""
        raise NotImplementedError()
