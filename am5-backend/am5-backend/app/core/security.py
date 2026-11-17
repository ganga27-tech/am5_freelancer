import bcrypt
from datetime import datetime, timedelta, timezone
from typing import Any, Mapping, Union
from jose import jwt
from app.core.config import settings

def require_jwt_secret() -> str:
    secret = settings.SECRET_KEY.strip()
    if len(secret) < 32:
        raise RuntimeError("JWT signing key is not configured")
    return secret


def create_access_token(
    subject: Union[str, Any],
    expires_delta: timedelta = None,
    additional_claims: Mapping[str, Any] | None = None,
) -> str:
    lifetime = expires_delta or timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    now = datetime.now(timezone.utc)
    to_encode = {
        "exp": now + lifetime,
        "iat": now,
        "sub": str(subject),
    }
    if additional_claims:
        to_encode.update(additional_claims)
    encoded_jwt = jwt.encode(
        to_encode,
        require_jwt_secret(),
        algorithm=settings.ALGORITHM,
    )
    return encoded_jwt

def verify_password(plain_password: str, hashed_password: str) -> bool:
    try:
        return bcrypt.checkpw(plain_password.encode('utf-8'), hashed_password.encode('utf-8'))
    except Exception:
        return False

def get_password_hash(password: str) -> str:
    return bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')
