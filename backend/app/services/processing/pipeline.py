from __future__ import annotations

from uuid import UUID

from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from app.database import async_session_factory
from app.models.document import DocumentStatus
from app.repositories.document_repository import (
    get_document_by_id,
    update_document_page_count,
    update_document_status,
)
from app.services.processing.chunker import Chunker
from app.services.processing.embedder import Embedder
from app.services.processing.extractor import ExtractionError, Extractor
from app.services.storage_service import StorageService
from app.services.vector_service import VectorService


async def process_document_pipeline(
    *,
    document_id: UUID,
    session_factory: async_sessionmaker[AsyncSession] = async_session_factory,
    storage_service: StorageService | None = None,
    extractor: Extractor | None = None,
    chunker: Chunker | None = None,
    embedder: Embedder | None = None,
    vector_service: VectorService | None = None,
) -> None:
    extractor = extractor or Extractor()
    chunker = chunker or Chunker()
    embedder = embedder or Embedder()
    storage = storage_service or StorageService()

    async with session_factory() as session:
        document = await get_document_by_id(session, document_id=document_id)
        if document is None:
            return

        await update_document_status(
            session,
            document_id=document_id,
            status=DocumentStatus.EXTRACTING,
            error_message=None,
        )

        try:
            pdf_bytes = await storage.download_pdf_bytes(object_key=document.file_path)
            pages = await extractor.extract_text_by_page(pdf_bytes=pdf_bytes)
            await update_document_page_count(
                session,
                document_id=document_id,
                page_count=len(pages),
            )

            await update_document_status(
                session,
                document_id=document_id,
                status=DocumentStatus.CHUNKING,
                error_message=None,
            )
            chunks = chunker.chunk_pages(document_id=document_id, pages=pages)

            await update_document_status(
                session,
                document_id=document_id,
                status=DocumentStatus.EMBEDDING,
                error_message=None,
            )
            active_vector_service = vector_service or VectorService()

            try:
                embeddings = await embedder.embed_chunks(chunks=chunks)
                await active_vector_service.upsert_chunks(
                    user_id=document.user_id,
                    document_id=document_id,
                    chunks=chunks,
                    embeddings=embeddings,
                )
            except Exception as exc:
                await _cleanup_document_vectors(
                    vector_service=active_vector_service,
                    user_id=document.user_id,
                    document_id=document_id,
                )
                await update_document_status(
                    session,
                    document_id=document_id,
                    status=DocumentStatus.ERROR,
                    error_message=f"Embedding stage failed: {exc}",
                )
                return

            await update_document_status(
                session,
                document_id=document_id,
                status=DocumentStatus.READY,
                error_message=None,
            )
        except ExtractionError as exc:
            await update_document_status(
                session,
                document_id=document_id,
                status=DocumentStatus.ERROR,
                error_message=str(exc),
            )
        except Exception:
            await update_document_status(
                session,
                document_id=document_id,
                status=DocumentStatus.ERROR,
                error_message="Document processing failed.",
            )


async def _cleanup_document_vectors(
    *,
    vector_service: VectorService,
    user_id: UUID,
    document_id: UUID,
) -> None:
    try:
        await vector_service.delete_document_collection(
            user_id=user_id,
            document_id=document_id,
        )
    except Exception:
        # Best-effort cleanup should not hide the original processing failure.
        return
