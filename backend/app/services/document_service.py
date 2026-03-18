from pathlib import Path
from uuid import UUID, uuid4

from fastapi import UploadFile
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.document import DocumentStatus
from app.repositories.document_repository import create_document
from app.schemas.documents import DocumentPublic
from app.services.storage_service import StorageService


class FileTooLargeError(Exception):
    """Raised when an uploaded file exceeds the upload size limit."""


class InvalidFileTypeError(Exception):
    """Raised when an uploaded file is not a valid PDF."""


class DocumentService:
    MAX_UPLOAD_SIZE_BYTES = 50 * 1024 * 1024
    READ_CHUNK_SIZE_BYTES = 1024 * 1024
    PDF_MAGIC_BYTES = b"%PDF-"

    def __init__(
        self,
        session: AsyncSession,
        storage_service: StorageService | None = None,
    ) -> None:
        self._session = session
        self._storage_service = storage_service or StorageService()

    async def upload_document_for_user(
        self,
        *,  
        user_id: UUID,
        upload_file: UploadFile,
    ) -> tuple[DocumentPublic, UUID]:
        file_size = await self._validate_pdf_and_get_size(upload_file)
        document_id = uuid4()

        file_path = await self._storage_service.upload_pdf(
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
