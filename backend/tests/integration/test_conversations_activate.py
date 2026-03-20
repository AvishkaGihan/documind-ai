import asyncio
from datetime import UTC, datetime, timedelta
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
                    title="conversation-activate-doc",
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
                    created_at=updated_at - timedelta(minutes=2),
                    updated_at=updated_at,
                )
            )
            await session.commit()

    asyncio.run(_create())
    return conversation_id


def _create_message(*, test_session_factory, conversation_id: UUID, content: str) -> None:
    async def _create() -> None:
        async with test_session_factory() as session:
            session.add(
                Message(
                    id=uuid4(),
                    conversation_id=conversation_id,
                    role=MessageRole.USER,
                    content=content,
                    citations=[],
                    created_at=datetime.now(UTC),
                )
            )
            await session.commit()

    asyncio.run(_create())


def test_activate_conversation_requires_authentication(client) -> None:
    response = client.post(
        f"/api/v1/documents/{uuid4()}/conversations/{uuid4()}/activate"
    )

    assert response.status_code == 401


def test_activate_conversation_enforces_document_ownership(client, test_session_factory) -> None:
    owner_headers, owner_id = _auth_headers(client, "activate-owner@example.com")
    requester_headers, _ = _auth_headers(client, "activate-requester@example.com")
    document_id = _create_document_for_user(
        test_session_factory=test_session_factory,
        user_id=owner_id,
    )
    conversation_id = _create_conversation(
        test_session_factory=test_session_factory,
        user_id=owner_id,
        document_id=document_id,
        updated_at=datetime.now(UTC) - timedelta(hours=1),
    )

    response = client.post(
        f"/api/v1/documents/{document_id}/conversations/{conversation_id}/activate",
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
        f"/api/v1/documents/{document_id}/conversations/{conversation_id}/activate",
        headers=owner_headers,
    )
    assert owner_response.status_code == 200


def test_activate_conversation_updates_latest_messages_target(client, test_session_factory) -> None:
    headers, user_id = _auth_headers(client, "activate-switch@example.com")
    document_id = _create_document_for_user(
        test_session_factory=test_session_factory,
        user_id=user_id,
    )

    conversation_old = _create_conversation(
        test_session_factory=test_session_factory,
        user_id=user_id,
        document_id=document_id,
        updated_at=datetime.now(UTC) - timedelta(hours=3),
    )
    conversation_new = _create_conversation(
        test_session_factory=test_session_factory,
        user_id=user_id,
        document_id=document_id,
        updated_at=datetime.now(UTC),
    )

    _create_message(
        test_session_factory=test_session_factory,
        conversation_id=conversation_old,
        content="old-conversation-message",
    )
    _create_message(
        test_session_factory=test_session_factory,
        conversation_id=conversation_new,
        content="new-conversation-message",
    )

    before = client.get(
        f"/api/v1/documents/{document_id}/conversations/latest/messages",
        headers=headers,
    )
    assert before.status_code == 200
    assert before.json()["items"][0]["content"] == "new-conversation-message"

    activate_response = client.post(
        f"/api/v1/documents/{document_id}/conversations/{conversation_old}/activate",
        headers=headers,
    )
    assert activate_response.status_code == 200

    after = client.get(
        f"/api/v1/documents/{document_id}/conversations/latest/messages",
        headers=headers,
    )
    assert after.status_code == 200
    assert after.json()["items"][0]["content"] == "old-conversation-message"
