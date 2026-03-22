from datetime import UTC, datetime, timedelta
from uuid import UUID

from jose import ExpiredSignatureError, JWTError, jwt

from app.config import get_settings

ALGORITHM = "HS256"


def _create_token(
    subject: str,
    token_type: str,
    expires_delta: timedelta,
    email: str | None = None,
) -> str:
    settings = get_settings()
    issued_at = datetime.now(UTC)
    expires_at = datetime.now(UTC) + expires_delta
    payload: dict[str, str | datetime | int] = {
        "sub": subject,
        "type": token_type,
        "iat": int(issued_at.timestamp()),
        "exp": expires_at,
    }
    if email is not None:
        payload["email"] = email
    return jwt.encode(payload, settings.jwt_secret_key, algorithm=ALGORITHM)


def create_access_token(subject: str, email: str | None = None) -> str:
    settings = get_settings()
    expiry = timedelta(hours=settings.jwt_access_token_expires_hours)
    return _create_token(subject=subject, token_type="access", expires_delta=expiry, email=email)


def create_refresh_token(subject: str, email: str | None = None) -> str:
    settings = get_settings()
    expiry = timedelta(days=settings.jwt_refresh_token_expires_days)
    return _create_token(subject=subject, token_type="refresh", expires_delta=expiry, email=email)


def create_password_reset_token(subject: str, email: str | None = None) -> str:
    settings = get_settings()
    expiry = timedelta(minutes=settings.password_reset_token_expires_minutes)
    return _create_token(subject=subject, token_type="reset", expires_delta=expiry, email=email)


def decode_password_reset_token(token: str) -> UUID:
    settings = get_settings()
    try:
        payload = jwt.decode(token, settings.jwt_secret_key, algorithms=[ALGORITHM])
    except (ExpiredSignatureError, JWTError) as exc:
        raise ValueError("Invalid or expired reset token") from exc

    if payload.get("type") != "reset":
        raise ValueError("Invalid or expired reset token")

    subject = payload.get("sub")
    try:
        return UUID(str(subject))
    except (TypeError, ValueError) as exc:
        raise ValueError("Invalid or expired reset token") from exc
