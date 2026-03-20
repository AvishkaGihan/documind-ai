# Story 5.2: Streaming Answer Endpoint with SSE

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a user,
I want to see the answer appear progressively as it's being generated,
so that I get faster perceived response times and an engaging experience.

## Acceptance Criteria

1. **Given** I send a question to `/api/v1/documents/{document_id}/ask` with `Accept: text/event-stream` header
   **When** the LLM generates the answer
   **Then** the response is an SSE stream with events:
     - `event: token` / `data: {"content": "partial text"}` — for each generated token
     - `event: citation` / `data: {"page": 4, "text": "relevant chunk text"}` — when a citation is referenced
     - `event: done` / `data: {"message_id": "uuid"}` — when generation is complete

2. **Given** the Groq API is unavailable or rate-limited
   **When** the LLM call fails
   **Then** an `event: error` / `data: {"code": "LLM_UNAVAILABLE", "message": "..."}` is sent and the stream ends

3. **And** a conversation record and message records (user question + assistant answer) are created/updated upon stream completion

## Tasks / Subtasks

- [x] Add an SSE streaming path to the existing `/ask` endpoint (AC: 1–2)
  - [x] Update `backend/app/routers/documents.py` to detect streaming via `Accept: text/event-stream`
    - [x] Keep existing JSON behavior for non-streaming clients (no regression to Story 5.1)
    - [x] If streaming is requested, return a `StreamingResponse` with media type `text/event-stream`
    - [x] Recommended headers for proxy friendliness: `Cache-Control: no-cache`, `Connection: keep-alive`, `X-Accel-Buffering: no`
    - [x] Keep existing auth + ownership + `DocumentStatus.READY` checks
      - [x] Not found / not ready should remain normal HTTP errors (404/409 JSON error response) because they occur before streaming begins

- [x] Implement SSE event formatting and cancellation-safe streaming generator (AC: 1–2)
  - [x] Add a small helper to format SSE frames (avoid ad-hoc string building scattered across services)
    - [x] Suggested location: `backend/app/core/sse.py` (or `backend/app/utils/sse.py` if `core/` is not used)
    - [x] Must output exactly:
      - [x] `event: <name>\n`
      - [x] `data: <json>\n\n`
  - [x] Ensure cancellation is handled (client disconnect) by having the generator hit an `await` regularly (FastAPI/Starlette cancellation model)

- [x] Extend `LlmService` to support streaming tokens from Groq (AC: 1–2)
  - [x] Update `backend/app/services/llm_service.py` (and only this file) to expose a streaming API, e.g.:
    - [x] `stream_answer(...) -> AsyncIterator[str]` yielding token strings (or small text deltas)
  - [x] Use the existing LangChain `ChatGroq` client (no direct Groq HTTP calls elsewhere)
  - [x] Keep timeouts/retries consistent with `generate_answer` behavior
  - [x] Ensure the streaming path raises a single domain exception type (`LlmServiceError`) so upstream can map it to SSE `error`

- [x] Extend `RagService` to orchestrate streaming and citation events (AC: 1–2)
  - [x] Add a streaming method in `backend/app/services/rag_service.py`, e.g.:
    - [x] `stream_answer_events(user_id, document_id, question, ...) -> AsyncIterator[tuple[event_name, payload_dict]]`
  - [x] Reuse existing logic from `ask_question` to prevent wheel reinvention:
    - [x] `Embedder.embed_texts` for query embedding
    - [x] `VectorService.query_chunks` for retrieval
    - [x] Similarity threshold handling + fallback message behavior
    - [x] Deterministic citation list derived from retrieved chunks (do not invent pages)
  - [x] Token events:
    - [x] Yield `token` events as soon as deltas are produced by the LLM
    - [x] Accumulate deltas into a final `answer_text` for persistence
  - [x] Citation events (“when referenced”):
    - [x] Keep this deterministic and implementable without fragile LLM parsing
    - [x] Recommended strategy:
      - [x] In the system prompt, keep the required phrasing “According to page X...” (already required)
      - [x] While streaming, maintain a small rolling buffer of the generated text and regex-detect first occurrences of `page <number>`
      - [x] When a new page number is detected, and it exists in the retrieved citations set, emit a `citation` SSE event with that page + excerpt
      - [x] De-duplicate citations per page (emit once per page)
    - [x] Do not block token streaming waiting on citation detection
  - [x] Error events:
    - [x] If `LlmServiceError` occurs, yield `error` with `{code: "LLM_UNAVAILABLE", message: <safe message>}` then stop

- [x] Persist conversation + messages on successful stream completion (AC: 3)
  - [x] Implement repository methods (do not write SQL in routers):
    - [x] Extend `backend/app/repositories/conversation_repository.py` with:
      - [x] `get_latest_conversation_for_document(session, *, user_id, document_id) -> Conversation | None`
      - [x] `create_conversation(session, *, user_id, document_id) -> Conversation`
      - [x] `touch_conversation(session, *, conversation_id) -> None` (optional; ensures `updated_at` advances)
    - [x] Add a new `backend/app/repositories/message_repository.py` with:
      - [x] `create_message(session, *, conversation_id, role, content, citations) -> Message`
  - [x] Implement a small service orchestrator (preferred) rather than stuffing persistence into the router:
    - [x] Suggested: `backend/app/services/conversation_service.py`
    - [x] Responsibilities:
      - [x] Resolve conversation (use latest for `{user_id, document_id}`; create if none)
      - [x] On completion, insert two messages:
        - [x] user message: role `user`, content = question, citations = []
        - [x] assistant message: role `assistant`, content = final answer text, citations = structured citations
      - [x] Commit once at the end, and return assistant `message_id` for the `done` event
  - [x] Ensure persistence happens only after successful completion (don’t create partial assistant messages if the stream errors)

- [x] Testing (AC: 1–3)
  - [x] Unit tests for streaming orchestration without external services
    - [x] Suggested: `backend/tests/unit/test_rag_service_streaming.py`
    - [x] Stub `LlmService.stream_answer` to yield deterministic token chunks
    - [x] Verify:
      - [x] token events are emitted in order
      - [x] citation events are emitted once per referenced page
      - [x] error event emitted on `LlmServiceError`
  - [x] Integration tests for SSE endpoint
    - [x] Suggested: `backend/tests/integration/test_documents_ask_streaming.py`
    - [x] Use the existing authenticated client fixture patterns
    - [x] Request with `Accept: text/event-stream`
    - [x] Collect streamed bytes and parse SSE frames
    - [x] Verify:
      - [x] at least one `token` event is present
      - [x] ends with `done` containing a UUID `message_id`
      - [x] DB contains a conversation and two messages after completion
      - [x] Error case: simulate LLM failure and assert `error` event with `LLM_UNAVAILABLE`

## Dev Notes

### Developer context (read this first)

This story upgrades the existing Q&A endpoint (`POST /api/v1/documents/{document_id}/ask`) to support **Server-Sent Events** when the client requests `text/event-stream`.

**Must preserve existing behavior:** The JSON response used in Story 5.1 remains the default for clients that do not request streaming.

**Also introduces minimal persistence:** create/update the **Conversation** + **Message** records only after a stream completes successfully. This is foundational for Story 5.3 (conversation memory) and Story 5.4 (Flutter chat UI), but do not implement the new conversation endpoints yet (those are Story 5.3).

### What already exists (reuse; do not reinvent)

- Existing JSON Q&A endpoint:
  - `backend/app/routers/documents.py` → `ask_document_question`
- RAG pipeline components:
  - `backend/app/services/rag_service.py` (retrieval, thresholding, deterministic citations)
  - `backend/app/services/vector_service.py` (Chroma queries)
  - `backend/app/services/processing/embedder.py` (Sentence Transformer model loading)
  - `backend/app/services/llm_service.py` (Groq gateway boundary)
- DB models already present for persistence:
  - `backend/app/models/conversation.py`
  - `backend/app/models/message.py` (includes JSON `citations`)
- Existing repo function(s):
  - `backend/app/repositories/conversation_repository.py` currently supports deletion/list IDs (extend this file rather than creating a second conversation repo)

### Architectural guardrails (must follow)

- **External service boundaries** (security + testability):
  - Only `LlmService` talks to Groq/LangChain
  - Only `VectorService` talks to ChromaDB
  - Only `Embedder` loads/uses Sentence Transformers
- **Layering:** routers → services → repositories (no SQL in routers)
- **Async discipline:** streaming generator must be cancellation-safe (hit an `await` periodically)
- **Data isolation:** never allow cross-user access (document ownership must be enforced before starting the stream)

### SSE format requirements (do not improvise)

Use the architecture-defined format:

```
event: token
data: {"content": "According to"}

event: token
data: {"content": " page 4, the"}

event: citation
data: {"page": 4, "text": "Relevant chunk text..."}

event: done
data: {"message_id": "uuid"}
```

Notes:
- Use JSON for all `data:` payloads.
- Do not emit extra event types.
- Emit `error` only when the LLM call fails (Groq unavailable/rate limited).

### Scope boundaries (avoid scope creep)

Explicitly out of scope for Story 5.2:
- Conversation memory / prompt-history truncation (Story 5.3)
- New endpoints `/conversations/new` or `/messages` (Story 5.3)
- Flutter streaming UI (Story 5.4)
- WebSockets (SSE is the chosen MVP transport)

### Project Structure Notes

Expected files to touch/create (names are suggestions; follow existing patterns in the repo):
- `backend/app/routers/documents.py` (extend `/ask` with SSE path)
- `backend/app/services/llm_service.py` (add token streaming support)
- `backend/app/services/rag_service.py` (add streaming orchestration)
- `backend/app/repositories/conversation_repository.py` (add create/get helpers)
- `backend/app/repositories/message_repository.py` (new)
- `backend/app/services/conversation_service.py` (new)
- `backend/tests/unit/test_rag_service_streaming.py` (new)
- `backend/tests/integration/test_documents_ask_streaming.py` (new)

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story-5.2:-Streaming-Answer-Endpoint-with-SSE]
- [Source: _bmad-output/planning-artifacts/architecture.md#API-Response-Formats] (SSE format)
- [Source: _bmad-output/project-context.md#API-Response-Formats-(MUST-follow-exactly)] (SSE + error shape rules)
- [Source: _bmad-output/implementation-artifacts/5-1-rag-pipeline-semantic-retrieval-and-answer-generation-api.md] (patterns, boundaries, tests)
- [Source: https://fastapi.tiangolo.com/advanced/custom-response/#streamingresponse] (StreamingResponse cancellation note)
- [Source: https://docs.langchain.com/oss/python/integrations/chat/groq] (ChatGroq integration)

## Dev Agent Record

### Agent Model Used

GPT-5.3-Codex (GitHub Copilot)

### Debug Log References

- Added red-phase tests and confirmed failures:
  - `.venv/bin/python -m pytest tests/unit/test_rag_service_streaming.py tests/integration/test_documents_ask_streaming.py -q`
- Implemented SSE streaming, RAG/LLM streaming, and conversation persistence.
- Validation runs:
  - `.venv/bin/python -m pytest -q`
  - `.venv/bin/python -m ruff check app tests`

### Completion Notes List

- Added SSE branch to `POST /api/v1/documents/{document_id}/ask` that activates on `Accept: text/event-stream` while preserving JSON behavior for non-streaming clients.
- Added shared SSE frame formatter at `backend/app/core/sse.py` and proxy-friendly streaming headers.
- Extended `LlmService` with `stream_answer(...)` using existing `ChatGroq`, timeout/retry logic, and cancellation points.
- Extended `RagService` with `stream_answer_events(...)` for token/citation/error events and deterministic citation emission by page references in streamed text.
- Added `DocumentService.ensure_document_ready_for_question(...)` to preserve pre-stream ownership/readiness checks (404/409 JSON errors).
- Added conversation/message persistence pipeline for successful streams with `ConversationService` + repository helpers, including returning assistant `message_id` for the `done` event.
- Added unit and integration tests for streaming behavior, error event behavior, and persistence verification.
- Full backend regression and lint checks pass.

### File List

- backend/app/core/sse.py
- backend/app/routers/documents.py
- backend/app/services/document_service.py
- backend/app/services/llm_service.py
- backend/app/services/rag_service.py
- backend/app/services/conversation_service.py
- backend/app/repositories/conversation_repository.py
- backend/app/repositories/message_repository.py
- backend/tests/unit/test_rag_service_streaming.py
- backend/tests/integration/test_documents_ask_streaming.py

### Change Log

- 2026-03-20: Implemented Story 5.2 SSE streaming endpoint, added streaming RAG/LLM orchestration, added conversation/message persistence on successful completion, and added unit/integration tests.
