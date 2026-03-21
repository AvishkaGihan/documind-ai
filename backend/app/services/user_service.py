from uuid import UUID

from sqlalchemy.ext.asyncio import AsyncSession

from app.repositories.document_repository import list_document_ids_for_user
from app.repositories.user_repository import delete_user_by_id
from app.services.document_service import DocumentDeletionError, DocumentService


class UserDeletionError(Exception):
    """Raised when account deletion fails due to external cleanup or persistence errors."""


class UserService:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def delete_account(self, *, user_id: UUID) -> None:
        document_ids = await list_document_ids_for_user(self._session, user_id=user_id)
        document_service = DocumentService(self._session)

        for document_id in document_ids:
            try:
                await document_service.delete_document_for_user(
                    user_id=user_id,
                    document_id=document_id,
                )
            except DocumentDeletionError as exc:
                await self._session.rollback()
                raise UserDeletionError from exc

        deleted_rows = await delete_user_by_id(self._session, user_id=user_id)
        if deleted_rows != 1:
            await self._session.rollback()
            raise UserDeletionError

        await self._session.commit()
