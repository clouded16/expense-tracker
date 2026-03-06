import re
from typing import List
from .receipt_model import ReceiptStructure, ExtractedFields


ADDRESS_KEYWORDS = [
    "road", "street", "sector", "complex", "cross",
    "near", "district", "state", "floor", "village",
    "plot", "lane", "building"
]

META_KEYWORDS = [
    "gst", "gstin", "invoice", "bill", "date",
    "time", "mobile", "phone", "tel",
    "order", "transaction", "receipt no"
]

CATEGORY_RULES = {
    "coffee": "Food",
    "pizzeria": "Food",
    "restaurant": "Food",
    "dine": "Food",
    "cafe": "Food",
    "petrol": "Transport",
    "fuel": "Transport",
    "hp service": "Transport",
    "uber": "Transport",
    "ola": "Transport",
    "medical": "Health",
    "pharmacy": "Health",
    "mart": "Groceries",
    "supermarket": "Groceries",
}


class FieldClassifier:

    def classify(self, structure: ReceiptStructure) -> ExtractedFields:
        amount = self._extract_amount(structure)
        merchant = self._extract_merchant(structure)
        category = self._infer_category(merchant)

        return ExtractedFields(
            amount=amount,
            transaction_date=None,
            merchant_name=merchant,
            category_name=category,
            confidence=0.0,
        )

    # =====================================================
    # AMOUNT (unchanged strong logic)
    # =====================================================

    def _extract_amount(self, structure: ReceiptStructure):
        candidates = []

        search_lines = (
            structure.total_lines
            if structure.total_lines
            else structure.body_lines[-8:]
        )

        for line in search_lines:
            text = line.normalized.lower()
            numbers = re.findall(r"[0-9]+(?:\.[0-9]{1,2})?", text)

            for num in numbers:
                try:
                    value = float(num)
                except:
                    continue

                if value <= 0:
                    continue

                score = 0

                if "grand total" in text:
                    score += 100
                elif "amount payable" in text:
                    score += 90
                elif "net total" in text:
                    score += 80
                elif "total" in text:
                    score += 50

                if "." in num:
                    score += 10

                if line.index > len(structure.all_lines) * 0.6:
                    score += 10

                candidates.append((score, value))

        if not candidates:
            return None

        candidates.sort(key=lambda x: x[0], reverse=True)
        best_score, best_value = candidates[0]

        if best_score < 20:
            return None

        return round(best_value, 2)

    # =====================================================
    # MERCHANT — PRODUCTION GRADE SCORING
    # =====================================================

    def _normalize(self, text: str) -> str:
        text = text.upper()
        text = re.sub(r"[^A-Z\s.&-]", " ", text)
        text = re.sub(r"\s+", " ", text).strip()
        return text

    def _is_address_like(self, text: str) -> bool:
        lower = text.lower()
        return any(k in lower for k in ADDRESS_KEYWORDS)

    def _is_meta_line(self, text: str) -> bool:
        lower = text.lower()
        return any(k in lower for k in META_KEYWORDS)

    def _extract_merchant(self, structure: ReceiptStructure):

        lines = structure.header_lines or structure.all_lines[:6]
        candidates = []

        for idx, line in enumerate(lines[:6]):
            raw = line.normalized.strip()

            if len(raw) < 3:
                continue

            normalized = self._normalize(raw)

            if len(normalized) < 3:
                continue

            alpha_ratio = sum(c.isalpha() for c in normalized) / max(1, len(normalized))
            if alpha_ratio < 0.7:
                continue

            score = 0

            # Header priority
            score += max(0, 50 - idx * 8)

            # All uppercase boost
            if raw.isupper():
                score += 15

            # Penalize address lines
            if self._is_address_like(normalized):
                score -= 40

            # Penalize metadata lines
            if self._is_meta_line(normalized):
                score -= 50

            # Prefer medium-length names
            if 4 <= len(normalized) <= 35:
                score += 20

            candidates.append((score, normalized))

        if not candidates:
            return None

        candidates.sort(key=lambda x: x[0], reverse=True)
        best_score, best_value = candidates[0]

        if best_score < 25:
            return None

        return best_value.title()

    # =====================================================
    # CATEGORY — DETERMINISTIC RULE ENGINE
    # =====================================================

    def _infer_category(self, merchant: str | None) -> str | None:
        if not merchant:
            return None

        lower = merchant.lower()

        for keyword, category in CATEGORY_RULES.items():
            if keyword in lower:
                return category

        return None