# services/ingestion_v2/engine.py

from .structure_builder import ReceiptStructureBuilder
from .field_classifier import FieldClassifier
from .confidence_engine import ConfidenceEngine
from .receipt_model import ExtractedFields


class IngestionEngineV2:
    """
    Orchestrates structured receipt ingestion pipeline.
    """

    def __init__(self):
        self.structure_builder = ReceiptStructureBuilder()
        self.field_classifier = FieldClassifier()
        self.confidence_engine = ConfidenceEngine()

    def process(self, raw_text: str) -> ExtractedFields:
        # 1️⃣ Build structure
        structure = self.structure_builder.build(raw_text)

        # 2️⃣ Extract fields
        fields = self.field_classifier.classify(structure)

        # 3️⃣ Compute confidence
        confidence = self.confidence_engine.compute(structure, fields)

        fields.confidence = confidence

        return fields