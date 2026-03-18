from __future__ import annotations

from collections.abc import Sequence
from uuid import UUID

import anyio
import chromadb

from app.config import get_settings
from app.services.processing.chunker import Chunk


class VectorServiceError(Exception):
    """Raised when ChromaDB operations fail."""


class VectorService:
    def __init__(self, *, client: chromadb.ClientAPI | None = None) -> None:
        self._client = client or self._build_default_client()

    async def upsert_chunks(
        self,
        *,
        user_id: UUID,
        document_id: UUID,
        chunks: Sequence[Chunk],
        embeddings: Sequence[Sequence[float]],
    ) -> None:
        if not chunks:
            return

        if len(chunks) != len(embeddings):
            raise VectorServiceError("Chunk and embedding counts must match")

        collection_name = self._collection_name(user_id=user_id, document_id=document_id)
        ids = [self._chunk_id(document_id=document_id, chunk=chunk) for chunk in chunks]
        documents = [chunk.text for chunk in chunks]
        metadatas = [
            {
                "page_number": chunk.page_number,
                "chunk_index": chunk.chunk_index,
                "chunk_text": chunk.text,
            }
            for chunk in chunks
        ]

        try:
            await anyio.to_thread.run_sync(
                self._upsert_sync,
                collection_name,
                ids,
                [list(vector) for vector in embeddings],
                documents,
                metadatas,
            )
        except Exception as exc:  # pragma: no cover - defensive conversion boundary
            raise VectorServiceError(f"Failed to upsert embeddings to ChromaDB: {exc}") from exc

    async def delete_document_collection(self, *, user_id: UUID, document_id: UUID) -> None:
        collection_name = self._collection_name(user_id=user_id, document_id=document_id)

        try:
            await anyio.to_thread.run_sync(self._delete_collection_sync, collection_name)
        except Exception as exc:  # pragma: no cover - defensive conversion boundary
            raise VectorServiceError(f"Failed to delete ChromaDB collection: {exc}") from exc

    @staticmethod
    def _collection_name(*, user_id: UUID, document_id: UUID) -> str:
        return f"user_{user_id}_doc_{document_id}"

    @staticmethod
    def _chunk_id(*, document_id: UUID, chunk: Chunk) -> str:
        return f"{document_id}:{chunk.page_number}:{chunk.chunk_index}"

    @staticmethod
    def _build_default_client() -> chromadb.ClientAPI:
        settings = get_settings()
        return chromadb.HttpClient(host=settings.chroma_host, port=settings.chroma_port)

    def _upsert_sync(
        self,
        collection_name: str,
        ids: list[str],
        embeddings: list[list[float]],
        documents: list[str],
        metadatas: list[dict[str, int | str]],
    ) -> None:
        collection = self._client.get_or_create_collection(name=collection_name)
        collection.upsert(
            ids=ids,
            embeddings=embeddings,
            documents=documents,
            metadatas=metadatas,
        )

    def _delete_collection_sync(self, collection_name: str) -> None:
        existing = self._client.list_collections()
        existing_names = [item if isinstance(item, str) else item.name for item in existing]
        if collection_name in existing_names:
            self._client.delete_collection(name=collection_name)
