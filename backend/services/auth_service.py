import hashlib
import logging
import secrets
import smtplib
import random
from datetime import datetime, timedelta, timezone
from email.mime.text import MIMEText
from typing import Optional

from google.auth.transport import requests as google_requests
from google.oauth2 import id_token
from sqlalchemy.orm import Session

from config import (
    GOOGLE_CLIENT_ID,
    OTP_EXPIRY_MINUTES,
    OTP_MAX_ATTEMPTS,
    SMTP_FROM_EMAIL,
    SMTP_HOST,
    SMTP_PASSWORD,
    SMTP_PORT,
    SMTP_USE_TLS,
    SMTP_USERNAME,
)
from models.auth import AuthResponse
from models.password_reset_otp_orm import PasswordResetOTP
from models.refresh_token_orm import RefreshToken
from models.user_orm import User
from services.auth import create_access_token, create_refresh_token, hash_password

logger = logging.getLogger("expense-tracker.auth")

GOOGLE_CLIENT_ID = "528638374828-fl2nmo6lojh0fvvskb6ftb4eeej87dqu.apps.googleusercontent.com"


def verify_google_token(token: str):
    try:
        idinfo = id_token.verify_oauth2_token(
            token,
            requests.Request(),
            GOOGLE_CLIENT_ID
        )

        email = idinfo["email"]
        name = idinfo.get("name")

        return {
            "email": email,
            "name": name
        }

    except Exception as e:
        raise Exception("Invalid Google token")

def _hash_otp(raw_otp: str) -> str:
    return hashlib.sha256(raw_otp.encode("utf-8")).hexdigest()


def generate_otp_code() -> str:
    return f"{secrets.randbelow(1000000):06d}"


def send_email(to_email: str, subject: str, body: str) -> None:
    if not SMTP_HOST or not SMTP_FROM_EMAIL:
        raise ValueError("SMTP configuration missing")

    msg = MIMEText(body)
    msg["Subject"] = subject
    msg["From"] = SMTP_FROM_EMAIL
    msg["To"] = to_email

    with smtplib.SMTP(SMTP_HOST, SMTP_PORT) as smtp:
        if SMTP_USE_TLS:
            smtp.starttls()
        if SMTP_USERNAME and SMTP_PASSWORD:
            smtp.login(SMTP_USERNAME, SMTP_PASSWORD)
        smtp.sendmail(SMTP_FROM_EMAIL, [to_email], msg.as_string())


def issue_auth_tokens(db: Session, user: User) -> AuthResponse:
    access_token = create_access_token(user)
    refresh_token, expires_at, jti = create_refresh_token(user.id)

    db_refresh = RefreshToken(
        user_id=user.id,
        jti=jti,
        token_hash=hash_password(refresh_token),
        expires_at=expires_at,
        revoked=False,
    )
    db.add(db_refresh)
    db.commit()

    return AuthResponse(access_token=access_token, refresh_token=refresh_token)


def login_or_register_with_google(db: Session, id_token_value: str) -> AuthResponse:
    if not GOOGLE_CLIENT_ID:
        raise ValueError("Google client ID is not configured")

    request = google_requests.Request()
    token_info = id_token.verify_oauth2_token(
        id_token_value,
        request,
        GOOGLE_CLIENT_ID,
    )

    email = token_info.get("email")
    if not email:
        raise ValueError("Google token does not include an email")

    full_name = token_info.get("name") or email.split("@")[0]

    user = db.query(User).filter(User.email == email).first()
    if not user:
        random_password = secrets.token_urlsafe(32)
        user = User(
            email=email,
            hashed_password=hash_password(random_password),
            full_name=full_name,
            is_verified=True,
            is_active=True,
        )
        db.add(user)
        db.commit()
        db.refresh(user)

    return issue_auth_tokens(db, user)


def create_and_send_reset_otp(db: Session, email: str) -> None:
    user = db.query(User).filter(User.email == email).first()
    if not user:
        return
    print("Sending OTP to:", email)
    db.query(PasswordResetOTP).filter(
        PasswordResetOTP.email == email,
        PasswordResetOTP.consumed.is_(False),
    ).update({"consumed": True})

    otp = generate_otp_code()
    expires_at = datetime.now(timezone.utc) + timedelta(minutes=OTP_EXPIRY_MINUTES)
    print("OTP sent successfully")
    entry = PasswordResetOTP(
        email=email,
        otp_code=_hash_otp(otp),
        expires_at=expires_at,
        attempts=0,
        verified=False,
        consumed=False,
    )
    db.add(entry)
    db.commit()
    send_otp_email(email, otp)

    print("OTP email sent successfully")
    subject = "Password Reset OTP"
    body = (
        "Your verification code is:\n\n"
        f"{otp}\n\n"
        f"This code expires in {OTP_EXPIRY_MINUTES} minutes."
    )

    send_email(email, subject, body)


def _latest_active_otp(db: Session, email: str) -> Optional[PasswordResetOTP]:
    return (
        db.query(PasswordResetOTP)
        .filter(
            PasswordResetOTP.email == email,
            PasswordResetOTP.consumed.is_(False),
        )
        .order_by(PasswordResetOTP.created_at.desc())
        .first()
    )


def verify_reset_otp(db: Session, email: str, otp: str) -> bool:
    entry = _latest_active_otp(db, email)

    if not entry:
        return False

    now = datetime.now(timezone.utc)
    expires_at = entry.expires_at

    if expires_at.tzinfo is None:
        expires_at = expires_at.replace(tzinfo=timezone.utc)

    # check expiry
    if expires_at < now:
        entry.consumed = True
        db.commit()
        return False

    # check attempts
    if entry.attempts >= OTP_MAX_ATTEMPTS:
        entry.consumed = True
        db.commit()
        return False

    print("EMAIL RECEIVED:", email)
    print("OTP RECEIVED:", otp)

    entry.attempts += 1

    # compare hashed OTP
    if entry.otp_code != _hash_otp(otp):
        print("HASHED OTP FROM USER:", _hash_otp(otp))
        print("HASHED OTP IN DB:", entry.otp_code)

        if entry.attempts >= OTP_MAX_ATTEMPTS:
            entry.consumed = True

        db.commit()
        return False

    # OTP correct
    entry.verified = True
    db.commit()

    print("OTP VERIFIED SUCCESSFULLY")

    return True


def reset_password_with_verified_otp(db: Session, email: str, new_password: str) -> bool:
    entry = _latest_active_otp(db, email)
    if not entry or not entry.verified:
        return False

    now = datetime.now(timezone.utc)
    expires_at = entry.expires_at
    if expires_at.tzinfo is None:
        expires_at = expires_at.replace(tzinfo=timezone.utc)

    if expires_at < now:
        entry.consumed = True
        db.commit()
        return False

    user = db.query(User).filter(User.email == email).first()
    if not user:
        return False

    user.hashed_password = hash_password(new_password)
    entry.consumed = True
    db.commit()
    return True
