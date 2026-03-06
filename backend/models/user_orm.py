from sqlalchemy import Column, Integer, String, Boolean, TIMESTAMP
from sqlalchemy.sql import func
from models.base import Base


class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)

    email = Column(String(255), unique=True, nullable=False, index=True)

    # Nullable because OAuth users won’t have password
    hashed_password = Column(String(255), nullable=True)

    full_name = Column(String(255), nullable=True)

    is_active = Column(Boolean, default=True)
    is_verified = Column(Boolean, default=False)

    token_version = Column(Integer, default=0)

    # 🔥 NEW FIELDS
    google_id = Column(String(255), unique=True, nullable=True, index=True)
    oauth_provider = Column(String(50), nullable=True)

    created_at = Column(TIMESTAMP, server_default=func.now())