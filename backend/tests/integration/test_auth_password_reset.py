from datetime import UTC, datetime, timedelta

from jose import jwt

from app.config import get_settings


def test_reset_password_request_returns_ok_for_existing_email(client) -> None:
    signup_payload = {"email": "reset-existing@example.com", "password": "strongpass123"}
    signup_response = client.post("/api/v1/auth/signup", json=signup_payload)
    assert signup_response.status_code == 201

    response = client.post(
        "/api/v1/auth/reset-password",
        json={"email": signup_payload["email"]},
    )

    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


def test_reset_password_request_returns_ok_for_unknown_email(client) -> None:
    response = client.post(
        "/api/v1/auth/reset-password",
        json={"email": "does-not-exist@example.com"},
    )

    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


def test_reset_password_confirm_with_malformed_token_returns_invalid_reset_token(client) -> None:
    response = client.post(
        "/api/v1/auth/reset-password/confirm",
        json={"token": "not-a-jwt", "new_password": "newstrongpass123"},
    )

    assert response.status_code == 400
    assert response.json() == {
        "detail": {
            "code": "INVALID_RESET_TOKEN",
            "message": "Invalid or expired reset token.",
            "field": None,
        }
    }


def test_reset_password_confirm_with_expired_token_returns_invalid_reset_token(client) -> None:
    signup_payload = {"email": "reset-expired@example.com", "password": "strongpass123"}
    signup_response = client.post("/api/v1/auth/signup", json=signup_payload)
    assert signup_response.status_code == 201

    user_id = signup_response.json()["user"]["id"]
    settings = get_settings()
    expired_payload = {
        "sub": user_id,
        "type": "reset",
        "iat": int((datetime.now(UTC) - timedelta(hours=1)).timestamp()),
        "exp": datetime.now(UTC) - timedelta(minutes=1),
    }
    expired_token = jwt.encode(expired_payload, settings.jwt_secret_key, algorithm="HS256")

    response = client.post(
        "/api/v1/auth/reset-password/confirm",
        json={"token": expired_token, "new_password": "newstrongpass123"},
    )

    assert response.status_code == 400
    assert response.json() == {
        "detail": {
            "code": "INVALID_RESET_TOKEN",
            "message": "Invalid or expired reset token.",
            "field": None,
        }
    }


def test_reset_password_confirm_with_valid_token_updates_password(client) -> None:
    signup_payload = {"email": "reset-valid@example.com", "password": "strongpass123"}
    signup_response = client.post("/api/v1/auth/signup", json=signup_payload)
    assert signup_response.status_code == 201

    user_id = signup_response.json()["user"]["id"]
    settings = get_settings()
    valid_payload = {
        "sub": user_id,
        "type": "reset",
        "iat": int(datetime.now(UTC).timestamp()),
        "exp": datetime.now(UTC) + timedelta(minutes=30),
    }
    reset_token = jwt.encode(valid_payload, settings.jwt_secret_key, algorithm="HS256")

    confirm_response = client.post(
        "/api/v1/auth/reset-password/confirm",
        json={"token": reset_token, "new_password": "newstrongpass123"},
    )
    assert confirm_response.status_code == 200
    assert confirm_response.json() == {"status": "ok"}

    old_login_response = client.post("/api/v1/auth/login", json=signup_payload)
    assert old_login_response.status_code == 401
    assert old_login_response.json() == {
        "detail": {
            "code": "INVALID_CREDENTIALS",
            "message": "Invalid email or password.",
            "field": None,
        }
    }

    new_login_response = client.post(
        "/api/v1/auth/login",
        json={"email": signup_payload["email"], "password": "newstrongpass123"},
    )
    assert new_login_response.status_code == 200


def test_reset_password_confirm_invalidates_existing_sessions(client) -> None:
    signup_payload = {"email": "reset-sessions@example.com", "password": "strongpass123"}
    signup_response = client.post("/api/v1/auth/signup", json=signup_payload)
    assert signup_response.status_code == 201

    access_token = signup_response.json()["tokens"]["access_token"]
    user_id = signup_response.json()["user"]["id"]

    settings = get_settings()
    valid_payload = {
        "sub": user_id,
        "type": "reset",
        "iat": int(datetime.now(UTC).timestamp()),
        "exp": datetime.now(UTC) + timedelta(minutes=30),
    }
    reset_token = jwt.encode(valid_payload, settings.jwt_secret_key, algorithm="HS256")

    confirm_response = client.post(
        "/api/v1/auth/reset-password/confirm",
        json={"token": reset_token, "new_password": "newstrongpass123"},
    )
    assert confirm_response.status_code == 200

    logout_response = client.post(
        "/api/v1/auth/logout",
        headers={"Authorization": f"Bearer {access_token}"},
    )
    assert logout_response.status_code == 401
    assert logout_response.json() == {
        "detail": {
            "code": "INVALID_TOKEN",
            "message": "Invalid or missing access token.",
            "field": None,
        }
    }
