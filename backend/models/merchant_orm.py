from sqlalchemy import Column, Integer, Text, TIMESTAMP, Index
from sqlalchemy.sql import func

from models.base import Base


class Merchant(Base):
    __tablename__ = "merchant"

    id = Column(Integer, primary_key=True)

    # Canonical display name
    name = Column(Text, nullable=False)

    # Deterministic normalized key (uppercase, stripped, no symbols)
    normalized_key = Column(Text, nullable=False, unique=True, index=True)

    created_at = Column(TIMESTAMP, server_default=func.now())


# Optional explicit index (extra safety)
Index("ix_merchant_normalized_key", Merchant.normalized_key)