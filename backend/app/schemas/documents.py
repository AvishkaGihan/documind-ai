from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict

from app.models.document import DocumentStatus


class DocumentPublic(BaseModel):
    id: UUID
    title: str
    status: DocumentStatus
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)
