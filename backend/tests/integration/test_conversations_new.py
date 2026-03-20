import asyncio
from datetime import UTC, datetime
from uuid import UUID, uuid4

from app.models.conversation import Conversation
from app.models.document import Document, DocumentStatus


def _auth_headers(client, email: str) -> tuple[dict[str, str], UUID]:
    payload = {"email": email, "password": "strongpass123"}
    response = client.post("/api/v1/auth/signup", json=payload)
    assert response.status_code == 201

    return {"Authorization": f"Bearer {response.json()['tokens']['access_token']}"}, UUID(
        response.json()["user"]["id"]
    )


def _create_document_for_user(*, test_session_factory, user_id: UUID) -> UUID:
    document_id = uuid4()

    async def _create() -> None:
        async with test_session_factory() as session:
            session.add(
                Document(
                    id=document_id,
                    user_id=user_id,
                    title="doc",
                    file_path=f"users/{user_id}/documents/{document_id}.pdf",
                    file_size=100,
                    page_count=1,
                    status=DocumentStatus.READY,
                    error_message=None,
                    created_at=datetime.now(UTC),
                    updated_at=datetime.now(UTC),
                )
            )
            await session.commit()

    asyncio.run(_create())
    return document_id


def test_create_new_conversation_requires_authentication(client) -> None:
    response = client.post(f"/api/v1/documents/{uuid4()}/conversations/new")

    assert response.status_code == 401


def test_create_new_conversation_enforces_document_ownership(client, test_session_factory) -> None:
    owner_headers, owner_id = _auth_headers(client, "conv-owner@example.com")
    requester_headers, _ = _auth_headers(client, "conv-requester@example.com")
    document_id = _create_document_for_user(
        test_session_factory=test_session_factory,
        user_id=owner_id,
    )

    response = client.post(
        f"/api/v1/documents/{document_id}/conversations/new",
        headers=requester_headers,
    )

    assert response.status_code == 404
    assert response.json() == {
        "detail": {
            "code": "DOCUMENT_NOT_FOUND",
            "message": "Document not found.",
            "field": None,
        }
    }

    owner_response = client.post(
        f"/api/v1/documents/{document_id}/conversations/new",
        headers=owner_headers,
    )
    assert owner_response.status_code == 201


def test_create_new_conversation_returns_conversation_id_and_creates_row(
    client,
    test_session_factory,
) -> None:
    headers, user_id = _auth_headers(client, "conv-create@example.com")
    document_id = _create_document_for_user(
        test_session_factory=test_session_factory,
        user_id=user_id,
    )

    response = client.post(
        f"/api/v1/documents/{document_id}/conversations/new",
        headers=headers,
    )

    assert response.status_code == 201
    conversation_id = UUID(response.json()["conversation_id"])

    async def _assert_created() -> None:
        async with test_session_factory() as session:
            row = await session.get(Conversation, conversation_id)
            assert row is not None
            assert row.user_id == user_id
            assert row.document_id == document_id

    asyncio.run(_assert_created())
