import asyncio
from datetime import UTC, datetime
from uuid import UUID, uuid4

from sqlalchemy import select

from app.models.conversation import Conversation
from app.models.document import Document, DocumentStatus
from app.models.message import Message, MessageRole
from app.models.user import User
from app.services.storage_service import StorageService
from app.services.vector_service import VectorService


def _auth_headers(client, email: str) -> tuple[dict[str, str], UUID, str]:
    signup_payload = {"email": email, "password": "strongpass123"}
    signup_response = client.post("/api/v1/auth/signup", json=signup_payload)
    assert signup_response.status_code == 201

    body = signup_response.json()
    access_token = body["tokens"]["access_token"]
    user_id = UUID(body["user"]["id"])
    return {"Authorization": f"Bearer {access_token}"}, user_id, access_token


def _seed_user_document_graph(
    *,
    test_session_factory,
    user_id: UUID,
    doc_count: int,
) -> list[tuple[UUID, UUID, UUID, str]]:
    seeded: list[tuple[UUID, UUID, UUID, str]] = []

    async def _create() -> None:
        async with test_session_factory() as session:
            now = datetime.now(UTC)
            for _ in range(doc_count):
                document_id = uuid4()
                conversation_id = uuid4()
                message_id = uuid4()
                file_path = f"users/{user_id}/documents/{document_id}.pdf"

                session.add(
                    Document(
                        id=document_id,
                        user_id=user_id,
                        title="to-delete",
                        file_path=file_path,
                        file_size=1024,
                        page_count=3,
                        status=DocumentStatus.READY,
                        error_message=None,
                        created_at=now,
                        updated_at=now,
                    )
                )
                session.add(
                    Conversation(
                        id=conversation_id,
                        document_id=document_id,
                        user_id=user_id,
                        created_at=now,
                        updated_at=now,
                    )
                )
                session.add(
                    Message(
                        id=message_id,
                        conversation_id=conversation_id,
                        role=MessageRole.USER,
                        content="hello",
                        citations=[],
                        created_at=now,
                    )
                )
                seeded.append((document_id, conversation_id, message_id, file_path))
            await session.commit()

    asyncio.run(_create())
    return seeded


def test_delete_me_requires_authentication(client) -> None:
    response = client.delete("/api/v1/user/me")

    assert response.status_code == 401
    assert response.json() == {
        "detail": {
            "code": "INVALID_TOKEN",
            "message": "Invalid or missing access token.",
            "field": None,
        }
    }


def test_delete_me_returns_204_and_deletes_user_owned_data(
    client,
    test_session_factory,
    monkeypatch,
) -> None:
    headers, user_id, _ = _auth_headers(client, "delete-me-owner@example.com")
    seeded = _seed_user_document_graph(
        test_session_factory=test_session_factory,
        user_id=user_id,
        doc_count=2,
    )

    storage_calls: list[str] = []
    vector_calls: list[tuple[UUID, UUID]] = []

    async def _fake_delete_pdf(self, *, object_key: str) -> None:
        storage_calls.append(object_key)

    async def _fake_delete_collection(self, *, user_id: UUID, document_id: UUID) -> None:
        vector_calls.append((user_id, document_id))

    monkeypatch.setattr(StorageService, "delete_pdf", _fake_delete_pdf)
    monkeypatch.setattr(VectorService, "delete_document_collection", _fake_delete_collection)

    response = client.delete("/api/v1/user/me", headers=headers)

    assert response.status_code == 204
    assert response.text == ""

    seeded_doc_ids = {doc_id for doc_id, _, _, _ in seeded}
    seeded_conversation_ids = {conversation_id for _, conversation_id, _, _ in seeded}
    seeded_message_ids = {message_id for _, _, message_id, _ in seeded}
    seeded_file_paths = {file_path for _, _, _, file_path in seeded}

    assert set(storage_calls) == seeded_file_paths
    assert {document_id for _, document_id in vector_calls} == seeded_doc_ids
    assert {call_user_id for call_user_id, _ in vector_calls} == {user_id}

    async def _assert_deleted() -> None:
        async with test_session_factory() as session:
            user_result = await session.execute(select(User).where(User.id == user_id))
            assert user_result.scalar_one_or_none() is None

            for document_id in seeded_doc_ids:
                document_result = await session.execute(
                    select(Document).where(Document.id == document_id)
                )
                assert document_result.scalar_one_or_none() is None

            for conversation_id in seeded_conversation_ids:
                conversation_result = await session.execute(
                    select(Conversation).where(Conversation.id == conversation_id)
                )
                assert conversation_result.scalar_one_or_none() is None

            for message_id in seeded_message_ids:
                message_result = await session.execute(
                    select(Message).where(Message.id == message_id)
                )
                assert message_result.scalar_one_or_none() is None

    asyncio.run(_assert_deleted())


def test_delete_me_invalidates_existing_access_token(client) -> None:
    headers, _, _ = _auth_headers(client, "delete-me-token@example.com")

    delete_response = client.delete("/api/v1/user/me", headers=headers)
    assert delete_response.status_code == 204

    post_delete_response = client.get("/api/v1/documents", headers=headers)
    assert post_delete_response.status_code == 401
    assert post_delete_response.json() == {
        "detail": {
            "code": "INVALID_TOKEN",
            "message": "Invalid or missing access token.",
            "field": None,
        }
    }


def test_delete_me_returns_500_when_external_cleanup_fails(
    client,
    test_session_factory,
    monkeypatch,
) -> None:
    headers, user_id, _ = _auth_headers(client, "delete-me-failure@example.com")
    seeded = _seed_user_document_graph(
        test_session_factory=test_session_factory,
        user_id=user_id,
        doc_count=1,
    )
    seeded_document_id = seeded[0][0]

    async def _fake_delete_collection(self, *, user_id: UUID, document_id: UUID) -> None:
        raise RuntimeError("vector cleanup failed")

    monkeypatch.setattr(VectorService, "delete_document_collection", _fake_delete_collection)

    response = client.delete("/api/v1/user/me", headers=headers)

    assert response.status_code == 500
    assert response.json() == {
        "detail": {
            "code": "USER_DELETION_FAILED",
            "message": "Failed to delete account resources.",
            "field": None,
        }
    }

    async def _assert_not_deleted() -> None:
        async with test_session_factory() as session:
            user_result = await session.execute(select(User).where(User.id == user_id))
            document_result = await session.execute(
                select(Document).where(Document.id == seeded_document_id)
            )
            assert user_result.scalar_one_or_none() is not None
            assert document_result.scalar_one_or_none() is not None

    asyncio.run(_assert_not_deleted())
