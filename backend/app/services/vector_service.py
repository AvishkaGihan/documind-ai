from __future__ import annotations

from collections.abc import Sequence
from dataclasses import dataclass
from typing import TYPE_CHECKING, Any
from uuid import UUID

import anyio
import chromadb

from app.config import get_settings

if TYPE_CHECKING:
    from app.services.processing.chunker import Chunk
else:
    Chunk = Any

DEFAULT_SIMILARITY_THRESHOLD = 0.75


@dataclass(frozen=True)
class RetrievedChunk:
    page_number: int
    chunk_text: str
    distance: float


class VectorServiceError(Exception):
    """Raised when ChromaDB operations fail."""


class VectorService:
    def __init__(self, *, client: chromadb.ClientAPI | None = None) -> None:
        self._client = client

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

    async def query_chunks(
        self,
        *,
        user_id: UUID,
        document_id: UUID,
        query_embedding: Sequence[float],
        top_k: int = 5,
    ) -> list[RetrievedChunk]:
        collection_name = self._collection_name(user_id=user_id, document_id=document_id)

        try:
            return await anyio.to_thread.run_sync(
                self._query_chunks_sync,
                collection_name,
                list(query_embedding),
                top_k,
            )
        except Exception as exc:  # pragma: no cover - defensive conversion boundary
            raise VectorServiceError(f"Failed to query ChromaDB collection: {exc}") from exc

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
        collection = self._get_client().get_or_create_collection(
            name=collection_name,
            metadata={"hnsw:space": "cosine"},
        )
        collection.upsert(
            ids=ids,
            embeddings=embeddings,
            documents=documents,
            metadatas=metadatas,
        )

    def _query_chunks_sync(
        self,
        collection_name: str,
        query_embedding: list[float],
        top_k: int,
    ) -> list[RetrievedChunk]:
        collection = self._get_client().get_or_create_collection(
            name=collection_name,
            metadata={"hnsw:space": "cosine"},
        )
        payload = collection.query(
            query_embeddings=[query_embedding],
            n_results=top_k,
            include=["documents", "metadatas", "distances"],
        )

        documents = payload.get("documents") or [[]]
        metadatas = payload.get("metadatas") or [[]]
        distances = payload.get("distances") or [[]]

        docs_row = documents[0] if documents else []
        metadata_row = metadatas[0] if metadatas else []
        distances_row = distances[0] if distances else []

        retrieved: list[RetrievedChunk] = []
        for index, document in enumerate(docs_row):
            metadata = metadata_row[index] if index < len(metadata_row) else {}
            distance = distances_row[index] if index < len(distances_row) else 1.0
            page_number = int(metadata.get("page_number", 0)) if metadata else 0
            if page_number <= 0:
                continue
            chunk_text = str(metadata.get("chunk_text") or document or "")
            retrieved.append(
                RetrievedChunk(
                    page_number=page_number,
                    chunk_text=chunk_text,
                    distance=float(distance),
                )
            )

        return retrieved

    def _delete_collection_sync(self, collection_name: str) -> None:
        client = self._get_client()
        existing = client.list_collections()
        existing_names = [item if isinstance(item, str) else item.name for item in existing]
        if collection_name in existing_names:
            client.delete_collection(name=collection_name)

    def _get_client(self) -> chromadb.ClientAPI:
        if self._client is None:
            self._client = self._build_default_client()
        return self._client
