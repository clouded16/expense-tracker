import re
from typing import List
from .receipt_model import ReceiptStructure, ExtractedFields


REJECT_NEAR_KEYWORDS = [
    "mobile", "phone", "tel", "gstin",
    "invoice", "bill no", "order", "transaction",
]

NEGATIVE_CONTEXT = [
    "rate", "price", "qty", "quantity",
    "kg", "ltr", "litre", "density",
]

POSITIVE_CONTEXT_STRONG = ["grand total", "amount payable"]
POSITIVE_CONTEXT = ["total", "net total"]


class FieldClassifier:

    def classify(self, structure: ReceiptStructure) -> ExtractedFields:
        amount = self._extract_amount(structure)
        merchant = self._extract_merchant(structure)

        return ExtractedFields(
            amount=amount,
            transaction_date=None,
            merchant_name=merchant,
            category_name=None,
            confidence=0.0,
        )

    # ------------------------
    # HYBRID AMOUNT ENGINE
    # ------------------------

    def _extract_amount(self, structure: ReceiptStructure):
        import re

        candidates = []

        # Always search total zone first
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

                # Reject unrealistic numbers
                if len(num.replace(".", "")) > 6:
                    continue

                score = 0

                # Priority weighting
                if "grand total" in text:
                    score += 100
                elif "amount payable" in text:
                    score += 90
                elif "net total" in text:
                    score += 80
                elif "total" in text:
                    score += 50

                # Penalize line totals
                if "line total" in text:
                    score -= 40

                # Prefer decimals
                if "." in num:
                    score += 15

                # Bottom bias
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

    # ------------------------
    # Simple Merchant Heuristic
    # ------------------------

    def _extract_merchant(self, structure: ReceiptStructure):
        candidates = []

        lines = structure.header_lines or structure.all_lines[:6]

        for line in lines:
            text = line.normalized.strip()
            text_lower = text.lower()

            if len(text) < 4:
                continue

            # Reject noisy OCR fragments
            alpha_count = sum(c.isalpha() for c in text)
            if alpha_count < 3:
                continue

            if alpha_count / len(text) < 0.6:
                continue

            if len(set(text_lower)) <= 3:
                continue

            score = 0

            # Positive signals
            if text.isupper():
                score += 20

            if 4 <= len(text) <= 40:
                score += 15

            if not any(char.isdigit() for char in text):
                score += 10

            # Negative signals
            if any(k in text_lower for k in [
                "plot", "road", "street", "complex",
                "cross", "gst", "invoice", "bill",
                "mobile", "tel", "no.", "date",
                "near", "sector", "floor", "village",
                "district", "state"
            ]):
                score -= 40

            candidates.append((score, text))

        if not candidates:
            return None

        candidates.sort(key=lambda x: x[0], reverse=True)
        best_score, best_value = candidates[0]

        if best_score < 15:
            return None

        # ---------- CLEANUP LAYER ----------

        merchant = best_value

        # Remove leading/trailing non-letter garbage
        merchant = re.sub(r"^[^A-Za-z]+", "", merchant)
        merchant = re.sub(r"[^A-Za-z]+$", "", merchant)

        # Remove internal weird punctuation clusters
        merchant = re.sub(r"[^\w\s.&-]", "", merchant)

        # Collapse spaces
        merchant = re.sub(r"\s+", " ", merchant).strip()

        # If too short after cleaning → reject
        if len(merchant) < 3:
            return None

        return merchant.title()