import asyncio
from datetime import UTC, datetime
from uuid import UUID, uuid4

from sqlalchemy import select

from app.models.conversation import Conversation
from app.models.document import Document, DocumentStatus
from app.models.message import Message, MessageRole
from app.services.storage_service import StorageService
from app.services.vector_service import VectorService


def _auth_headers(client, email: str) -> tuple[dict[str, str], UUID]:
    signup_payload = {"email": email, "password": "strongpass123"}
    signup_response = client.post("/api/v1/auth/signup", json=signup_payload)
    assert signup_response.status_code == 201

    access_token = signup_response.json()["tokens"]["access_token"]
    user_id = UUID(signup_response.json()["user"]["id"])
    return {"Authorization": f"Bearer {access_token}"}, user_id


def _seed_document_with_conversation_data(
    *,
    test_session_factory,
    user_id: UUID,
) -> tuple[UUID, UUID, UUID, str]:
    document_id = uuid4()
    conversation_id = uuid4()
    message_id = uuid4()
    file_path = f"users/{user_id}/documents/{document_id}.pdf"

    async def _create() -> None:
        async with test_session_factory() as session:
            now = datetime.now(UTC)
            session.add(
                Document(
                    id=document_id,
                    user_id=user_id,
                    title="to-delete",
                    file_path=file_path,
                    file_size=2048,
                    page_count=5,
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
            await session.commit()

    asyncio.run(_create())
    return document_id, conversation_id, message_id, file_path


def test_delete_requires_authentication(client) -> None:
    response = client.delete(f"/api/v1/documents/{uuid4()}")

    assert response.status_code == 401
    assert response.json() == {
        "detail": {
            "code": "INVALID_TOKEN",
            "message": "Invalid or missing access token.",
            "field": None,
        }
    }


def test_owner_delete_returns_204_and_removes_document_rows(
    client,
    test_session_factory,
    monkeypatch,
) -> None:
    headers, user_id = _auth_headers(client, "delete-owner@example.com")
    document_id, _, _, _ = _seed_document_with_conversation_data(
        test_session_factory=test_session_factory,
        user_id=user_id,
    )

    async def _fake_delete_pdf(self, *, object_key: str) -> None:
        assert object_key.endswith(".pdf")

    async def _fake_delete_collection(self, *, user_id: UUID, document_id: UUID) -> None:
        assert user_id
        assert document_id

    monkeypatch.setattr(StorageService, "delete_pdf", _fake_delete_pdf)
    monkeypatch.setattr(VectorService, "delete_document_collection", _fake_delete_collection)

    response = client.delete(f"/api/v1/documents/{document_id}", headers=headers)

    assert response.status_code == 204
    assert response.text == ""

    async def _assert_deleted() -> None:
        async with test_session_factory() as session:
            result = await session.execute(
                select(Document).where(
                    Document.id == document_id,
                    Document.user_id == user_id,
                )
            )
            assert result.scalar_one_or_none() is None

    asyncio.run(_assert_deleted())


def test_delete_returns_404_for_non_owner(client, test_session_factory, monkeypatch) -> None:
    owner_headers, owner_user_id = _auth_headers(client, "delete-owner2@example.com")
    requester_headers, _ = _auth_headers(client, "delete-requester@example.com")

    document_id, _, _, _ = _seed_document_with_conversation_data(
        test_session_factory=test_session_factory,
        user_id=owner_user_id,
    )

    async def _fake_delete_pdf(self, *, object_key: str) -> None:
        assert object_key

    async def _fake_delete_collection(self, *, user_id: UUID, document_id: UUID) -> None:
        assert user_id
        assert document_id

    monkeypatch.setattr(StorageService, "delete_pdf", _fake_delete_pdf)
    monkeypatch.setattr(VectorService, "delete_document_collection", _fake_delete_collection)

    response = client.delete(f"/api/v1/documents/{document_id}", headers=requester_headers)

    assert response.status_code == 404
    assert response.json() == {
        "detail": {
            "code": "DOCUMENT_NOT_FOUND",
            "message": "Document not found.",
            "field": None,
        }
    }

    owner_view = client.get(f"/api/v1/documents/{document_id}", headers=owner_headers)
    assert owner_view.status_code == 200


def test_delete_performs_explicit_cascade_cleanup_on_sqlite(
    client,
    test_session_factory,
    monkeypatch,
) -> None:
    headers, user_id = _auth_headers(client, "delete-cascade@example.com")
    document_id, conversation_id, message_id, _ = _seed_document_with_conversation_data(
        test_session_factory=test_session_factory,
        user_id=user_id,
    )

    async def _fake_delete_pdf(self, *, object_key: str) -> None:
        assert object_key

    async def _fake_delete_collection(self, *, user_id: UUID, document_id: UUID) -> None:
        assert user_id
        assert document_id

    monkeypatch.setattr(StorageService, "delete_pdf", _fake_delete_pdf)
    monkeypatch.setattr(VectorService, "delete_document_collection", _fake_delete_collection)

    response = client.delete(f"/api/v1/documents/{document_id}", headers=headers)

    assert response.status_code == 204

    async def _assert_all_deleted() -> None:
        async with test_session_factory() as session:
            document_result = await session.execute(
                select(Document).where(Document.id == document_id)
            )
            conversation_result = await session.execute(
                select(Conversation).where(Conversation.id == conversation_id)
            )
            message_result = await session.execute(select(Message).where(Message.id == message_id))

            assert document_result.scalar_one_or_none() is None
            assert conversation_result.scalar_one_or_none() is None
            assert message_result.scalar_one_or_none() is None

    asyncio.run(_assert_all_deleted())


def test_delete_invokes_storage_and_vector_boundaries(
    client,
    test_session_factory,
    monkeypatch,
) -> None:
    headers, user_id = _auth_headers(client, "delete-boundaries@example.com")
    document_id, _, _, file_path = _seed_document_with_conversation_data(
        test_session_factory=test_session_factory,
        user_id=user_id,
    )

    calls: dict[str, object] = {}

    async def _fake_delete_pdf(self, *, object_key: str) -> None:
        calls["object_key"] = object_key

    async def _fake_delete_collection(self, *, user_id: UUID, document_id: UUID) -> None:
        calls["user_id"] = user_id
        calls["document_id"] = document_id

    monkeypatch.setattr(StorageService, "delete_pdf", _fake_delete_pdf)
    monkeypatch.setattr(VectorService, "delete_document_collection", _fake_delete_collection)

    response = client.delete(f"/api/v1/documents/{document_id}", headers=headers)

    assert response.status_code == 204
    assert calls == {
        "object_key": file_path,
        "user_id": user_id,
        "document_id": document_id,
    }
