from datetime import UTC, datetime, timedelta

from jose import jwt

from app.config import get_settings


def test_logout_without_authorization_header_returns_invalid_token(client) -> None:
    response = client.post("/api/v1/auth/logout")

    assert response.status_code == 401
    assert response.json() == {
        "detail": {
            "code": "INVALID_TOKEN",
            "message": "Invalid or missing access token.",
            "field": None,
        }
    }


def test_logout_with_malformed_authorization_header_returns_invalid_token(client) -> None:
    response = client.post(
        "/api/v1/auth/logout",
        headers={"Authorization": "Bearer not-a-valid-jwt"},
    )

    assert response.status_code == 401
    assert response.json() == {
        "detail": {
            "code": "INVALID_TOKEN",
            "message": "Invalid or missing access token.",
            "field": None,
        }
    }


def test_logout_with_expired_token_returns_token_expired(client) -> None:
    settings = get_settings()
    payload = {
        "sub": "7ecbcf7a-cf5f-4bd8-953a-6b1a22f9bcf6",
        "type": "access",
        "iat": int((datetime.now(UTC) - timedelta(hours=2)).timestamp()),
        "exp": datetime.now(UTC) - timedelta(minutes=1),
    }
    expired_token = jwt.encode(payload, settings.jwt_secret_key, algorithm="HS256")

    response = client.post(
        "/api/v1/auth/logout",
        headers={"Authorization": f"Bearer {expired_token}"},
    )

    assert response.status_code == 401
    assert response.json() == {
        "detail": {
            "code": "TOKEN_EXPIRED",
            "message": "Access token has expired.",
            "field": None,
        }
    }


def test_logout_with_valid_access_token_returns_success(client) -> None:
    payload = {"email": "logout-success@example.com", "password": "strongpass123"}
    signup_response = client.post("/api/v1/auth/signup", json=payload)
    assert signup_response.status_code == 201

    access_token = signup_response.json()["tokens"]["access_token"]
    response = client.post(
        "/api/v1/auth/logout",
        headers={"Authorization": f"Bearer {access_token}"},
    )

    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


def test_logout_invalidates_access_token_for_next_authenticated_request(client) -> None:
    payload = {"email": "logout-invalidate@example.com", "password": "strongpass123"}
    signup_response = client.post("/api/v1/auth/signup", json=payload)
    assert signup_response.status_code == 201

    access_token = signup_response.json()["tokens"]["access_token"]
    headers = {"Authorization": f"Bearer {access_token}"}

    logout_response = client.post("/api/v1/auth/logout", headers=headers)
    assert logout_response.status_code == 200

    second_logout_response = client.post("/api/v1/auth/logout", headers=headers)
    assert second_logout_response.status_code == 401
    assert second_logout_response.json() == {
        "detail": {
            "code": "INVALID_TOKEN",
            "message": "Invalid or missing access token.",
            "field": None,
        }
    }
