import asyncio
from datetime import UTC, datetime
from uuid import UUID, uuid4

from app.models.document import Document, DocumentStatus


def _auth_headers(client, email: str) -> tuple[dict[str, str], str]:
    signup_payload = {"email": email, "password": "strongpass123"}
    signup_response = client.post("/api/v1/auth/signup", json=signup_payload)
    assert signup_response.status_code == 201

    access_token = signup_response.json()["tokens"]["access_token"]
    user_id = signup_response.json()["user"]["id"]
    return {"Authorization": f"Bearer {access_token}"}, user_id


def _create_document_for_user(
    *,
    test_session_factory,
    user_id: UUID,
    status: DocumentStatus,
    error_message: str | None,
) -> UUID:
    document_id = uuid4()

    async def _create() -> None:
        async with test_session_factory() as session:
            session.add(
                Document(
                    id=document_id,
                    user_id=user_id,
                    title="status-spec",
                    file_path=f"users/{user_id}/documents/{document_id}.pdf",
                    file_size=1024,
                    page_count=8,
                    status=status,
                    error_message=error_message,
                    created_at=datetime.now(UTC),
                    updated_at=datetime.now(UTC),
                )
            )
            await session.commit()

    asyncio.run(_create())
    return document_id


def test_get_document_by_id_returns_owner_document_with_status(
    client,
    test_session_factory,
) -> None:
    headers, user_id_value = _auth_headers(client, "doc-owner@example.com")
    user_id = UUID(user_id_value)

    document_id = _create_document_for_user(
        test_session_factory=test_session_factory,
        user_id=user_id,
        status=DocumentStatus.EMBEDDING,
        error_message=None,
    )

    response = client.get(f"/api/v1/documents/{document_id}", headers=headers)

    assert response.status_code == 200
    body = response.json()
    assert body["id"] == str(document_id)
    assert body["title"] == "status-spec"
    assert body["file_size"] == 1024
    assert body["page_count"] == 8
    assert body["status"] == "embedding"
    assert body["error_message"] is None
    assert body["created_at"]


def test_get_document_by_id_returns_404_for_non_owner(client, test_session_factory) -> None:
    owner_headers, owner_user_id_value = _auth_headers(client, "doc-owner2@example.com")
    requester_headers, _ = _auth_headers(client, "doc-requester@example.com")

    owner_user_id = UUID(owner_user_id_value)
    document_id = _create_document_for_user(
        test_session_factory=test_session_factory,
        user_id=owner_user_id,
        status=DocumentStatus.ERROR,
        error_message="Parsing failed",
    )

    response = client.get(f"/api/v1/documents/{document_id}", headers=requester_headers)

    assert response.status_code == 404
    assert response.json() == {
        "detail": {
            "code": "DOCUMENT_NOT_FOUND",
            "message": "Document not found.",
            "field": None,
        }
    }

    # Ensure the owner can still fetch it to prove ownership-based filtering.
    owner_response = client.get(f"/api/v1/documents/{document_id}", headers=owner_headers)
    assert owner_response.status_code == 200
