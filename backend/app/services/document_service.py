from __future__ import annotations

from pathlib import Path
from typing import TYPE_CHECKING
from uuid import UUID, uuid4

from fastapi import UploadFile
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.document import DocumentStatus
from app.repositories.conversation_repository import (
    delete_conversations_for_document,
    delete_messages_for_conversation_ids,
    list_conversation_ids_for_document,
)
from app.repositories.document_repository import (
    count_documents_for_user,
    create_document,
    delete_document_for_user,
    get_document_for_user,
    list_documents_for_user,
)
from app.schemas.documents import DocumentListResponse, DocumentPublic
from app.schemas.qa import AskQuestionResponse
from app.services.storage_service import StorageService

if TYPE_CHECKING:
    from app.services.rag_service import RagService
    from app.services.vector_service import VectorService


class FileTooLargeError(Exception):
    """Raised when an uploaded file exceeds the upload size limit."""


class InvalidFileTypeError(Exception):
    """Raised when an uploaded file is not a valid PDF."""


class DocumentNotFoundError(Exception):
    """Raised when a document does not exist or is not owned by the user."""


class DocumentDeletionError(Exception):
    """Raised when external resource cleanup fails during document deletion."""


class DocumentNotReadyError(Exception):
    """Raised when a document has not completed processing for Q&A."""


class DocumentService:
    MAX_UPLOAD_SIZE_BYTES = 50 * 1024 * 1024
    READ_CHUNK_SIZE_BYTES = 1024 * 1024
    PDF_MAGIC_BYTES = b"%PDF-"

    def __init__(
        self,
        session: AsyncSession,
        storage_service: StorageService | None = None,
        vector_service: VectorService | None = None,
    ) -> None:
        self._session = session
        self._storage_service = storage_service
        self._vector_service = vector_service

    def _get_storage_service(self) -> StorageService:
        if self._storage_service is None:
            self._storage_service = StorageService()
        return self._storage_service

    def _get_vector_service(self) -> VectorService:
        if self._vector_service is None:
            from app.services.vector_service import VectorService

            self._vector_service = VectorService()
        return self._vector_service

    async def upload_document_for_user(
        self,
        *,  
        user_id: UUID,
        upload_file: UploadFile,
    ) -> tuple[DocumentPublic, UUID]:
        file_size = await self._validate_pdf_and_get_size(upload_file)
        document_id = uuid4()

        file_path = await self._get_storage_service().upload_pdf(
            user_id=user_id,
            document_id=document_id,
            fileobj=upload_file.file,
            content_type=upload_file.content_type or "application/pdf",
        )

        document = await create_document(
            self._session,
            user_id=user_id,
            title=self._title_from_filename(upload_file.filename),
            file_path=file_path,
            file_size=file_size,
            page_count=0,
            status=DocumentStatus.PROCESSING,
        )
        return DocumentPublic.model_validate(document), document.id

    async def _validate_pdf_and_get_size(self, upload_file: UploadFile) -> int:
        await upload_file.seek(0)
        magic_bytes = await upload_file.read(len(self.PDF_MAGIC_BYTES))
        if magic_bytes != self.PDF_MAGIC_BYTES:
            raise InvalidFileTypeError

        total_size = len(magic_bytes)
        while True:
            chunk = await upload_file.read(self.READ_CHUNK_SIZE_BYTES)
            if not chunk:
                break
            total_size += len(chunk)
            if total_size > self.MAX_UPLOAD_SIZE_BYTES:
                raise FileTooLargeError

        await upload_file.seek(0)
        return total_size

    def _title_from_filename(self, filename: str | None) -> str:
        if not filename:
            return "document"
        stem = Path(filename).stem.strip()
        return stem or "document"

    async def get_document_for_user(
        self,
        *,
        user_id: UUID,
        document_id: UUID,
    ) -> DocumentPublic:
        document = await get_document_for_user(
            self._session,
            document_id=document_id,
            user_id=user_id,
        )
        if document is None:
            raise DocumentNotFoundError

        return DocumentPublic.model_validate(document)

    async def list_documents_for_user(
        self,
        *,
        user_id: UUID,
        page: int,
        page_size: int,
        search: str | None = None,
    ) -> DocumentListResponse:
        documents = await list_documents_for_user(
            self._session,
            user_id=user_id,
            page=page,
            page_size=page_size,
            search=search,
        )
        total = await count_documents_for_user(
            self._session,
            user_id=user_id,
            search=search,
        )
        return DocumentListResponse(
            items=[DocumentPublic.model_validate(document) for document in documents],
            total=total,
            page=page,
            page_size=page_size,
        )

    async def delete_document_for_user(self, *, user_id: UUID, document_id: UUID) -> None:
        document = await get_document_for_user(
            self._session,
            document_id=document_id,
            user_id=user_id,
        )
        if document is None:
            raise DocumentNotFoundError

        file_path = document.file_path

        try:
            await self._get_vector_service().delete_document_collection(
                user_id=user_id,
                document_id=document_id,
            )
            await self._get_storage_service().delete_pdf(object_key=file_path)
        except Exception as exc:  # pragma: no cover - defensive conversion boundary
            raise DocumentDeletionError from exc

        conversation_ids = await list_conversation_ids_for_document(
            self._session,
            document_id=document_id,
        )
        await delete_messages_for_conversation_ids(
            self._session,
            conversation_ids=conversation_ids,
        )
        await delete_conversations_for_document(
            self._session,
            document_id=document_id,
        )

        deleted_rows = await delete_document_for_user(
            self._session,
            document_id=document_id,
            user_id=user_id,
        )
        if deleted_rows != 1:
            await self._session.rollback()
            raise DocumentNotFoundError

        await self._session.commit()

    async def ask_question_for_document(
        self,
        *,
        user_id: UUID,
        document_id: UUID,
        question: str,
        rag_service: RagService | None = None,
    ) -> AskQuestionResponse:
        document = await get_document_for_user(
            self._session,
            document_id=document_id,
            user_id=user_id,
        )
        if document is None:
            raise DocumentNotFoundError
        if document.status != DocumentStatus.READY:
            raise DocumentNotReadyError

        if rag_service is None:
            from app.services.rag_service import RagService

            rag_service = RagService()

        active_rag_service = rag_service
        return await active_rag_service.ask_question(
            user_id=user_id,
            document_id=document_id,
            question=question,
        )
