from datetime import UTC, datetime

from app.services.llm_service import LlmService
from app.services.vector_service import RetrievedChunk


class _HistoryMessage:
    def __init__(self, role: str, content: str) -> None:
        self.role = role
        self.content = content
        self.created_at = datetime.now(UTC)


def test_build_messages_preserves_system_prompt_and_truncates_to_recent_n() -> None:
    service = LlmService(api_key="test", max_retries=0)

    chunks = [RetrievedChunk(page_number=2, chunk_text="Chunk text", distance=0.1)]
    history = [
        _HistoryMessage("user", "u1"),
        _HistoryMessage("assistant", "a1"),
        _HistoryMessage("user", "u2"),
        _HistoryMessage("assistant", "a2"),
    ]

    messages = service._build_messages(
        question="latest question",
        context_chunks=chunks,
        system_prompt="system",
        conversation_history=history,
        max_history_messages=2,
    )

    assert messages[0].content == "system"
    assert [message.content for message in messages[1:3]] == ["u2", "a2"]
    assert messages[-1].content == "Context:\nPage 2: Chunk text\n\nQuestion:\nlatest question"


def test_build_messages_ignores_unsupported_history_roles() -> None:
    service = LlmService(api_key="test", max_retries=0)

    messages = service._build_messages(
        question="q",
        context_chunks=[],
        system_prompt="system",
        conversation_history=[_HistoryMessage("system", "ignore me")],
        max_history_messages=5,
    )

    assert len(messages) == 2
    assert messages[0].content == "system"
    assert messages[1].content.endswith("Question:\nq")
