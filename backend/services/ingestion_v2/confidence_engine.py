# services/ingestion_v2/confidence_engine.py

from .receipt_model import ReceiptStructure, ExtractedFields


class ConfidenceEngine:
    """
    Computes structured confidence score based on:
    - Field presence
    - Structural alignment
    - Logical consistency
    """

    def compute(self, structure: ReceiptStructure, fields: ExtractedFields) -> float:
        score = 0.0

        # -----------------------
        # Field Presence Weights
        # -----------------------
        if fields.amount:
            score += 0.4

        if fields.merchant_name:
            score += 0.25

        if fields.transaction_date:
            score += 0.15

        # -----------------------
        # Structural Consistency
        # -----------------------

        # Amount found in totals region → strong boost
        if fields.amount:
            for line in structure.total_lines:
                if str(int(fields.amount)) in line.normalized:
                    score += 0.1
                    break

        # Merchant found in header → boost
        if fields.merchant_name:
            for line in structure.header_lines:
                if fields.merchant_name.lower() in line.normalized.lower():
                    score += 0.05
                    break

        # -----------------------
        # Logical Validation
        # -----------------------

        # If amount seems too small or too large, penalize
        if fields.amount:
            if fields.amount < 1:
                score -= 0.2
            if fields.amount > 1000000:
                score -= 0.2

        # Clamp score
        score = max(0.0, min(1.0, score))

        return round(score, 2)