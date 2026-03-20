import asyncio
from datetime import UTC, datetime
from uuid import UUID, uuid4

from app.models.conversation import Conversation
from app.models.document import Document, DocumentStatus
from app.models.message import Message, MessageRole


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


def _seed_conversation_messages(
    *,
    test_session_factory,
    user_id: UUID,
    document_id: UUID,
) -> UUID:
    conversation_id = uuid4()

    async def _seed() -> None:
        async with test_session_factory() as session:
            session.add(
                Conversation(
                    id=conversation_id,
                    user_id=user_id,
                    document_id=document_id,
                    created_at=datetime.now(UTC),
                    updated_at=datetime.now(UTC),
                )
            )
            session.add_all(
                [
                    Message(
                        conversation_id=conversation_id,
                        role=MessageRole.USER,
                        content="first",
                        citations=[],
                        created_at=datetime(2026, 1, 1, tzinfo=UTC),
                    ),
                    Message(
                        conversation_id=conversation_id,
                        role=MessageRole.ASSISTANT,
                        content="second",
                        citations=[{"page_number": 1, "text": "t"}],
                        created_at=datetime(2026, 1, 2, tzinfo=UTC),
                    ),
                ]
            )
            await session.commit()

    asyncio.run(_seed())
    return conversation_id


def test_list_messages_requires_authentication(client) -> None:
    response = client.get(
        f"/api/v1/documents/{uuid4()}/conversations/{uuid4()}/messages"
    )

    assert response.status_code == 401


def test_list_messages_enforces_conversation_ownership(client, test_session_factory) -> None:
    owner_headers, owner_id = _auth_headers(client, "msg-owner@example.com")
    requester_headers, _ = _auth_headers(client, "msg-requester@example.com")
    document_id = _create_document_for_user(
        test_session_factory=test_session_factory,
        user_id=owner_id,
    )
    conversation_id = _seed_conversation_messages(
        test_session_factory=test_session_factory,
        user_id=owner_id,
        document_id=document_id,
    )

    response = client.get(
        f"/api/v1/documents/{document_id}/conversations/{conversation_id}/messages",
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

    owner_response = client.get(
        f"/api/v1/documents/{document_id}/conversations/{conversation_id}/messages",
        headers=owner_headers,
    )
    assert owner_response.status_code == 200


def test_list_messages_returns_chronological_order_and_list_envelope(
    client,
    test_session_factory,
) -> None:
    headers, user_id = _auth_headers(client, "msg-order@example.com")
    document_id = _create_document_for_user(
        test_session_factory=test_session_factory,
        user_id=user_id,
    )
    conversation_id = _seed_conversation_messages(
        test_session_factory=test_session_factory,
        user_id=user_id,
        document_id=document_id,
    )

    response = client.get(
        f"/api/v1/documents/{document_id}/conversations/{conversation_id}/messages",
        headers=headers,
    )

    assert response.status_code == 200
    payload = response.json()
    assert payload["total"] == 2
    assert payload["page"] == 1
    assert payload["page_size"] == 2
    assert [item["content"] for item in payload["items"]] == ["first", "second"]
    assert [item["role"] for item in payload["items"]] == ["user", "assistant"]
