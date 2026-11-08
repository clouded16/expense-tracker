import re
from datetime import datetime
from difflib import get_close_matches
from pathlib import Path
from typing import Optional

import cv2
import easyocr


class OCRProcessingError(Exception):
    pass


class OCRService:
    def __init__(self) -> None:
        self._reader = easyocr.Reader(["en"], gpu=False)

    def scan_receipt(self, image_path: str) -> dict:
        try:
            path = Path(image_path)
            if not path.exists():
                raise OCRProcessingError("Image file not found")

            processed_image = self._preprocess_image(str(path))
            results = self._reader.readtext(processed_image, detail=1, paragraph=False)

            sorted_results = sorted(results, key=lambda x: x[0][0][1])
            line_items = [
                (item[1].strip(), float(item[0][0][1]))
                for item in sorted_results
                if item[1].strip()
            ]

            lines = [text for text, _ in line_items]
            raw_text = "\n".join(lines)

            merchant = self._extract_merchant(lines)
            amount = self._extract_amount(line_items)
            extracted_date = self._extract_date(raw_text)
            category = self._detect_category(raw_text, merchant)

            return {
                "merchant": merchant,
                "amount": amount,
                "date": extracted_date,
                "category": category,
                "raw_text": raw_text,
            }

        except OCRProcessingError:
            raise
        except Exception as exc:
            raise OCRProcessingError(f"Failed to process receipt OCR: {exc}") from exc

    def _preprocess_image(self, image_path: str) -> str:
        image = cv2.imread(image_path)
        if image is None:
            raise OCRProcessingError("Unable to load receipt image")

        gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
        blur = cv2.GaussianBlur(gray, (5, 5), 0)
        thresh = cv2.adaptiveThreshold(
            blur,
            255,
            cv2.ADAPTIVE_THRESH_GAUSSIAN_C,
            cv2.THRESH_BINARY,
            11,
            2,
        )

        processed_path = image_path.replace(".jpg", "_processed.jpg")
        cv2.imwrite(processed_path, thresh)
        return processed_path

    def _extract_merchant(self, lines: list[str]) -> Optional[str]:
        blacklist = [
            "invoice",
            "bill",
            "gst",
            "date",
            "cash",
            "qty",
            "total",
            "amount",
            "tax",
            "sgst",
            "cgst",
            "customer",
            "phone",
            "address",
            "barcode",
            "pickup",
            "delivery",
            "order",
            "table",
            "token",
        ]

        scored_candidates = []
        for index, line in enumerate(lines[:10]):
            clean = re.sub(r"[^A-Za-z0-9&'.,\- ]", "", line).strip()
            if len(clean) < 3:
                continue

            lower = clean.lower()
            score = 0
            score += max(0, 25 - index * 3)
            score += 10 if re.search(r"[A-Za-z]", clean) else 0

            digit_count = len(re.findall(r"\d", clean))
            score += -15 if digit_count > 4 else 5

            if any(word in lower for word in blacklist):
                score -= 20

            word_count = len(clean.split())
            if 1 <= word_count <= 5:
                score += 15

            if clean.isupper():
                score += 5

            if any(x in lower for x in ["cafe", "restaurant", "pizza", "mart", "store", "hotel"]):
                score += 10

            scored_candidates.append((score, clean))

        if not scored_candidates:
            return None

        return max(scored_candidates, key=lambda x: x[0])[1].title()

    def _extract_amount(self, line_items: list[tuple[str, float]]) -> Optional[float]:
        if not line_items:
            return None

        include_keywords = ("grand total", "amount due", "payable", "total")
        ignore_keywords = ("qty", "item price", "sub total", "subtotal", "tax")

        candidates: list[tuple[float, float]] = []
        max_y = max(y for _, y in line_items)
        min_y = min(y for _, y in line_items)
        y_span = max(max_y - min_y, 1.0)

        for line, y in line_items:
            lower = line.lower()

            if any(keyword in lower for keyword in ignore_keywords):
                continue

            normalized = re.sub(r"(?<=\d)\s+(?=\d)", "", lower)
            numbers = re.findall(r"\d+\.\d{2}", normalized)
            if not numbers:
                continue

            bottom_weight = (y - min_y) / y_span
            keyword_weight = 1.0 if any(keyword in lower for keyword in include_keywords) else 0.0

            for raw in numbers:
                value = float(raw)
                if value <= 0:
                    continue

                score = 0.0
                score += 120.0 * keyword_weight
                score += 90.0 * bottom_weight
                score += min(value / 40.0, 60.0)
                candidates.append((score, value))

        if not candidates:
            return None

        candidates.sort(key=lambda item: (item[0], item[1]), reverse=True)
        return round(candidates[0][1], 2)

    def _extract_date(self, raw_text: str) -> Optional[str]:
        date_patterns = [
            r"\b(0?[1-9]|[12]\d|3[01])[/-](0?[1-9]|1[0-2])[/-](\d{2,4})\b",
            r"\b(\d{4})[/-](0?[1-9]|1[0-2])[/-](0?[1-9]|[12]\d|3[01])\b",
        ]

        for pattern in date_patterns:
            match = re.search(pattern, raw_text)
            if not match:
                continue

            value = match.group(0)
            for fmt in (
                "%d/%m/%Y",
                "%d-%m-%Y",
                "%d/%m/%y",
                "%d-%m-%y",
                "%Y/%m/%d",
                "%Y-%m-%d",
            ):
                try:
                    parsed = datetime.strptime(value, fmt).date()
                    return parsed.isoformat()
                except ValueError:
                    continue

        return datetime.today().date().isoformat()

    def _detect_category(self, raw_text: str, merchant: Optional[str]) -> str:
        text = raw_text.lower()
        merchant_name = (merchant or "").lower()

        merchant_category_map = {
            "pizza": "Food",
            "restaurant": "Food",
            "cafe": "Food",
            "burger": "Food",
            "zomato": "Food",
            "swiggy": "Food",
            "dmart": "Groceries",
            "supermarket": "Groceries",
            "mart": "Groceries",
            "uber": "Transport",
            "ola": "Transport",
            "rapido": "Transport",
            "apollo": "Medical",
            "pharmacy": "Medical",
            "hospital": "Medical",
            "amazon": "Shopping",
            "flipkart": "Shopping",
            "mall": "Shopping",
            "store": "Shopping",
        }

        for keyword, category in merchant_category_map.items():
            if keyword in merchant_name:
                return category

        category_keywords = {
            "Food": ["pizza", "restaurant", "cafe", "burger", "zomato", "swiggy", "food"],
            "Groceries": ["dmart", "supermarket", "mart", "grocery", "vegetable"],
            "Transport": ["uber", "ola", "rapido", "taxi", "bus", "train"],
            "Medical": ["apollo", "pharmacy", "hospital", "medical", "chemist"],
            "Shopping": ["amazon", "flipkart", "mall", "store", "fashion", "electronics"],
        }

        words = text.split()
        for category, keywords in category_keywords.items():
            for keyword in keywords:
                if keyword in text:
                    return category

                if get_close_matches(keyword, words, cutoff=0.8):
                    return category

        return "Other"

    def _to_float(self, value: str) -> Optional[float]:
        try:
            return float(value.replace(",", "."))
        except (TypeError, ValueError):
            return None
