from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field

from app.models.message import MessageRole


class MessagePublic(BaseModel):
    id: UUID
    role: MessageRole
    content: str
    citations: list[dict[str, object]] = Field(default_factory=list)
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class MessageListResponse(BaseModel):
    items: list[MessagePublic]
    total: int
    page: int
    page_size: int
