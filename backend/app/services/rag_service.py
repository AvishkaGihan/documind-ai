from __future__ import annotations

from uuid import UUID

from app.schemas.qa import AskQuestionResponse, CitationPublic
from app.services.llm_service import LlmService, LlmServiceError
from app.services.processing.embedder import Embedder, EmbeddingError
from app.services.vector_service import (
    DEFAULT_SIMILARITY_THRESHOLD,
    RetrievedChunk,
    VectorService,
    VectorServiceError,
)

DEFAULT_TOP_K = 5
MAX_CITATION_TEXT_LENGTH = 280
FALLBACK_NO_RELEVANT_INFO = (
    "I couldn't find relevant information for this question in the document."
)

SYSTEM_PROMPT = (
    "You are a document question-answering assistant. "
    "Use only the provided context chunks to answer the user question. "
    "If the context is insufficient, respond exactly with: "
    f"{FALLBACK_NO_RELEVANT_INFO} "
    "When information exists, include citations in the answer text using 'According to page X...'."
)


class RagServiceError(Exception):
    """Raised when RAG orchestration fails."""


class RagService:
    def __init__(
        self,
        *,
        embedder: Embedder | None = None,
        vector_service: VectorService | None = None,
        llm_service: LlmService | None = None,
        similarity_threshold: float = DEFAULT_SIMILARITY_THRESHOLD,
    ) -> None:
        self._embedder = embedder or Embedder()
        self._vector_service = vector_service or VectorService()
        self._llm_service = llm_service or LlmService()
        self._similarity_threshold = similarity_threshold

    async def ask_question(
        self,
        *,
        user_id: UUID,
        document_id: UUID,
        question: str,
        top_k: int = DEFAULT_TOP_K,
    ) -> AskQuestionResponse:
        try:
            question_embeddings = await self._embedder.embed_texts([question])
            if not question_embeddings:
                raise RagServiceError("Question embedding generation returned no vectors")

            retrieved_chunks = await self._vector_service.query_chunks(
                user_id=user_id,
                document_id=document_id,
                query_embedding=question_embeddings[0],
                top_k=top_k,
            )

            relevant_chunks = [
                chunk
                for chunk in retrieved_chunks
                if self._distance_to_similarity(chunk.distance) >= self._similarity_threshold
            ]
            if not relevant_chunks:
                return AskQuestionResponse(answer=FALLBACK_NO_RELEVANT_INFO, citations=[])

            answer = await self._llm_service.generate_answer(
                question=question,
                context_chunks=relevant_chunks,
                system_prompt=SYSTEM_PROMPT,
            )
            citations = self._build_citations(relevant_chunks)
            return AskQuestionResponse(answer=answer, citations=citations)
        except (EmbeddingError, VectorServiceError, LlmServiceError) as exc:
            raise RagServiceError("Failed to generate RAG answer") from exc

    @staticmethod
    def _distance_to_similarity(distance: float) -> float:
        # Chroma cosine distance is converted into similarity for thresholding.
        return 1.0 - float(distance)

    @staticmethod
    def _build_citations(chunks: list[RetrievedChunk]) -> list[CitationPublic]:
        citations: list[CitationPublic] = []
        seen: set[tuple[int, str]] = set()
        for chunk in chunks:
            excerpt = chunk.chunk_text.strip()[:MAX_CITATION_TEXT_LENGTH]
            key = (chunk.page_number, excerpt)
            if not excerpt or key in seen:
                continue
            citations.append(CitationPublic(page_number=chunk.page_number, text=excerpt))
            seen.add(key)
        return citations
