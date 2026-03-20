import asyncio
from datetime import UTC, datetime
from uuid import UUID, uuid4

from app.models.document import Document, DocumentStatus
from app.models.message import Message
from app.routers import documents as documents_router
from app.schemas.qa import AskQuestionResponse, CitationPublic


class FakeRagService:
    calls: list[dict[str, object]] = []

    async def ask_question(
        self,
        *,
        user_id: UUID,
        document_id: UUID,
        question: str,
        conversation_history,
    ) -> AskQuestionResponse:
        self.calls.append(
            {
                "user_id": user_id,
                "document_id": document_id,
                "question": question,
                "history_count": len(conversation_history),
            }
        )
        return AskQuestionResponse(
            answer="According to page 1, answer.",
            citations=[CitationPublic(page_number=1, text="evidence")],
        )


def _auth_headers(client, email: str) -> tuple[dict[str, str], UUID]:
    signup_payload = {"email": email, "password": "strongpass123"}
    signup_response = client.post("/api/v1/auth/signup", json=signup_payload)
    assert signup_response.status_code == 201

    access_token = signup_response.json()["tokens"]["access_token"]
    user_id = UUID(signup_response.json()["user"]["id"])
    return {"Authorization": f"Bearer {access_token}"}, user_id


def _create_document_for_user(
    *,
    test_session_factory,
    user_id: UUID,
    status: DocumentStatus,
) -> UUID:
    document_id = uuid4()

    async def _create() -> None:
        async with test_session_factory() as session:
            session.add(
                Document(
                    id=document_id,
                    user_id=user_id,
                    title="qa-source",
                    file_path=f"users/{user_id}/documents/{document_id}.pdf",
                    file_size=1200,
                    page_count=6,
                    status=status,
                    error_message=None,
                    created_at=datetime.now(UTC),
                    updated_at=datetime.now(UTC),
                )
            )
            await session.commit()

    asyncio.run(_create())
    return document_id


def test_non_streaming_ask_uses_history_and_persists_messages(
    client,
    test_session_factory,
    monkeypatch,
) -> None:
    headers, user_id = _auth_headers(client, "ask-history@example.com")
    document_id = _create_document_for_user(
        test_session_factory=test_session_factory,
        user_id=user_id,
        status=DocumentStatus.READY,
    )

    monkeypatch.setattr(documents_router, "RagService", FakeRagService)

    first = client.post(
        f"/api/v1/documents/{document_id}/ask",
        headers=headers,
        json={"question": "First question?"},
    )
    assert first.status_code == 200

    second = client.post(
        f"/api/v1/documents/{document_id}/ask",
        headers=headers,
        json={"question": "Follow up question?"},
    )
    assert second.status_code == 200

    assert FakeRagService.calls[0]["history_count"] == 0
    assert FakeRagService.calls[1]["history_count"] >= 2

    async def _assert_persisted() -> None:
        async with test_session_factory() as session:
            rows = (await session.execute(Message.__table__.select())).all()
            assert len(rows) == 4

    asyncio.run(_assert_persisted())
