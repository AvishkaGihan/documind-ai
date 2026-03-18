import asyncio
from uuid import uuid4

import chromadb

from app.services.processing.chunker import Chunk
from app.services.vector_service import VectorService


def test_vector_service_upsert_persists_chunk_metadata() -> None:
    client = chromadb.EphemeralClient()
    service = VectorService(client=client)
    user_id = uuid4()
    document_id = uuid4()
    chunks = [
        Chunk(text="alpha text", page_number=1, chunk_index=0, document_id=document_id),
        Chunk(text="beta text", page_number=2, chunk_index=1, document_id=document_id),
    ]
    embeddings = [[0.1, 0.2], [0.3, 0.4]]

    async def _run() -> None:
        await service.upsert_chunks(
            user_id=user_id,
            document_id=document_id,
            chunks=chunks,
            embeddings=embeddings,
        )

    asyncio.run(_run())

    collection_name = f"user_{user_id}_doc_{document_id}"
    collection = client.get_collection(name=collection_name)
    payload = collection.get(include=["metadatas", "documents"])

    assert payload["documents"] == ["alpha text", "beta text"]
    metadatas = payload["metadatas"]
    assert metadatas is not None
    assert metadatas[0]["page_number"] == 1
    assert metadatas[0]["chunk_index"] == 0
    assert metadatas[0]["chunk_text"] == "alpha text"


def test_vector_service_can_delete_document_collection() -> None:
    client = chromadb.EphemeralClient()
    service = VectorService(client=client)
    user_id = uuid4()
    document_id = uuid4()

    async def _run() -> None:
        await service.upsert_chunks(
            user_id=user_id,
            document_id=document_id,
            chunks=[
                Chunk(
                    text="to-remove",
                    page_number=1,
                    chunk_index=0,
                    document_id=document_id,
                )
            ],
            embeddings=[[0.1, 0.2]],
        )
        await service.delete_document_collection(user_id=user_id, document_id=document_id)

    asyncio.run(_run())

    collection_name = f"user_{user_id}_doc_{document_id}"
    existing_names = [collection.name for collection in client.list_collections()]
    assert collection_name not in existing_names
