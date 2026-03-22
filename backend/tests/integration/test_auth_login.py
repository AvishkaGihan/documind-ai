def test_login_success_after_signup_returns_user_and_tokens(client) -> None:
    signup_payload = {"email": "loginuser@example.com", "password": "strongpass123"}
    signup_response = client.post("/api/v1/auth/signup", json=signup_payload)
    assert signup_response.status_code == 201

    login_response = client.post("/api/v1/auth/login", json=signup_payload)

    assert login_response.status_code == 200
    body = login_response.json()
    assert body["user"]["id"]
    assert body["user"]["email"] == signup_payload["email"]
    assert body["tokens"]["access_token"]
    assert body["tokens"]["refresh_token"]
    assert body["tokens"]["token_type"] == "bearer"


def test_login_wrong_password_returns_invalid_credentials_error(client) -> None:
    signup_payload = {"email": "wrongpass@example.com", "password": "strongpass123"}
    signup_response = client.post("/api/v1/auth/signup", json=signup_payload)
    assert signup_response.status_code == 201

    response = client.post(
        "/api/v1/auth/login",
        json={"email": signup_payload["email"], "password": "incorrectpass456"},
    )

    assert response.status_code == 401
    assert response.json() == {
        "detail": {
            "code": "INVALID_CREDENTIALS",
            "message": "Invalid email or password.",
            "field": None,
        }
    }


def test_login_unknown_email_returns_same_invalid_credentials_error(client) -> None:
    response = client.post(
        "/api/v1/auth/login",
        json={"email": "doesnotexist@example.com", "password": "strongpass123"},
    )

    assert response.status_code == 401
    assert response.json() == {
        "detail": {
            "code": "INVALID_CREDENTIALS",
            "message": "Invalid email or password.",
            "field": None,
        }
    }


def test_login_short_password_returns_standardized_validation_error(client) -> None:
    response = client.post(
        "/api/v1/auth/login",
        json={"email": "shortlogin@example.com", "password": "short"},
    )

    assert response.status_code == 422
    assert response.json() == {
        "detail": {
            "code": "VALIDATION_ERROR",
            "message": "Invalid request payload.",
            "field": "password",
        }
    }
