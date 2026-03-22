import asyncio

from sqlalchemy import select

from app.models.user import User


def test_signup_success_creates_user_and_returns_tokens(client, test_session_factory) -> None:
    payload = {"email": "newuser@example.com", "password": "strongpass123"}

    response = client.post("/api/v1/auth/signup", json=payload)

    assert response.status_code == 201
    body = response.json()
    assert body["user"]["id"]
    assert body["user"]["email"] == payload["email"]
    assert body["tokens"]["access_token"]
    assert body["tokens"]["refresh_token"]
    assert body["tokens"]["token_type"] == "bearer"

    async def _assert_user_stored_with_hashed_password() -> None:
        async with test_session_factory() as session:
            statement = select(User).where(User.email == payload["email"])
            user = (await session.execute(statement)).scalar_one()
            assert user.hashed_password != payload["password"]

    asyncio.run(_assert_user_stored_with_hashed_password())


def test_signup_duplicate_email_returns_conflict(client) -> None:
    payload = {"email": "duplicate@example.com", "password": "strongpass123"}

    first_response = client.post("/api/v1/auth/signup", json=payload)
    assert first_response.status_code == 201

    second_response = client.post("/api/v1/auth/signup", json=payload)

    assert second_response.status_code == 409
    assert second_response.json() == {
        "detail": {
            "code": "EMAIL_ALREADY_EXISTS",
            "message": "An account with this email already exists.",
            "field": None,
        }
    }


def test_signup_short_password_returns_standardized_validation_error(client) -> None:
    response = client.post(
        "/api/v1/auth/signup",
        json={"email": "short@example.com", "password": "short"},
    )

    assert response.status_code == 422
    assert response.json() == {
        "detail": {
            "code": "VALIDATION_ERROR",
            "message": "Invalid request payload.",
            "field": "password",
        }
    }
