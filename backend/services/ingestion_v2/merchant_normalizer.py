import re
from difflib import SequenceMatcher


class MerchantNormalizer:

    SIMILARITY_THRESHOLD = 0.85
    RELAXED_THRESHOLD = 0.80

    def normalize_basic(self, text: str) -> str:
        text = text.upper()
        text = re.sub(r"[^A-Z\s]", " ", text)
        text = re.sub(r"\s+", " ", text).strip()
        return text

    def collapse_repeated_chars(self, text: str) -> str:
        return re.sub(r"(.)\1{1,}", r"\1", text)

    def remove_vowels(self, text: str) -> str:
        return re.sub(r"[AEIOU]", "", text)

    def similarity(self, a: str, b: str) -> float:
        return SequenceMatcher(None, a, b).ratio()

    def best_similarity(self, a: str, b: str) -> float:
        scores = [
            self.similarity(a, b),
            self.similarity(self.remove_vowels(a), self.remove_vowels(b)),
            self.similarity(self.collapse_repeated_chars(a),
                            self.collapse_repeated_chars(b)),
        ]
        return max(scores)

    def canonicalize(self, merchant: str | None, known_merchants: list[str]) -> str | None:
        if not merchant:
            return None

        merchant_norm = self.normalize_basic(merchant)

        best_match = None
        best_score = 0.0

        for known in known_merchants:
            known_norm = self.normalize_basic(known)

            score = self.best_similarity(merchant_norm, known_norm)

            if score > best_score:
                best_score = score
                best_match = known

        if best_score >= self.SIMILARITY_THRESHOLD:
            return best_match

        return merchant_norm.title()