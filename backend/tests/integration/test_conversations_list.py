import asyncio
from datetime import UTC, datetime, timedelta
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
                    title="conversation-list-doc",
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


def _create_conversation(
    *,
    test_session_factory,
    user_id: UUID,
    document_id: UUID,
    updated_at: datetime,
) -> UUID:
    conversation_id = uuid4()

    async def _create() -> None:
        async with test_session_factory() as session:
            session.add(
                Conversation(
                    id=conversation_id,
                    user_id=user_id,
                    document_id=document_id,
                    created_at=updated_at - timedelta(minutes=5),
                    updated_at=updated_at,
                )
            )
            await session.commit()

    asyncio.run(_create())
    return conversation_id


def test_list_conversations_requires_authentication(client) -> None:
    response = client.get(f"/api/v1/documents/{uuid4()}/conversations")

    assert response.status_code == 401


def test_list_conversations_enforces_document_ownership(client, test_session_factory) -> None:
    owner_headers, owner_id = _auth_headers(client, "list-owner@example.com")
    requester_headers, _ = _auth_headers(client, "list-requester@example.com")
    document_id = _create_document_for_user(
        test_session_factory=test_session_factory,
        user_id=owner_id,
    )

    owner_response = client.get(
        f"/api/v1/documents/{document_id}/conversations",
        headers=owner_headers,
    )
    assert owner_response.status_code == 200

    response = client.get(
        f"/api/v1/documents/{document_id}/conversations",
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


def test_list_conversations_returns_newest_first(client, test_session_factory) -> None:
    headers, user_id = _auth_headers(client, "list-order@example.com")
    document_id = _create_document_for_user(
        test_session_factory=test_session_factory,
        user_id=user_id,
    )

    oldest = _create_conversation(
        test_session_factory=test_session_factory,
        user_id=user_id,
        document_id=document_id,
        updated_at=datetime.now(UTC) - timedelta(hours=2),
    )
    newest = _create_conversation(
        test_session_factory=test_session_factory,
        user_id=user_id,
        document_id=document_id,
        updated_at=datetime.now(UTC),
    )

    response = client.get(
        f"/api/v1/documents/{document_id}/conversations",
        headers=headers,
    )

    assert response.status_code == 200
    payload = response.json()
    assert payload["total"] == 2
    assert payload["page"] == 1
    assert payload["page_size"] == 2
    assert [item["id"] for item in payload["items"]] == [str(newest), str(oldest)]
