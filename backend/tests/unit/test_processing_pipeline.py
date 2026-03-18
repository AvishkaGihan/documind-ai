import asyncio
import uuid

from sqlalchemy import select

from app.models.document import Document, DocumentStatus
from app.models.user import User
from app.services.processing.extractor import ExtractionError, Extractor
from app.services.processing.pipeline import process_document_pipeline
from app.services.storage_service import StorageService


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
