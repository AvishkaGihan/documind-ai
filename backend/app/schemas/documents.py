from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict

from app.models.document import DocumentStatus


class DocumentPublic(BaseModel):
    id: UUID
    title: str
    file_size: int
    page_count: int
    status: DocumentStatus
    error_message: str | None
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)
