from __future__ import annotations

from collections.abc import AsyncIterator, Sequence
from typing import Any

import anyio
import structlog
from langchain_core.messages import HumanMessage, SystemMessage
from langchain_groq import ChatGroq

from app.config import get_settings
from app.services.vector_service import RetrievedChunk

logger = structlog.get_logger(__name__)


class LlmServiceError(Exception):
    """Raised when generating an LLM answer fails."""


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
    ) -> str:
        if not self._api_key:
            raise LlmServiceError("GROQ_API_KEY is required for answer generation")

        messages = [
            SystemMessage(content=system_prompt),
            HumanMessage(
                content=self._build_user_prompt(
                    question=question,
                    context_chunks=context_chunks,
                )
            ),
        ]

        attempts = self._max_retries + 1
        last_error: Exception | None = None
        for attempt in range(1, attempts + 1):
            try:
                with anyio.fail_after(self._timeout_seconds):
                    return await anyio.to_thread.run_sync(self._invoke_sync, messages)
            except Exception as exc:
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
    ) -> AsyncIterator[str]:
        if not self._api_key:
            raise LlmServiceError("GROQ_API_KEY is required for answer generation")

        messages = [
            SystemMessage(content=system_prompt),
            HumanMessage(
                content=self._build_user_prompt(
                    question=question,
                    context_chunks=context_chunks,
                )
            ),
        ]

        attempts = self._max_retries + 1
        last_error: Exception | None = None
        for attempt in range(1, attempts + 1):
            emitted_any_token = False
            try:
                with anyio.fail_after(self._timeout_seconds):
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
    def _build_user_prompt(*, question: str, context_chunks: Sequence[RetrievedChunk]) -> str:
        context_blocks = [
            f"Page {chunk.page_number}: {chunk.chunk_text}" for chunk in context_chunks
        ]
        context_text = "\n\n".join(context_blocks)
        return f"Context:\n{context_text}\n\nQuestion:\n{question}"
