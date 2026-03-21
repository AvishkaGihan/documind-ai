from __future__ import annotations

from collections.abc import AsyncIterator, Sequence
from typing import Any

import anyio
import structlog
from langchain_core.messages import AIMessage, BaseMessage, HumanMessage, SystemMessage
from langchain_groq import ChatGroq

from app.config import get_settings
from app.services.vector_service import RetrievedChunk

logger = structlog.get_logger(__name__)


class LlmServiceError(Exception):
    """Raised when generating an LLM answer fails."""


class LlmRateLimitError(LlmServiceError):
    """Raised when the upstream LLM provider responds with rate limiting."""

    def __init__(self, *, retry_after_seconds: int | None = None) -> None:
        super().__init__("LLM provider rate limit reached")
        self.retry_after_seconds = retry_after_seconds


class LlmService:
    def __init__(
        self,
        *,
        model_name: str | None = None,
        api_key: str | None = None,
        timeout_seconds: int | None = None,
        max_retries: int | None = None,
        client: Any | None = None,
    ) -> None:
        settings = get_settings()
        self._model_name = model_name or settings.groq_model_name
        self._api_key = api_key if api_key is not None else settings.groq_api_key
        self._timeout_seconds = timeout_seconds or settings.groq_timeout_seconds
        self._max_retries = max_retries if max_retries is not None else settings.groq_max_retries
        self._client = client

    async def generate_answer(
        self,
        *,
        question: str,
        context_chunks: Sequence[RetrievedChunk],
        system_prompt: str,
        conversation_history: Sequence[Any] | None = None,
    ) -> str:
        if not self._api_key:
            raise LlmServiceError("GROQ_API_KEY is required for answer generation")

        messages = self._build_messages(
            question=question,
            context_chunks=context_chunks,
            system_prompt=system_prompt,
            conversation_history=conversation_history,
            max_history_messages=get_settings().rag_max_history_messages,
        )

        attempts = self._max_retries + 1
        last_error: Exception | None = None
        for attempt in range(1, attempts + 1):
            try:
                with anyio.fail_after(self._timeout_seconds):
                    return await anyio.to_thread.run_sync(self._invoke_sync, messages)
            except Exception as exc:
                if self._is_rate_limit_error(exc):
                    raise LlmRateLimitError(
                        retry_after_seconds=self._extract_retry_after_seconds(exc)
                    ) from exc
                last_error = exc
                logger.warning(
                    "groq_generation_failed",
                    model_name=self._model_name,
                    attempt=attempt,
                    max_attempts=attempts,
                    error=str(exc),
                )
                if attempt < attempts:
                    await anyio.sleep(0.2)

        raise LlmServiceError("Failed to generate answer from Groq") from last_error

    async def stream_answer(
        self,
        *,
        question: str,
        context_chunks: Sequence[RetrievedChunk],
        system_prompt: str,
        conversation_history: Sequence[Any] | None = None,
    ) -> AsyncIterator[str]:
        if not self._api_key:
            raise LlmServiceError("GROQ_API_KEY is required for answer generation")

        messages = self._build_messages(
            question=question,
            context_chunks=context_chunks,
            system_prompt=system_prompt,
            conversation_history=conversation_history,
            max_history_messages=get_settings().rag_max_history_messages,
        )

        attempts = self._max_retries + 1
        last_error: Exception | None = None
        for attempt in range(1, attempts + 1):
            emitted_any_token = False
            try:
                # NOTE: Do NOT wrap this in anyio.fail_after() – the cancel
                # scope must be entered and exited in the *same* async task,
                # but FastAPI's StreamingResponse consumes this generator in a
                # different task, causing "Attempted to exit cancel scope in a
                # different task than it was entered in".  The ChatGroq client
                # already enforces its own timeout via the ``timeout`` param.
                async for chunk in self._get_client().astream(messages):
                    token = self._chunk_to_text(chunk)
                    if not token:
                        continue
                    emitted_any_token = True
                    yield token
                    # Ensure a regular cancellation point for disconnected clients.
                    await anyio.sleep(0)
                return
            except Exception as exc:
                if self._is_rate_limit_error(exc):
                    raise LlmRateLimitError(
                        retry_after_seconds=self._extract_retry_after_seconds(exc)
                    ) from exc
                last_error = exc
                logger.warning(
                    "groq_stream_failed",
                    model_name=self._model_name,
                    attempt=attempt,
                    max_attempts=attempts,
                    emitted_any_token=emitted_any_token,
                    error=str(exc),
                )
                if emitted_any_token or attempt >= attempts:
                    break
                await anyio.sleep(0.2)

        raise LlmServiceError("Failed to stream answer from Groq") from last_error

    def _invoke_sync(self, messages: list[Any]) -> str:
        response = self._get_client().invoke(messages)
        content = getattr(response, "content", "")
        if isinstance(content, str):
            return content.strip()
        if isinstance(content, list):
            parts = [item.get("text", "") for item in content if isinstance(item, dict)]
            return "".join(parts).strip()
        return str(content).strip()

    def _get_client(self) -> Any:
        if self._client is None:
            self._client = ChatGroq(
                api_key=self._api_key,
                model=self._model_name,
                max_retries=0,
                timeout=self._timeout_seconds,
            )
        return self._client

    @staticmethod
    def _chunk_to_text(chunk: Any) -> str:
        content = getattr(chunk, "content", "")
        if isinstance(content, str):
            return content
        if isinstance(content, list):
            parts = [item.get("text", "") for item in content if isinstance(item, dict)]
            return "".join(parts)
        return str(content or "")

    @staticmethod
    def _is_rate_limit_error(error: Exception) -> bool:
        status_code = getattr(error, "status_code", None)
        if status_code == 429:
            return True

        response = getattr(error, "response", None)
        if response is not None and getattr(response, "status_code", None) == 429:
            return True

        text = str(error).lower()
        return "429" in text or "rate limit" in text or "too many requests" in text

    @staticmethod
    def _extract_retry_after_seconds(error: Exception) -> int | None:
        candidates: list[Any] = []
        response = getattr(error, "response", None)
        if response is not None:
            headers = getattr(response, "headers", None)
            if headers is not None:
                candidates.append(headers.get("retry-after"))
                candidates.append(headers.get("Retry-After"))
        headers = getattr(error, "headers", None)
        if headers is not None:
            candidates.append(headers.get("retry-after"))
            candidates.append(headers.get("Retry-After"))

        for value in candidates:
            if value is None:
                continue
            try:
                parsed = int(str(value).strip())
                if parsed > 0:
                    return parsed
            except ValueError:
                continue

        return None

    @staticmethod
    def _build_user_prompt(*, question: str, context_chunks: Sequence[RetrievedChunk]) -> str:
        context_blocks = [
            f"Page {chunk.page_number}: {chunk.chunk_text}" for chunk in context_chunks
        ]
        context_text = "\n\n".join(context_blocks)
        return f"Context:\n{context_text}\n\nQuestion:\n{question}"

    def _build_messages(
        self,
        *,
        question: str,
        context_chunks: Sequence[RetrievedChunk],
        system_prompt: str,
        conversation_history: Sequence[Any] | None,
        max_history_messages: int,
    ) -> list[BaseMessage]:
        history_messages = self._coerce_history_messages(conversation_history)
        bounded_history = history_messages[-max(0, max_history_messages) :]

        return [
            SystemMessage(content=system_prompt),
            *bounded_history,
            HumanMessage(
                content=self._build_user_prompt(
                    question=question,
                    context_chunks=context_chunks,
                )
            ),
        ]

    @staticmethod
    def _coerce_history_messages(conversation_history: Sequence[Any] | None) -> list[BaseMessage]:
        if not conversation_history:
            return []

        messages: list[BaseMessage] = []
        for item in conversation_history:
            role = getattr(item, "role", None)
            content = getattr(item, "content", None)
            if role is None and isinstance(item, dict):
                role = item.get("role")
                content = item.get("content")

            role_text = str(role or "").strip().lower()
            content_text = str(content or "").strip()
            if not content_text:
                continue
            if role_text == "user":
                messages.append(HumanMessage(content=content_text))
            elif role_text == "assistant":
                messages.append(AIMessage(content=content_text))
        return messages
