import asyncio
from uuid import uuid4

import pytest
from pydantic import ValidationError

from app.schemas.qa import AskQuestionRequest
from app.services.rag_service import FALLBACK_NO_RELEVANT_INFO, RagService
from app.services.vector_service import RetrievedChunk


class StubEmbedder:
    def __init__(self, embedding: list[float]) -> None:
        self.embedding = embedding
        self.calls: list[list[str]] = []

    async def embed_texts(self, texts: list[str]) -> list[list[float]]:
        self.calls.append(texts)
        return [self.embedding]


class StubVectorService:
    def __init__(self, chunks: list[RetrievedChunk]) -> None:
        self.chunks = chunks
        self.calls: list[dict[str, object]] = []

    async def query_chunks(
        self,
        *,
        user_id,
        document_id,
        query_embedding,
        top_k: int = 5,
    ) -> list[RetrievedChunk]:
        self.calls.append(
            {
                "user_id": user_id,
                "document_id": document_id,
                "query_embedding": query_embedding,
                "top_k": top_k,
            }
        )
        return self.chunks


class StubLlmService:
    def __init__(self, answer: str) -> None:
        self.answer = answer
        self.calls: list[dict[str, object]] = []

    async def generate_answer(
        self,
        *,
        question: str,
        context_chunks,
        system_prompt: str,
        conversation_history=None,
    ) -> str:
        self.calls.append(
            {
                "question": question,
                "context_chunks": context_chunks,
                "system_prompt": system_prompt,
                "conversation_history": conversation_history,
            }
        )
        return self.answer


def test_rag_service_happy_path_returns_answer_and_citations() -> None:
    user_id = uuid4()
    document_id = uuid4()
    embedder = StubEmbedder([0.12, 0.34])
    vector_service = StubVectorService(
        [
            RetrievedChunk(page_number=2, chunk_text="Alpha chunk for answer", distance=0.1),
            RetrievedChunk(page_number=5, chunk_text="Beta supporting evidence", distance=0.2),
        ]
    )
    llm_service = StubLlmService("According to page 2, the answer is alpha.")
    rag_service = RagService(
        embedder=embedder,
        vector_service=vector_service,
        llm_service=llm_service,
    )

    async def _run() -> None:
        response = await rag_service.ask_question(
            user_id=user_id,
            document_id=document_id,
            question="What is the alpha finding?",
        )
        assert response.answer == "According to page 2, the answer is alpha."
        assert [citation.page_number for citation in response.citations] == [2, 5]
        assert response.citations[0].text == "Alpha chunk for answer"
        assert response.citations[1].text == "Beta supporting evidence"

        assert embedder.calls == [["What is the alpha finding?"]]
        assert len(vector_service.calls) == 1
        assert len(llm_service.calls) == 1

    asyncio.run(_run())


def test_rag_service_returns_fallback_when_no_chunk_meets_threshold() -> None:
    rag_service = RagService(
        embedder=StubEmbedder([0.5, 0.9]),
        vector_service=StubVectorService(
            [
                RetrievedChunk(
                    page_number=3,
                    chunk_text="Irrelevant content",
                    distance=0.99,
                )
            ]
        ),
        llm_service=StubLlmService("This should not be called"),
    )

    async def _run() -> None:
        response = await rag_service.ask_question(
            user_id=uuid4(),
            document_id=uuid4(),
            question="Question with no support",
        )
        assert (
            response.answer
            == "I couldn't find relevant information for this question in the document. "
            "Try rephrasing your question or asking about a different topic."
        )
        assert response.citations == []

    asyncio.run(_run())


def test_ask_question_request_rejects_empty_question() -> None:
    with pytest.raises(ValidationError):
        AskQuestionRequest(question="")
