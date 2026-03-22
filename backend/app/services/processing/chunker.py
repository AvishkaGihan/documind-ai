from __future__ import annotations

from dataclasses import dataclass
from uuid import UUID

from app.services.processing.extractor import PageText

DEFAULT_CHUNK_SIZE_TOKENS = 500
DEFAULT_CHUNK_OVERLAP_TOKENS = 50


@dataclass(frozen=True, slots=True)
class Chunk:
    text: str
    page_number: int
    chunk_index: int
    document_id: UUID


class Chunker:
    def __init__(
        self,
        *,
        chunk_size_tokens: int = DEFAULT_CHUNK_SIZE_TOKENS,
        chunk_overlap_tokens: int = DEFAULT_CHUNK_OVERLAP_TOKENS,
    ) -> None:
        if chunk_size_tokens <= 0:
            raise ValueError("chunk_size_tokens must be positive")
        if chunk_overlap_tokens < 0:
            raise ValueError("chunk_overlap_tokens cannot be negative")
        if chunk_overlap_tokens >= chunk_size_tokens:
            raise ValueError("chunk_overlap_tokens must be less than chunk_size_tokens")

        self._chunk_size_tokens = chunk_size_tokens
        self._chunk_overlap_tokens = chunk_overlap_tokens

    def chunk_pages(self, *, document_id: UUID, pages: list[PageText]) -> list[Chunk]:
        chunks: list[Chunk] = []

        for page in pages:
            words = page.text.split()
            if not words:
                continue

            start = 0
            chunk_index = 0
            while start < len(words):
                end = min(start + self._chunk_size_tokens, len(words))
                chunk_words = words[start:end]
                chunks.append(
                    Chunk(
                        text=" ".join(chunk_words),
                        page_number=page.page_number,
                        chunk_index=chunk_index,
                        document_id=document_id,
                    )
                )
                if end == len(words):
                    break
                start = end - self._chunk_overlap_tokens
                chunk_index += 1

        return chunks
