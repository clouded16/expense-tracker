# services/ingestion_v2/structure_builder.py

import re
from typing import List
from .receipt_model import ReceiptLine, ReceiptStructure


class ReceiptStructureBuilder:
    """
    Converts raw OCR text into structured receipt sections:
    - header
    - body
    - totals
    - footer
    """

    TOTAL_KEYWORDS = (
        "total",
        "grand total",
        "net amount",
        "amount payable",
        "balance",
        "sale",
    )

    FOOTER_KEYWORDS = (
        "thank",
        "visit again",
        "gst",
        "tax invoice",
        "invoice no",
        "receipt no",
    )

    def build(self, raw_text: str) -> ReceiptStructure:
        lines = self._prepare_lines(raw_text)

        structure = ReceiptStructure(
            all_lines=lines
        )

        total_zone_started = False

        for line in lines:
            lower = line.normalized.lower()

            # Detect total section
            if any(k in lower for k in self.TOTAL_KEYWORDS):
                total_zone_started = True
                structure.total_lines.append(line)
                continue

            # Detect footer
            if total_zone_started and any(k in lower for k in self.FOOTER_KEYWORDS):
                structure.footer_lines.append(line)
                continue

            # Header detection: until first numeric-heavy line
            if not total_zone_started:
                digit_ratio = sum(c.isdigit() for c in line.normalized) / max(1, len(line.normalized))

                if digit_ratio < 0.3:
                    structure.header_lines.append(line)
                    continue

            # After total zone but not footer → still total region
            if total_zone_started:
                structure.total_lines.append(line)
                continue

            # Everything else → body
            structure.body_lines.append(line)

        return structure

    def _prepare_lines(self, raw_text: str) -> List[ReceiptLine]:
        cleaned = raw_text.replace("\r\n", "\n").replace("\r", "\n")
        split_lines = [ln.strip() for ln in cleaned.split("\n") if ln.strip()]

        prepared = []
        for idx, ln in enumerate(split_lines):
            normalized = re.sub(r"\s+", " ", ln)
            prepared.append(
                ReceiptLine(
                    index=idx,
                    raw=ln,
                    normalized=normalized,
                )
            )

        return prepared