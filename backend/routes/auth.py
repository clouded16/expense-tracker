from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, EmailStr, Field
from sqlalchemy.orm import Session

from database import get_db
from models.auth import AuthResponse
from services.auth_service import (
    create_and_send_reset_otp,
    login_or_register_with_google,
    reset_password_with_verified_otp,
    verify_reset_otp,
)

from services.email_service import send_otp_email

router = APIRouter(prefix="/auth", tags=["auth"])
GOOGLE_CLIENT_ID = "528638374828-fl2nmo6lojh0fvvskb6ftb4eeej87dqu.apps.googleusercontent.com"

# ---------------- GOOGLE LOGIN ----------------

class GoogleLoginRequest(BaseModel):
    id_token: str


@router.post("/google-login", response_model=AuthResponse)
def google_login(payload: GoogleLoginRequest, db: Session = Depends(get_db)):
    try:
        return login_or_register_with_google(
            db=db,
            id_token_value=payload.id_token
        )
    except Exception as exc:
        raise HTTPException(status_code=401, detail=f"Google authentication failed: {exc}")


# ---------------- FORGOT PASSWORD ----------------

class SendResetOtpRequest(BaseModel):
    email: EmailStr


class VerifyResetOtpRequest(BaseModel):
    email: EmailStr
    otp: str = Field(min_length=6, max_length=6)


class ResetPasswordRequest(BaseModel):
    email: EmailStr
    new_password: str = Field(min_length=8, max_length=72)


@router.post("/send-reset-otp")
def send_reset_otp(payload: SendResetOtpRequest, db: Session = Depends(get_db)):
    try:
        create_and_send_reset_otp(db=db, email=payload.email)
    except Exception:
        pass

    return {"message": "If this email is registered, an OTP has been sent."}


@router.post("/verify-reset-otp")
def verify_otp(payload: VerifyResetOtpRequest, db: Session = Depends(get_db)):
    is_valid = verify_reset_otp(db=db, email=payload.email, otp=payload.otp)

    if not is_valid:
        raise HTTPException(status_code=400, detail="Invalid or expired OTP")

    return {"message": "OTP verified"}


@router.post("/reset-password")
def reset_password(payload: ResetPasswordRequest, db: Session = Depends(get_db)):
    ok = reset_password_with_verified_otp(
        db=db,
        email=payload.email,
        new_password=payload.new_password,
    )

    if not ok:
        raise HTTPException(status_code=400, detail="Password reset not allowed")

    return {"message": "Password updated successfully"}


# ---------------- TEST EMAIL (DEBUG ONLY) ----------------

@router.get("/test-email")
def test_email():
    send_otp_email("khushisheth1873@gmail.com", "123456")
    return {"message": "Email sent"}