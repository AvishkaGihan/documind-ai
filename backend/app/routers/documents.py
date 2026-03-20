import asyncio
from collections.abc import AsyncIterator
from typing import Annotated
from uuid import UUID

from fastapi import (
    APIRouter,
    BackgroundTasks,
    Depends,
    File,
    HTTPException,
    Query,
    Request,
    Response,
    UploadFile,
    status,
)
from fastapi.responses import StreamingResponse
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import get_settings
from app.core.sse import format_sse_event
from app.database import get_async_session
from app.dependencies.auth import CurrentUser
from app.routers.errors import build_error_detail
from app.schemas.conversations import CreateConversationResponse
from app.schemas.documents import DocumentListResponse, DocumentPublic
from app.schemas.messages import MessageListResponse, MessagePublic
from app.schemas.qa import AskQuestionRequest, AskQuestionResponse
from app.services.conversation_service import ConversationNotFoundError, ConversationService
from app.services.document_service import (
    DocumentDeletionError,
    DocumentNotFoundError,
    DocumentNotReadyError,
    DocumentService,
    FileTooLargeError,
    InvalidFileTypeError,
)
from app.services.processing.pipeline import process_document_pipeline
from app.services.rag_service import RagService, RagServiceError

router = APIRouter()
async_session_dependency = Depends(get_async_session)
settings = get_settings()


@router.post("/upload", response_model=DocumentPublic, status_code=status.HTTP_201_CREATED)
async def upload_document(
    current_user: CurrentUser,
    background_tasks: BackgroundTasks,
    file: Annotated[UploadFile, File(...)],
    session: AsyncSession = async_session_dependency,
) -> DocumentPublic:
    service = DocumentService(session)

    try:
        document, document_id = await service.upload_document_for_user(
            user_id=current_user.id,
            upload_file=file,
        )
        background_tasks.add_task(process_document_pipeline, document_id=document_id)
        return document
    except InvalidFileTypeError as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail=build_error_detail(
                code="INVALID_FILE_TYPE",
                message="Only PDF files are supported",
            ),
        ) from exc
    except FileTooLargeError as exc:
        raise HTTPException(
            status_code=status.HTTP_413_CONTENT_TOO_LARGE,
            detail=build_error_detail(
                code="FILE_TOO_LARGE",
                message="Uploaded file exceeds the 50 MB limit",
            ),
        ) from exc


@router.get("", response_model=DocumentListResponse)
async def list_documents(
    current_user: CurrentUser,
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1),
    search: str | None = Query(default=None),
    session: AsyncSession = async_session_dependency,
) -> DocumentListResponse:
    service = DocumentService(session)
    return await service.list_documents_for_user(
        user_id=current_user.id,
        page=page,
        page_size=page_size,
        search=search,
    )


@router.get("/{document_id}", response_model=DocumentPublic)
async def get_document(
    document_id: UUID,
    current_user: CurrentUser,
    session: AsyncSession = async_session_dependency,
) -> DocumentPublic:
    service = DocumentService(session)

    try:
        return await service.get_document_for_user(
            user_id=current_user.id,
            document_id=document_id,
        )
    except DocumentNotFoundError as exc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=build_error_detail(
                code="DOCUMENT_NOT_FOUND",
                message="Document not found.",
            ),
        ) from exc


@router.delete("/{document_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_document(
    document_id: UUID,
    current_user: CurrentUser,
    session: AsyncSession = async_session_dependency,
) -> Response:
    service = DocumentService(session)

    try:
        await service.delete_document_for_user(
            user_id=current_user.id,
            document_id=document_id,
        )
        return Response(status_code=status.HTTP_204_NO_CONTENT)
    except DocumentNotFoundError as exc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=build_error_detail(
                code="DOCUMENT_NOT_FOUND",
                message="Document not found.",
            ),
        ) from exc
    except DocumentDeletionError as exc:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=build_error_detail(
                code="DOCUMENT_DELETION_FAILED",
                message="Failed to delete document resources.",
            ),
        ) from exc


@router.post("/{document_id}/ask", response_model=AskQuestionResponse)
async def ask_document_question(
    document_id: UUID,
    payload: AskQuestionRequest,
    request: Request,
    current_user: CurrentUser,
    session: AsyncSession = async_session_dependency,
) -> AskQuestionResponse | StreamingResponse:
    service = DocumentService(session)
    conversation_service = ConversationService(session)
    rag_service = RagService()
    is_streaming_request = "text/event-stream" in request.headers.get("accept", "").lower()

    try:
        await service.ensure_document_ready_for_question(
            user_id=current_user.id,
            document_id=document_id,
        )
        prompt_history = await conversation_service.get_prompt_history(
            user_id=current_user.id,
            document_id=document_id,
            max_messages=settings.rag_max_history_messages,
        )

        if is_streaming_request:
            async def _stream_events() -> AsyncIterator[str]:
                answer_parts: list[str] = []
                citations: list[dict[str, object]] = []
                emitted_citation_pages: set[int] = set()
                saw_error = False

                async for event_name, event_payload in rag_service.stream_answer_events(
                    user_id=current_user.id,
                    document_id=document_id,
                    question=payload.question,
                    conversation_history=prompt_history,
                ):
                    if event_name == "token":
                        token = str(event_payload.get("content", ""))
                        answer_parts.append(token)
                    elif event_name == "citation":
                        page = int(event_payload.get("page", 0))
                        text = str(event_payload.get("text", ""))
                        if page > 0 and text and page not in emitted_citation_pages:
                            citations.append({"page_number": page, "text": text})
                            emitted_citation_pages.add(page)
                    elif event_name == "error":
                        saw_error = True

                    yield format_sse_event(event_name, event_payload)
                    await asyncio.sleep(0)

                    if event_name == "error":
                        return

                if not saw_error:
                    assistant_message_id = await conversation_service.persist_qa_exchange(
                        user_id=current_user.id,
                        document_id=document_id,
                        question=payload.question,
                        answer_text="".join(answer_parts).strip(),
                        citations=citations,
                    )
                    yield format_sse_event("done", {"message_id": str(assistant_message_id)})

            return StreamingResponse(
                _stream_events(),
                media_type="text/event-stream",
                headers={
                    "Cache-Control": "no-cache",
                    "Connection": "keep-alive",
                    "X-Accel-Buffering": "no",
                },
            )

        response = await rag_service.ask_question(
            user_id=current_user.id,
            document_id=document_id,
            question=payload.question,
            conversation_history=prompt_history,
        )
        citations = [citation.model_dump() for citation in response.citations]
        await conversation_service.persist_qa_exchange(
            user_id=current_user.id,
            document_id=document_id,
            question=payload.question,
            answer_text=response.answer,
            citations=citations,
        )
        return response
    except DocumentNotFoundError as exc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=build_error_detail(
                code="DOCUMENT_NOT_FOUND",
                message="Document not found.",
            ),
        ) from exc
    except DocumentNotReadyError as exc:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=build_error_detail(
                code="DOCUMENT_NOT_READY",
                message="Document is still processing. Try again when status is ready.",
            ),
        ) from exc
    except RagServiceError as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=build_error_detail(
                code="ANSWER_GENERATION_FAILED",
                message="Unable to generate an answer at the moment.",
            ),
        ) from exc


@router.post(
    "/{document_id}/conversations/new",
    response_model=CreateConversationResponse,
    status_code=status.HTTP_201_CREATED,
)
async def create_new_conversation(
    document_id: UUID,
    current_user: CurrentUser,
    session: AsyncSession = async_session_dependency,
) -> CreateConversationResponse:
    document_service = DocumentService(session)
    conversation_service = ConversationService(session)

    try:
        await document_service.get_document_for_user(
            user_id=current_user.id,
            document_id=document_id,
        )
        conversation_id = await conversation_service.create_new_conversation(
            user_id=current_user.id,
            document_id=document_id,
        )
        return CreateConversationResponse(conversation_id=conversation_id)
    except DocumentNotFoundError as exc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=build_error_detail(
                code="DOCUMENT_NOT_FOUND",
                message="Document not found.",
            ),
        ) from exc


@router.get(
    "/{document_id}/conversations/{conversation_id}/messages",
    response_model=MessageListResponse,
)
async def list_conversation_messages(
    document_id: UUID,
    conversation_id: UUID,
    current_user: CurrentUser,
    session: AsyncSession = async_session_dependency,
) -> MessageListResponse:
    document_service = DocumentService(session)
    conversation_service = ConversationService(session)

    try:
        await document_service.get_document_for_user(
            user_id=current_user.id,
            document_id=document_id,
        )
        messages = await conversation_service.list_messages_for_conversation(
            user_id=current_user.id,
            document_id=document_id,
            conversation_id=conversation_id,
        )
    except DocumentNotFoundError as exc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=build_error_detail(
                code="DOCUMENT_NOT_FOUND",
                message="Document not found.",
            ),
        ) from exc
    except ConversationNotFoundError as exc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=build_error_detail(
                code="CONVERSATION_NOT_FOUND",
                message="Conversation not found.",
            ),
        ) from exc

    items = [MessagePublic.model_validate(message) for message in messages]
    return MessageListResponse(
        items=items,
        total=len(items),
        page=1,
        page_size=len(items),
    )
