from datetime import UTC, datetime, timedelta
from uuid import uuid4

import pytest
from jose import jwt

from app.config import get_settings
from app.services.auth.jwt_service import (
    ALGORITHM,
    create_password_reset_token,
    decode_password_reset_token,
)


def test_create_and_decode_password_reset_token_round_trip(monkeypatch) -> None:
    monkeypatch.setenv("JWT_SECRET_KEY", "unit-test-secret")
    monkeypatch.setenv("PASSWORD_RESET_TOKEN_EXPIRES_MINUTES", "30")
    get_settings.cache_clear()

    user_id = uuid4()
    token = create_password_reset_token(subject=str(user_id), email="user@example.com")

    decoded_user_id = decode_password_reset_token(token)

    assert decoded_user_id == user_id


def test_decode_password_reset_token_rejects_non_reset_token(monkeypatch) -> None:
    monkeypatch.setenv("JWT_SECRET_KEY", "unit-test-secret")
    get_settings.cache_clear()

    settings = get_settings()
    payload = {
        "sub": str(uuid4()),
        "type": "access",
        "iat": int(datetime.now(UTC).timestamp()),
        "exp": datetime.now(UTC) + timedelta(minutes=30),
    }
    token = jwt.encode(payload, settings.jwt_secret_key, algorithm=ALGORITHM)

    with pytest.raises(ValueError):
        decode_password_reset_token(token)


def test_decode_password_reset_token_rejects_expired_token(monkeypatch) -> None:
    monkeypatch.setenv("JWT_SECRET_KEY", "unit-test-secret")
    get_settings.cache_clear()

    settings = get_settings()
    payload = {
        "sub": str(uuid4()),
        "type": "reset",
        "iat": int((datetime.now(UTC) - timedelta(hours=1)).timestamp()),
        "exp": datetime.now(UTC) - timedelta(minutes=1),
    }
    token = jwt.encode(payload, settings.jwt_secret_key, algorithm=ALGORITHM)

    with pytest.raises(ValueError):
        decode_password_reset_token(token)
