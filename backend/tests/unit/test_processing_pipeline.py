import asyncio
import uuid
from uuid import UUID

from sqlalchemy import select

from app.models.document import Document, DocumentStatus
from app.models.user import User
from app.services.processing.chunker import Chunk, Chunker
from app.services.processing.embedder import Embedder
from app.services.processing.extractor import ExtractionError, Extractor
from app.services.processing.pipeline import process_document_pipeline
from app.services.storage_service import StorageService
from app.services.vector_service import VectorService


class StubChunker(Chunker):
    def chunk_pages(self, *, document_id: UUID, pages):
        return [
            Chunk(text="chunk one", page_number=1, chunk_index=0, document_id=document_id),
            Chunk(text="chunk two", page_number=1, chunk_index=1, document_id=document_id),
        ]


class StubEmbedder(Embedder):
    async def embed_chunks(self, *, chunks):
        return [[0.1, 0.2] for _ in chunks]


class RecordingVectorService(VectorService):
    def __init__(self) -> None:
        self.upsert_calls = 0
        self.cleanup_calls = 0

    async def upsert_chunks(self, *, user_id, document_id, chunks, embeddings):
        self.upsert_calls += 1

    async def delete_document_collection(self, *, user_id, document_id):
        self.cleanup_calls += 1


class FailingVectorService(RecordingVectorService):
    async def upsert_chunks(self, *, user_id, document_id, chunks, embeddings):
        self.upsert_calls += 1
        raise RuntimeError("chroma insert failed")


def test_extractor_raises_domain_error_for_invalid_pdf_bytes() -> None:
    async def _run() -> None:
        extractor = Extractor()
        try:
            await extractor.extract_text_by_page(pdf_bytes=b"not-a-pdf")
            raise AssertionError("Extractor should fail for invalid PDF bytes")
        except ExtractionError as exc:
            assert "Failed to extract text" in str(exc)

    asyncio.run(_run())


def test_pipeline_sets_error_for_invalid_pdf_bytes(test_session_factory, monkeypatch) -> None:
    async def _fake_download_pdf_bytes(self, *, object_key: str) -> bytes:
        assert object_key.endswith(".pdf")
        return b"not-a-pdf"

    monkeypatch.setattr(StorageService, "download_pdf_bytes", _fake_download_pdf_bytes)

    async def _run() -> None:
        async with test_session_factory() as session:
            user = User(email="pipeline-invalid@example.com", hashed_password="hash")
            session.add(user)
            await session.flush()
            document = Document(
                user_id=user.id,
                title="invalid",
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
        )

        async with test_session_factory() as session:
            result = await session.execute(select(Document).where(Document.id == document_id))
            updated = result.scalar_one()
            assert updated.status == DocumentStatus.ERROR
            assert updated.error_message is not None

    asyncio.run(_run())


def test_pipeline_sets_error_for_minimal_text(test_session_factory, monkeypatch) -> None:
    async def _fake_download_pdf_bytes(self, *, object_key: str) -> bytes:
        assert object_key.endswith(".pdf")
        return b"fake-pdf"

    async def _fake_extract_text_by_page(self, *, pdf_bytes: bytes):
        assert pdf_bytes == b"fake-pdf"
        raise ExtractionError("No extractable text found. This PDF may be scanned or image-only.")

    monkeypatch.setattr(StorageService, "download_pdf_bytes", _fake_download_pdf_bytes)
    monkeypatch.setattr(Extractor, "extract_text_by_page", _fake_extract_text_by_page)

    async def _run() -> None:
        async with test_session_factory() as session:
            user = User(email="pipeline-minimal@example.com", hashed_password="hash")
            session.add(user)
            await session.flush()
            document = Document(
                user_id=user.id,
                title="minimal",
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
        )

        async with test_session_factory() as session:
            result = await session.execute(select(Document).where(Document.id == document_id))
            updated = result.scalar_one()
            assert updated.status == DocumentStatus.ERROR
            assert (
                updated.error_message
                == "No extractable text found. This PDF may be scanned or image-only."
            )

    asyncio.run(_run())


def test_pipeline_sets_ready_when_embedding_and_storage_succeed(
    test_session_factory,
    monkeypatch,
) -> None:
    async def _fake_download_pdf_bytes(self, *, object_key: str) -> bytes:
        return b"fake-pdf"

    async def _fake_extract_text_by_page(self, *, pdf_bytes: bytes):
        return [
            type("PageTextLike", (), {"page_number": 1, "text": "alpha beta gamma " * 30})(),
        ]

    monkeypatch.setattr(StorageService, "download_pdf_bytes", _fake_download_pdf_bytes)
    monkeypatch.setattr(Extractor, "extract_text_by_page", _fake_extract_text_by_page)

    vector_service = RecordingVectorService()

    async def _run() -> None:
        async with test_session_factory() as session:
            user = User(email="pipeline-ready@example.com", hashed_password="hash")
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
            vector_service=vector_service,
        )

        async with test_session_factory() as session:
            result = await session.execute(select(Document).where(Document.id == document_id))
            updated = result.scalar_one()
            assert updated.status == DocumentStatus.READY
            assert updated.error_message is None

        assert vector_service.upsert_calls == 1
        assert vector_service.cleanup_calls == 0

    asyncio.run(_run())


def test_pipeline_cleans_up_vectors_when_storage_fails(test_session_factory, monkeypatch) -> None:
    async def _fake_download_pdf_bytes(self, *, object_key: str) -> bytes:
        return b"fake-pdf"

    async def _fake_extract_text_by_page(self, *, pdf_bytes: bytes):
        return [
            type("PageTextLike", (), {"page_number": 1, "text": "alpha beta gamma " * 30})(),
        ]

    monkeypatch.setattr(StorageService, "download_pdf_bytes", _fake_download_pdf_bytes)
    monkeypatch.setattr(Extractor, "extract_text_by_page", _fake_extract_text_by_page)

    vector_service = FailingVectorService()

    async def _run() -> None:
        async with test_session_factory() as session:
            user = User(email="pipeline-fail@example.com", hashed_password="hash")
            session.add(user)
            await session.flush()
            document = Document(
                user_id=user.id,
                title="fail",
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
            vector_service=vector_service,
        )

        async with test_session_factory() as session:
            result = await session.execute(select(Document).where(Document.id == document_id))
            updated = result.scalar_one()
            assert updated.status == DocumentStatus.ERROR
            assert updated.error_message is not None
            assert "chroma insert failed" in updated.error_message

        assert vector_service.upsert_calls == 1
        assert vector_service.cleanup_calls == 1

    asyncio.run(_run())
