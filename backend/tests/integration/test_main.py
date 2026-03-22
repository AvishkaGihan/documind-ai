from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_docs_endpoint_available() -> None:
    response = client.get("/docs")
    assert response.status_code == 200


def test_cors_preflight_for_allowed_origin() -> None:
    response = client.options(
        "/docs",
        headers={
            "Origin": "http://localhost:3000",
            "Access-Control-Request-Method": "GET",
        },
    )
    assert response.status_code == 200
    assert response.headers["access-control-allow-origin"] == "http://localhost:3000"
