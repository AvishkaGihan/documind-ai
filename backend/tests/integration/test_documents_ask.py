import asyncio
from datetime import UTC, datetime
from uuid import UUID, uuid4

from app.models.document import Document, DocumentStatus
from app.routers import documents as documents_router
from app.schemas.qa import AskQuestionResponse, CitationPublic


class FakeRagService:
    def __init__(self) -> None:
        self.calls: list[dict[str, object]] = []

    async def ask_question(
        self,
        *,
        user_id: UUID,
        document_id: UUID,
        question: str,
    ) -> AskQuestionResponse:
        self.calls.append(
            {
                "user_id": user_id,
                "document_id": document_id,
                "question": question,
            }
        )
        return AskQuestionResponse(
            answer="According to page 4, the key point is retained.",
            citations=[CitationPublic(page_number=4, text="Key retained point")],
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


def test_ask_requires_authentication(client) -> None:
    response = client.post(
        f"/api/v1/documents/{uuid4()}/ask",
        json={"question": "What is in the document?"},
    )

    assert response.status_code == 401
    assert response.json() == {
        "detail": {
            "code": "INVALID_TOKEN",
            "message": "Invalid or missing access token.",
            "field": None,
        }
    }


def test_ask_returns_404_for_non_owner(client, test_session_factory) -> None:
    owner_headers, owner_id = _auth_headers(client, "ask-owner@example.com")
    requester_headers, _ = _auth_headers(client, "ask-requester@example.com")
    document_id = _create_document_for_user(
        test_session_factory=test_session_factory,
        user_id=owner_id,
        status=DocumentStatus.READY,
    )

    response = client.post(
        f"/api/v1/documents/{document_id}/ask",
        headers=requester_headers,
        json={"question": "What is in the document?"},
    )

    assert response.status_code == 404
    assert response.json() == {
        "detail": {
            "code": "DOCUMENT_NOT_FOUND",
            "message": "Document not found.",
            "field": None,
        }
    }

    owner_check = client.post(
        f"/api/v1/documents/{document_id}/ask",
        headers=owner_headers,
        json={"question": "What is in the document?"},
    )
    assert owner_check.status_code != 404


def test_ask_returns_document_not_ready_error(client, test_session_factory) -> None:
    headers, user_id = _auth_headers(client, "ask-not-ready@example.com")
    document_id = _create_document_for_user(
        test_session_factory=test_session_factory,
        user_id=user_id,
        status=DocumentStatus.PROCESSING,
    )

    response = client.post(
        f"/api/v1/documents/{document_id}/ask",
        headers=headers,
        json={"question": "Can I query this yet?"},
    )

    assert response.status_code == 409
    assert response.json() == {
        "detail": {
            "code": "DOCUMENT_NOT_READY",
            "message": "Document is still processing. Try again when status is ready.",
            "field": None,
        }
    }


def test_ask_returns_answer_with_citations_for_ready_document(
    client,
    test_session_factory,
    monkeypatch,
) -> None:
    headers, user_id = _auth_headers(client, "ask-ready@example.com")
    document_id = _create_document_for_user(
        test_session_factory=test_session_factory,
        user_id=user_id,
        status=DocumentStatus.READY,
    )

    fake_rag = FakeRagService()

    def _fake_rag_service_factory() -> FakeRagService:
        return fake_rag

    monkeypatch.setattr(documents_router, "RagService", _fake_rag_service_factory)

    response = client.post(
        f"/api/v1/documents/{document_id}/ask",
        headers=headers,
        json={"question": "What is retained?"},
    )

    assert response.status_code == 200
    assert response.json() == {
        "answer": "According to page 4, the key point is retained.",
        "citations": [{"page_number": 4, "text": "Key retained point"}],
    }
    assert len(fake_rag.calls) == 1
    assert fake_rag.calls[0]["user_id"] == user_id
    assert fake_rag.calls[0]["document_id"] == document_id
    assert fake_rag.calls[0]["question"] == "What is retained?"
