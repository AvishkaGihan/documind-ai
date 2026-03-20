from __future__ import annotations

from collections.abc import Sequence
from typing import Any

import anyio
from sentence_transformers import SentenceTransformer

from app.services.processing.chunker import Chunk

DEFAULT_EMBEDDING_MODEL = "sentence-transformers/all-MiniLM-L6-v2"


class EmbeddingError(Exception):
    """Raised when embedding generation fails."""


class Embedder:
    def __init__(
        self,
        *,
        model_name: str = DEFAULT_EMBEDDING_MODEL,
        model: Any | None = None,
    ) -> None:
        self._model = model
        self._model_name = model_name

    async def embed_chunks(self, *, chunks: Sequence[Chunk]) -> list[list[float]]:
        if not chunks:
            return []

        return await self.embed_texts([chunk.text for chunk in chunks])

    async def embed_texts(self, texts: Sequence[str]) -> list[list[float]]:
        if not texts:
            return []

        try:
            encoded = await anyio.to_thread.run_sync(self._encode_sync, list(texts))
        except Exception as exc:  # pragma: no cover - defensive conversion boundary
            raise EmbeddingError("Failed to generate embeddings") from exc

        if hasattr(encoded, "tolist"):
            return [list(row) for row in encoded.tolist()]

        return [list(row) for row in encoded]

    def _encode_sync(self, texts: list[str]) -> Any:
        if self._model is None:
            self._model = SentenceTransformer(self._model_name)
        return self._model.encode(texts, convert_to_numpy=True)
