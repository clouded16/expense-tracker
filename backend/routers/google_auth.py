from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel
from sqlalchemy.orm import Session
from google.oauth2 import id_token
from google.auth.transport import requests as google_requests
import os

from database import get_db
from models.user_orm import User
from models.refresh_token_orm import RefreshToken
from services.auth import (
    create_access_token,
    create_refresh_token,
    hash_password,
)

router = APIRouter()

GOOGLE_WEB_CLIENT_ID = os.getenv("GOOGLE_WEB_CLIENT_ID")

if not GOOGLE_WEB_CLIENT_ID:
    raise RuntimeError("GOOGLE_WEB_CLIENT_ID not set ")


class GoogleAuthRequest(BaseModel):
    id_token: str


@router.post("/auth/google")
def google_login(payload: GoogleAuthRequest, db: Session = Depends(get_db)):
    try:
        idinfo = id_token.verify_oauth2_token(
            payload.id_token,
            google_requests.Request(),
            GOOGLE_WEB_CLIENT_ID
        )

        email = idinfo["email"]
        google_id = idinfo["sub"]
        full_name = idinfo.get("name")

    except Exception:
        raise HTTPException(status_code=401, detail="Invalid Google token")

    user = db.query(User).filter(User.email == email).first()

    if not user:
        user = User(
            email=email,
            full_name=full_name,
            google_id=google_id,
            oauth_provider="google",
            is_verified=True,
            is_active=True,
            token_version=0
        )
        db.add(user)
        db.commit()
        db.refresh(user)
    else:
        if not user.google_id:
            user.google_id = google_id
            user.oauth_provider = "google"
            db.commit()

    # ✅ CREATE ACCESS TOKEN
    access_token = create_access_token(user)

    # ✅ CREATE REFRESH TOKEN (IDENTICAL TO NORMAL LOGIN FLOW)
    refresh_token, expires_at, jti = create_refresh_token(user.id)

    hashed_refresh = hash_password(refresh_token)

    db_refresh = RefreshToken(
        user_id=user.id,
        jti=jti,
        token_hash=hashed_refresh,
        expires_at=expires_at,
        revoked=False
    )

    db.add(db_refresh)
    db.commit()

    return {
        "access_token": access_token,
        "refresh_token": refresh_token,
        "token_type": "bearer",
        "user_id": user.id
    }