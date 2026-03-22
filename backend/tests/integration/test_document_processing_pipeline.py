import asyncio
import uuid
from uuid import UUID

from sqlalchemy import select

from app.models.document import Document, DocumentStatus
from app.models.user import User
from app.services.processing.chunker import Chunk, Chunker
from app.services.processing.embedder import Embedder
from app.services.processing.extractor import Extractor, PageText
from app.services.processing.pipeline import process_document_pipeline
from app.services.storage_service import StorageService
from app.services.vector_service import VectorService


class StubChunker(Chunker):
    def chunk_pages(self, *, document_id: UUID, pages: list[PageText]) -> list[Chunk]:
        return [
            Chunk(text="first", page_number=1, chunk_index=0, document_id=document_id),
            Chunk(text="second", page_number=2, chunk_index=0, document_id=document_id),
        ]


class StubEmbedder(Embedder):
    async def embed_chunks(self, *, chunks: list[Chunk]) -> list[list[float]]:
        return [[0.1, 0.2] for _ in chunks]


class StubVectorService(VectorService):
    async def upsert_chunks(self, *, user_id, document_id, chunks, embeddings) -> None:
        return

    async def delete_document_collection(self, *, user_id, document_id) -> None:
        return


def test_processing_pipeline_sets_ready_status_and_page_count(
    test_session_factory,
    monkeypatch,
) -> None:
    async def _fake_download_pdf_bytes(self, *, object_key: str) -> bytes:
        assert object_key.endswith(".pdf")
        return b"synthetic-pdf"

    async def _fake_extract_text_by_page(self, *, pdf_bytes: bytes) -> list[PageText]:
        assert pdf_bytes == b"synthetic-pdf"
        text = " ".join(f"token{i}" for i in range(640))
        return [PageText(page_number=1, text=text), PageText(page_number=2, text=text)]

    monkeypatch.setattr(StorageService, "download_pdf_bytes", _fake_download_pdf_bytes)
    monkeypatch.setattr(Extractor, "extract_text_by_page", _fake_extract_text_by_page)

    async def _run() -> None:
        async with test_session_factory() as session:
            user = User(email="pipeline-success@example.com", hashed_password="hash")
            session.add(user)
            await session.flush()
            document = Document(
                user_id=user.id,
                title="ready",
                file_path=f"users/{user.id}/documents/{uuid.uuid4()}.pdf",
                file_size=100,
                page_count=0,
                status=DocumentStatus.PROCESSING,
            )
            session.add(document)
            await session.commit()
            document_id = document.id

        await process_document_pipeline(
            document_id=document_id,
            session_factory=test_session_factory,
            chunker=StubChunker(),
            embedder=StubEmbedder(model=object()),
            vector_service=StubVectorService(client=object()),
        )

        async with test_session_factory() as session:
            result = await session.execute(select(Document).where(Document.id == document_id))
            updated = result.scalar_one()
            assert updated.page_count == 2
            assert updated.status == DocumentStatus.READY
            assert updated.error_message is None

    asyncio.run(_run())
