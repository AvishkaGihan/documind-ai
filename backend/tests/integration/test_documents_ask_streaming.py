import asyncio
import json
from datetime import UTC, datetime
from uuid import UUID, uuid4

from app.models.conversation import Conversation
from app.models.document import Document, DocumentStatus
from app.models.message import Message, MessageRole


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


def _parse_sse_events(content: bytes) -> list[tuple[str, dict[str, object]]]:
    text = content.decode("utf-8")
    frames = [frame for frame in text.split("\n\n") if frame.strip()]
    parsed: list[tuple[str, dict[str, object]]] = []
    for frame in frames:
        event_name = ""
        data_payload = "{}"
        for line in frame.splitlines():
            if line.startswith("event: "):
                event_name = line.replace("event: ", "", 1)
            if line.startswith("data: "):
                data_payload = line.replace("data: ", "", 1)
        parsed.append((event_name, json.loads(data_payload)))
    return parsed


def _get_streamed_events(client, url: str, *, headers: dict[str, str], payload: dict[str, str]):
    stream_headers = {**headers, "Accept": "text/event-stream"}
    with client.stream("POST", url, headers=stream_headers, json=payload) as response:
        assert response.status_code == 200
        assert response.headers["content-type"].startswith("text/event-stream")
        content = b"".join(response.iter_bytes())
    return _parse_sse_events(content)


def test_streaming_ask_returns_token_and_done_and_persists_messages(
    client,
    test_session_factory,
    monkeypatch,
) -> None:
    from app.routers import documents as documents_router

    class FakeRagService:
        async def stream_answer_events(
            self,
            *,
            user_id,
            document_id,
            question,
            conversation_history,
        ):
            del user_id, document_id, question
            del conversation_history
            yield "token", {"content": "According to page "}
            yield "token", {"content": "4, this is streamed."}
            yield "citation", {"page": 4, "text": "Key retained point"}

    monkeypatch.setattr(documents_router, "RagService", FakeRagService)

    headers, user_id = _auth_headers(client, "ask-streaming-success@example.com")
    document_id = _create_document_for_user(
        test_session_factory=test_session_factory,
        user_id=user_id,
        status=DocumentStatus.READY,
    )

    events = _get_streamed_events(
        client,
        f"/api/v1/documents/{document_id}/ask",
        headers=headers,
        payload={"question": "What is retained?"},
    )

    assert any(name == "token" for name, _ in events)
    assert events[-1][0] == "done"
    done_payload = events[-1][1]
    message_id = UUID(str(done_payload["message_id"]))

    async def _assert_persisted() -> None:
        async with test_session_factory() as session:
            conversations = (await session.execute(
                Conversation.__table__.select().where(
                    Conversation.user_id == user_id,
                    Conversation.document_id == document_id,
                )
            )).all()
            assert len(conversations) == 1

            messages = (await session.execute(
                Message.__table__.select().where(
                    Message.conversation_id == conversations[0].id
                )
            )).all()
            assert len(messages) == 2
            roles = {row.role for row in messages}
            assert roles == {MessageRole.USER.value, MessageRole.ASSISTANT.value}
            assert any(row.id == message_id for row in messages)

    asyncio.run(_assert_persisted())


def test_streaming_ask_emits_error_event_when_llm_unavailable(
    client,
    test_session_factory,
    monkeypatch,
) -> None:
    from app.routers import documents as documents_router

    class FakeRagService:
        async def stream_answer_events(
            self,
            *,
            user_id,
            document_id,
            question,
            conversation_history,
        ):
            del user_id, document_id, question
            del conversation_history
            yield "error", {
                "code": "LLM_UNAVAILABLE",
                "message": "Unable to generate an answer at the moment.",
            }

    monkeypatch.setattr(documents_router, "RagService", FakeRagService)

    headers, user_id = _auth_headers(client, "ask-streaming-error@example.com")
    document_id = _create_document_for_user(
        test_session_factory=test_session_factory,
        user_id=user_id,
        status=DocumentStatus.READY,
    )

    events = _get_streamed_events(
        client,
        f"/api/v1/documents/{document_id}/ask",
        headers=headers,
        payload={"question": "Will this fail?"},
    )

    assert events[-1] == (
        "error",
        {
            "code": "LLM_UNAVAILABLE",
            "message": "Unable to generate an answer at the moment.",
        },
    )

    async def _assert_not_persisted() -> None:
        async with test_session_factory() as session:
            conversations = (await session.execute(
                Conversation.__table__.select().where(
                    Conversation.user_id == user_id,
                    Conversation.document_id == document_id,
                )
            )).all()
            assert len(conversations) == 0

    asyncio.run(_assert_not_persisted())


def test_streaming_ask_returns_http_429_when_rate_limited(
    client,
    test_session_factory,
    monkeypatch,
) -> None:
    from app.routers import documents as documents_router
    from app.services.rag_service import RagServiceRateLimitError

    class FakeRagService:
        async def stream_answer_events(
            self,
            *,
            user_id,
            document_id,
            question,
            conversation_history,
        ):
            del user_id, document_id, question
            del conversation_history
            raise RagServiceRateLimitError(retry_after_seconds=17)
            yield "token", {"content": "unreachable"}

    monkeypatch.setattr(documents_router, "RagService", FakeRagService)

    headers, user_id = _auth_headers(client, "ask-streaming-ratelimit@example.com")
    document_id = _create_document_for_user(
        test_session_factory=test_session_factory,
        user_id=user_id,
        status=DocumentStatus.READY,
    )

    response = client.post(
        f"/api/v1/documents/{document_id}/ask",
        headers={**headers, "Accept": "text/event-stream"},
        json={"question": "Will this be rate limited?"},
    )

    assert response.status_code == 429
    assert response.headers.get("Retry-After") == "17"
    assert response.json() == {
        "detail": {
            "code": "RATE_LIMITED",
            "message": "You've reached the query limit. Please wait 17 seconds.",
            "field": None,
        }
    }
