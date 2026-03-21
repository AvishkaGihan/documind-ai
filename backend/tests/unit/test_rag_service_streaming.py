import asyncio
from uuid import uuid4

from app.services.llm_service import LlmServiceError
from app.services.rag_service import FALLBACK_NO_RELEVANT_INFO, RagService
from app.services.vector_service import RetrievedChunk


class StubEmbedder:
    def __init__(self, embedding: list[float]) -> None:
        self.embedding = embedding

    async def embed_texts(self, texts: list[str]) -> list[list[float]]:
        return [self.embedding]


class StubVectorService:
    def __init__(self, chunks: list[RetrievedChunk]) -> None:
        self.chunks = chunks

    async def query_chunks(
        self,
        *,
        user_id,
        document_id,
        query_embedding,
        top_k: int = 5,
    ) -> list[RetrievedChunk]:
        return self.chunks


class StubStreamingLlmService:
    def __init__(self, tokens: list[str] | None = None, *, fail: bool = False) -> None:
        self.tokens = tokens or []
        self.fail = fail

    async def stream_answer(
        self,
        *,
        question: str,
        context_chunks,
        system_prompt: str,
        conversation_history=None,
    ):
        if self.fail:
            raise LlmServiceError("groq unavailable")

        for token in self.tokens:
            yield token


async def _collect_events(
    rag_service: RagService,
    *,
    question: str,
) -> list[tuple[str, dict[str, object]]]:
    events: list[tuple[str, dict[str, object]]] = []
    async for name, payload in rag_service.stream_answer_events(
        user_id=uuid4(),
        document_id=uuid4(),
        question=question,
    ):
        events.append((name, payload))
    return events


def test_streaming_emits_token_then_citation_events_in_order() -> None:
    rag_service = RagService(
        embedder=StubEmbedder([0.12, 0.34]),
        vector_service=StubVectorService(
            [
                RetrievedChunk(page_number=4, chunk_text="Key retained point", distance=0.1),
                RetrievedChunk(page_number=7, chunk_text="Secondary point", distance=0.2),
            ]
        ),
        llm_service=StubStreamingLlmService(
            [
                "According to page ",
                "4, the answer starts here. ",
                "According to page 4, this reference should not duplicate.",
            ]
        ),
    )

    events = asyncio.run(_collect_events(rag_service, question="What is retained?"))

    token_events = [payload for name, payload in events if name == "token"]
    citation_events = [payload for name, payload in events if name == "citation"]

    assert len(token_events) == 3
    assert token_events[0] == {"content": "According to page "}
    assert token_events[1] == {"content": "4, the answer starts here. "}
    assert len(citation_events) == 1
    assert citation_events[0]["page"] == 4
    assert citation_events[0]["text"] == "Key retained point"


def test_streaming_emits_error_event_when_llm_fails() -> None:
    rag_service = RagService(
        embedder=StubEmbedder([0.12, 0.34]),
        vector_service=StubVectorService(
            [RetrievedChunk(page_number=4, chunk_text="Key retained point", distance=0.1)]
        ),
        llm_service=StubStreamingLlmService(fail=True),
    )

    events = asyncio.run(_collect_events(rag_service, question="What failed?"))

    assert events == [
        (
            "error",
            {
                "code": "LLM_UNAVAILABLE",
                "message": "Unable to generate an answer at the moment.",
            },
        )
    ]


def test_streaming_emits_fallback_token_when_no_relevant_chunks() -> None:
    rag_service = RagService(
        embedder=StubEmbedder([0.12, 0.34]),
        vector_service=StubVectorService(
            [RetrievedChunk(page_number=4, chunk_text="Low similarity", distance=0.99)]
        ),
        llm_service=StubStreamingLlmService(["should not be used"]),
    )

    events = asyncio.run(_collect_events(rag_service, question="No support"))

    assert events == [
        (
            "token",
            {
                "content": (
                    "I couldn't find relevant information for this question in the document. "
                    "Try rephrasing your question or asking about a different topic."
                )
            },
        )
    ]
