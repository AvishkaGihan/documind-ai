# Story 5.3: Conversation Memory and Context Management

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a user,
I want my follow-up questions to understand the context of my previous questions,
so that I can have natural, multi-turn conversations with my documents.

## Acceptance Criteria

1. **Given** I have an active conversation with a document
   **When** I ask a follow-up question
   **Then** the previous conversation history (up to the context window limit) is included in the LLM prompt alongside the new question and retrieved chunks
   **And** the answer correctly references prior conversation context

2. **Given** the conversation history exceeds the LLM context window
   **When** a new question is asked
   **Then** the system truncates older messages while preserving the system prompt and the most recent N messages

3. **Given** I want to start fresh with the same document
   **When** I send a POST request to `/api/v1/documents/{document_id}/conversations/new`
   **Then** a new conversation is created, previous context is cleared, and the new conversation ID is returned

4. **Given** I want to view my conversation history
   **When** I send a GET request to `/api/v1/documents/{document_id}/conversations/{conversation_id}/messages`
   **Then** all messages (user questions and assistant answers with citations) are returned in chronological order

## Tasks / Subtasks

- [x] Implement conversation context retrieval (AC: 1–2)
  - [x] Extend `backend/app/repositories/message_repository.py` to support fetching message history for a conversation
    - [x] Add a query to list messages by `conversation_id` in chronological order
    - [x] Add a bounded form (e.g., last N messages) for prompt inclusion (N comes from config)
    - [x] Ensure returned message shapes include `role`, `content`, and `created_at` (citations optional for prompting)
  - [x] Extend `backend/app/services/conversation_service.py` with read APIs
    - [x] `get_or_create_latest_conversation(user_id, document_id) -> Conversation`
    - [x] `get_prompt_history(user_id, document_id, max_messages) -> list[Message]` (uses latest conversation)
    - [x] `create_new_conversation(user_id, document_id) -> UUID` (returns new conversation id)
    - [x] `list_messages_for_conversation(user_id, document_id, conversation_id) -> list[Message]`

- [x] Include conversation history in LLM prompt (AC: 1–2)
  - [x] Update `backend/app/services/llm_service.py` to accept optional conversation history
    - [x] Use LangChain message types for chat history (`SystemMessage`, `HumanMessage`, `AIMessage`)
    - [x] Keep the existing RAG context formatting (page-numbered chunks) intact
    - [x] Ensure truncation logic preserves the system prompt and includes only the most recent N messages
  - [x] Update `backend/app/services/rag_service.py` to pass conversation history through to `LlmService`
    - [x] For both `ask_question(...)` and `stream_answer_events(...)`, include prompt history in the LLM call
    - [x] Keep all existing retrieval, similarity-threshold, and citation-determinism behavior unchanged

- [x] Add conversation endpoints under the existing documents router (AC: 3–4)
  - [x] Update `backend/app/routers/documents.py`
    - [x] `POST /api/v1/documents/{document_id}/conversations/new`
      - [x] Auth required
      - [x] Enforce document ownership via `DocumentService` (no cross-user access)
      - [x] Return `{ "conversation_id": "uuid" }` as a typed Pydantic response model
    - [x] `GET /api/v1/documents/{document_id}/conversations/{conversation_id}/messages`
      - [x] Auth required
      - [x] Enforce that the conversation belongs to `{user_id, document_id}` (messages must be filtered by joining through `conversations` because `messages` has no `user_id` column)
      - [x] Return messages in chronological order (oldest → newest)
      - [x] Use the project’s list response envelope shape (`items`, `total`, etc.) unless it would break existing client assumptions

- [x] Ensure Q&A persistence supports history (supports AC: 4 and future Story 5.4)
  - [x] Confirm both Q&A paths persist messages:
    - [x] Streaming path already persists on completion (Story 5.2)
    - [x] Non-streaming JSON path should also persist the question + assistant answer to the latest conversation
  - [x] Avoid duplicating persistence logic: prefer a shared method in `ConversationService` used by both streaming and non-streaming flows

- [x] Configuration: define a context window limit (AC: 2)
  - [x] Add a new settings field in `backend/app/config.py` (env alias) for max history messages, e.g. `RAG_MAX_HISTORY_MESSAGES`
  - [x] Add the variable to `backend/.env.example` with a sensible default

- [x] Testing (AC: 1–4)
  - [x] Unit tests for truncation/prompt inclusion
    - [x] Suggested: `backend/tests/unit/test_llm_service_history.py` or `backend/tests/unit/test_rag_service_history.py`
    - [x] Verify: most recent N messages included; older messages excluded; system prompt preserved
  - [x] Integration tests for new endpoints
    - [x] Suggested: `backend/tests/integration/test_conversations_new.py` and `backend/tests/integration/test_conversation_messages.py`
    - [x] Verify: auth required; ownership enforced; conversation created; messages returned in order
  - [x] Integration test ensuring follow-up uses history (lightweight)
    - [x] Prefer stubbing at the LLM boundary (so retrieval remains unchanged) and asserting the final prompt includes prior messages

## Dev Notes

### Developer context (read this first)

This story adds **server-side conversation memory** for document Q&A. The backend already persists conversations/messages on successful SSE stream completion (Story 5.2), but it does **not** yet:

- Feed conversation history back into the LLM prompt for follow-up questions
- Provide endpoints to create a fresh conversation or list messages
- Persist the non-streaming (JSON) `/ask` path for history completeness

### What already exists (reuse; do not reinvent)

- Q&A endpoint (JSON + SSE) and ownership/readiness checks:
  - `backend/app/routers/documents.py` → `ask_document_question`
  - `backend/app/services/document_service.py` → `ensure_document_ready_for_question(...)`
- RAG pipeline and deterministic citations:
  - `backend/app/services/rag_service.py`
  - `backend/app/services/vector_service.py`
  - `backend/app/services/processing/embedder.py`
  - `backend/app/services/llm_service.py`
- Conversation persistence (stream completion):
  - `backend/app/services/conversation_service.py` → `persist_stream_completion(...)`
  - `backend/app/models/conversation.py`, `backend/app/models/message.py`
  - `backend/app/repositories/conversation_repository.py`, `backend/app/repositories/message_repository.py`

### Architecture + project guardrails (must follow)

- Routers handle HTTP only; business logic in services; DB queries in repositories.
- Enforce per-user data isolation at the service layer for:
  - Document ownership (already enforced via `DocumentService`)
  - Conversation ownership (must be enforced in new endpoints and history retrieval)
- Keep abstraction boundaries:
  - Only `LlmService` interacts with Groq/LangChain
  - Only `VectorService` interacts with ChromaDB
  - Only `Embedder` loads/uses Sentence Transformers
- Preserve existing SSE contract from Story 5.2 (`token`, `citation`, `done`, and `error` only).

### Context-window design guidance (pragmatic)

- LLaMA 3.3 70B supports a large context window, but still bound prompt growth.
- Define the limit in settings (e.g., `RAG_MAX_HISTORY_MESSAGES`) and use it consistently.
- Truncation rule should be deterministic:
  - Always keep the system prompt
  - Keep the most recent N messages (user/assistant pairs) in chronological order

### Definition: “active conversation” (must be consistent)

- Treat the **active conversation** for `{user_id, document_id}` as the **latest** conversation (ordered by `conversations.updated_at DESC`).
- `POST /conversations/new` should create a new `conversations` row; this naturally becomes the latest and therefore the active conversation for subsequent `/ask` calls.

### API shape guidance

- Endpoints required by AC are under the existing documents router:
  - `POST /api/v1/documents/{document_id}/conversations/new`
  - `GET  /api/v1/documents/{document_id}/conversations/{conversation_id}/messages`
- Follow the project’s standard error response format via `build_error_detail(...)`.

### Project Structure Notes

- New API schemas should live alongside existing schema modules:
  - Add `backend/app/schemas/conversations.py` and/or `backend/app/schemas/messages.py` (match the existing naming style like `documents.py` and `qa.py`).
  - Prefer response models that follow existing list envelope conventions (see `DocumentListResponse`).

### Scope boundaries (avoid scope creep)

- Do not add Flutter UI changes (Story 5.4).
- Do not add cross-document memory (each document’s conversation is isolated).
- Do not introduce Redis, Celery, or complex summarization/compression (MVP truncation is sufficient).

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story-5.3:-Conversation-Memory-and-Context-Management]
- [Source: _bmad-output/planning-artifacts/architecture.md#API-&-Communication-Patterns]
- [Source: _bmad-output/project-context.md#RAG-Pipeline-Rules]
- [Source: _bmad-output/implementation-artifacts/5-2-streaming-answer-endpoint-with-sse.md] (patterns + persistence boundary)
- [Source: https://fastapi.tiangolo.com/advanced/custom-response/#streamingresponse] (stream cancellation points)

## Dev Agent Record

### Agent Model Used

GPT-5.3-Codex (GitHub Copilot)

### Debug Log References

- Red phase:
  - `cd backend && .venv/bin/python -m pytest tests/unit/test_llm_service_history.py tests/integration/test_conversations_new.py tests/integration/test_conversation_messages.py tests/integration/test_documents_ask_history.py`
- Green and regression validation:
  - `cd backend && .venv/bin/python -m pytest tests/unit/test_llm_service_history.py tests/unit/test_rag_service.py tests/unit/test_rag_service_streaming.py tests/integration/test_documents_ask.py tests/integration/test_documents_ask_streaming.py tests/integration/test_conversations_new.py tests/integration/test_conversation_messages.py tests/integration/test_documents_ask_history.py`
  - `cd backend && .venv/bin/python -m ruff check app tests && .venv/bin/python -m pytest`

### Completion Notes List

- Implemented conversation memory retrieval in repository/service layers, including chronological and bounded prompt-history reads.
- Added history-aware LLM prompt construction with deterministic truncation (system prompt preserved, most recent N messages retained).
- Updated RAG JSON and SSE flows to pass prompt history through to `LlmService`.
- Added `POST /api/v1/documents/{document_id}/conversations/new` and `GET /api/v1/documents/{document_id}/conversations/{conversation_id}/messages` with auth and ownership enforcement.
- Unified persistence for streaming and non-streaming Q&A using `ConversationService.persist_qa_exchange(...)`.
- Added `RAG_MAX_HISTORY_MESSAGES` to settings and `.env.example`.
- Added/updated unit and integration tests; full backend test suite and lint checks pass.

### File List

- backend/app/config.py
- backend/.env.example
- backend/app/routers/documents.py
- backend/app/services/conversation_service.py
- backend/app/services/rag_service.py
- backend/app/services/llm_service.py
- backend/app/repositories/conversation_repository.py
- backend/app/repositories/message_repository.py
- backend/app/schemas/conversations.py
- backend/app/schemas/messages.py
- backend/tests/unit/test_llm_service_history.py
- backend/tests/unit/test_rag_service.py
- backend/tests/unit/test_rag_service_streaming.py
- backend/tests/integration/test_documents_ask.py
- backend/tests/integration/test_documents_ask_streaming.py
- backend/tests/integration/test_conversations_new.py
- backend/tests/integration/test_conversation_messages.py
- backend/tests/integration/test_documents_ask_history.py

### Change Log

- 2026-03-20: Implemented Story 5.3 conversation memory/context management, added new conversation/message endpoints, unified Q&A persistence for streaming and non-streaming paths, and added history-focused tests.
