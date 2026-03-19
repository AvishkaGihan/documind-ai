from typing import BinaryIO
from uuid import UUID

import anyio
import boto3
from botocore.exceptions import ClientError

from app.config import get_settings


class StorageServiceError(Exception):
    """Raised when storage operations fail."""


class StorageService:
    def __init__(self) -> None:
        settings = get_settings()
        self._bucket_name = settings.s3_bucket_name
        self._client = boto3.client(
            "s3",
            aws_access_key_id=settings.aws_access_key_id,
            aws_secret_access_key=settings.aws_secret_access_key,
            region_name=settings.aws_region,
        )

    async def upload_pdf(
        self,
        *,
        user_id: UUID,
        document_id: UUID,
        fileobj: BinaryIO,
        content_type: str,
    ) -> str:
        object_key = f"users/{user_id}/documents/{document_id}.pdf"
        await anyio.to_thread.run_sync(
            self._upload_fileobj,
            fileobj,
            object_key,
            content_type,
        )
        return object_key

    async def download_pdf_bytes(self, *, object_key: str) -> bytes:
        return await anyio.to_thread.run_sync(self._download_pdf_bytes, object_key)

    async def delete_pdf(self, *, object_key: str) -> None:
        try:
            await anyio.to_thread.run_sync(self._delete_pdf_sync, object_key)
        except Exception as exc:  # pragma: no cover - defensive conversion boundary
            raise StorageServiceError(f"Failed to delete PDF from storage: {exc}") from exc

    def _upload_fileobj(self, fileobj: BinaryIO, object_key: str, content_type: str) -> None:
        fileobj.seek(0)
        self._client.upload_fileobj(
            fileobj,
            self._bucket_name,
            object_key,
            ExtraArgs={"ContentType": content_type or "application/pdf"},
        )

    def _download_pdf_bytes(self, object_key: str) -> bytes:
        response = self._client.get_object(Bucket=self._bucket_name, Key=object_key)
        body = response["Body"]
        return body.read()

    def _delete_pdf_sync(self, object_key: str) -> None:
        try:
            self._client.delete_object(Bucket=self._bucket_name, Key=object_key)
        except ClientError as exc:
            error_code = str(exc.response.get("Error", {}).get("Code", ""))
            if error_code in {"NoSuchKey", "404", "NotFound"}:
                return
            raise
