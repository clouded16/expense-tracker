from passlib.context import CryptContext
from jose import JWTError, jwt
from datetime import datetime, timedelta, timezone
import os
import uuid
from dotenv import load_dotenv
from fastapi.security import OAuth2PasswordBearer
from fastapi import Depends, HTTPException, status
from sqlalchemy.orm import Session
from database import get_db
from models.user_orm import User
from config import (
    SECRET_KEY,
    ALGORITHM,
    ACCESS_TOKEN_EXPIRE_MINUTES,
    REFRESH_TOKEN_EXPIRE_DAYS
)


##oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/login")
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials

security = HTTPBearer()

##def get_current_user(token: str = Depends(oauth2_scheme),
                     ##db: Session = Depends(get_db)):
def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: Session = Depends(get_db),
):
    token = credentials.credentials
    print("DECODE SECRET_KEY:", SECRET_KEY)
    print("DECODE ALGORITHM:", ALGORITHM)
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])

        if payload.get("type") != "access":
            raise HTTPException(status_code=401, detail="Invalid token type")

        user_id = int(payload.get("sub"))
        token_version = payload.get("token_version")

    except JWTError:
        raise HTTPException(status_code=401, detail="Invalid token")

    user = db.query(User).filter(User.id == user_id).first()

    if not user:
        raise HTTPException(status_code=401, detail="User not found")
    
    if user.token_version != token_version:
        raise HTTPException(status_code=401, detail="Token invalidated")

    if not user.is_active:
        raise HTTPException(status_code=403, detail="Account disabled")

    if not user.is_verified:
        raise HTTPException(status_code=403, detail="Email not verified")

    return user



pwd_context = CryptContext(schemes=["bcrypt_sha256"], deprecated="auto")



def hash_password(password: str) -> str:
    return pwd_context.hash(password)


def verify_password(plain_password: str, hashed_password: str) -> bool:
    return pwd_context.verify(plain_password, hashed_password)


def create_access_token(user: User):
    print("ENCODE SECRET_KEY:", SECRET_KEY)
    print("ENCODE ALGORITHM:", ALGORITHM)
    expire = datetime.now(timezone.utc) + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    payload = {
        "sub": str(user.id),
        "type": "access",
        "token_version": user.token_version,
        "exp": expire
    }
    return jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)


def create_refresh_token(user_id: int):
    expire = datetime.now(timezone.utc) + timedelta(days=REFRESH_TOKEN_EXPIRE_DAYS)
    jti = str(uuid.uuid4())

    payload = {
        "sub": str(user_id),
        "jti": jti,
        "type": "refresh",
        "exp": expire
    }

    token = jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)
    return token, expire, jti 


def decode_token(token: str):
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        return payload
    except JWTError:
        return None
