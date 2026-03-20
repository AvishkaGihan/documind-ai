# Story 5.1: RAG Pipeline — Semantic Retrieval and Answer Generation API

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a user,
I want to ask a question about my document and receive an accurate, cited answer,
so that I can extract information without reading the entire document.

## Acceptance Criteria

1. **Given** I have a "ready" document and am authenticated
   **When** I send a POST request to `/api/v1/documents/{document_id}/ask` with a question text
   **Then** `backend/app/services/rag_service.py` generates an embedding for the question using the same Sentence Transformer model
   **And** `backend/app/services/vector_service.py` performs similarity search on the document's ChromaDB collection and retrieves the top-k (default: 5) most relevant chunks with page metadata
   **And** `backend/app/services/llm_service.py` sends the retrieved chunks + question + system prompt to Groq LLaMA 3.3 70B
   **And** the system prompt instructs the LLM to include page citations in the format "According to page X..."
   **And** the response includes the answer text and a structured citations array with page numbers and source text

2. **Given** the document has no relevant content for the question
   **When** the retrieval finds no chunks above the similarity threshold
   **Then** the system returns a message: "I couldn't find relevant information for this question in the document."

## Tasks / Subtasks

- [x] Define Q&A request/response schemas (AC: 1–2)
  - [x] Add `backend/app/schemas/qa.py` (new) with:
    - [x] `AskQuestionRequest(question: str)` (validate non-empty, reasonable max length)
    - [x] `CitationPublic(page_number: int, text: str)`
    - [x] `AskQuestionResponse(answer: str, citations: list[CitationPublic])`
  - [x] Keep API JSON field names `snake_case` (consistent with existing schemas)

- [x] Extend embedder to support question embeddings (AC: 1)
  - [x] Update `backend/app/services/processing/embedder.py` to support embedding arbitrary texts without duplicating model loading
    - [x] Preferred: add `embed_texts(texts: Sequence[str]) -> list[list[float]]` that reuses `_encode_sync`
    - [x] Preserve existing `embed_chunks(...)` behavior and injection-friendly design (tests must not download models)

- [x] Implement vector similarity retrieval (AC: 1–2)
  - [x] Extend `backend/app/services/vector_service.py` with a read path method (no new Chroma calls outside this file):
    - [x] `query_chunks(user_id, document_id, query_embedding, *, top_k=5) -> list[RetrievedChunk]`
    - [x] Use `anyio.to_thread.run_sync(...)` to call Chroma sync APIs (avoid blocking event loop)
    - [x] Query Chroma `collection.query(query_embeddings=[...], n_results=top_k, include=["documents","metadatas","distances"])`
    - [x] Return the retrieved chunks with `page_number`, `chunk_text` (or `document`), and `distance`
  - [x] Similarity threshold behavior:
    - [x] Define a single constant for thresholding (e.g., `DEFAULT_SIMILARITY_THRESHOLD = 0.75` as *similarity*)
    - [x] Convert Chroma distance → similarity using a documented rule (recommended if using cosine: `similarity = 1 - distance`)
    - [x] If the collection metric is ambiguous, make it explicit:
      - [x] Recommended: create collections with cosine space (Chroma HNSW): set `metadata={"hnsw:space": "cosine"}` on `get_or_create_collection(...)`
      - [x] Note: existing collections created before this change may need recreation for consistent scoring

- [x] Implement Groq LLM gateway service (AC: 1)
  - [x] Create `backend/app/services/llm_service.py` as the ONLY place that talks to Groq/LangChain
  - [x] Use `GROQ_API_KEY` from `backend/app/config.py::Settings.groq_api_key`
  - [x] Add `langchain-groq` to `backend/requirements.txt` (keep compatible with `langchain==1.2.10`)
  - [x] If `backend/.env.example` exists, document `GROQ_API_KEY=` there (do not commit real secrets)
  - [x] Use `langchain-groq`’s `ChatGroq` (per project-context) and keep model name configurable (default to Groq LLaMA 3.3 70B)
  - [x] Add retries/timeouts appropriate for demo reliability (avoid infinite waits)
  - [x] Log failures via `structlog` and raise a domain-specific exception at the service boundary

- [x] Implement RAG orchestration service (AC: 1–2)
  - [x] Create `backend/app/services/rag_service.py` to orchestrate:
    - [x] Embed question (reuse `Embedder`)
    - [x] Retrieve top-k chunks (via `VectorService`)
    - [x] Apply similarity threshold → if none, return the required fallback message
    - [x] Build a strict system prompt:
      - [x] Use ONLY provided chunk context
      - [x] If not enough info, answer with the fallback message (no hallucinations)
      - [x] Include citations in the text as "According to page X..."
    - [x] Call `LlmService` to generate answer
    - [x] Return `answer` + `citations`
  - [x] Citations array MUST be deterministic and grounded:
    - [x] Build citations from retrieved chunks’ `page_number` + excerpt text (do not invent pages)
    - [x] Keep citation excerpts short (e.g., first N chars/tokens) for payload size

- [x] Add the `/ask` endpoint (AC: 1–2)
  - [x] Update `backend/app/routers/documents.py` to add `POST /{document_id}/ask`
  - [x] Must require auth (`CurrentUser`) and enforce ownership (reuse `DocumentService.get_document_for_user(...)` or repository equivalent)
  - [x] Ensure document is `DocumentStatus.READY` before answering
    - [x] If not ready, return a consistent error response with an explicit code (e.g., `DOCUMENT_NOT_READY`) and a user-friendly message
  - [x] Keep all business logic in services (router should only validate input, call service, map errors)

- [x] Tests (AC: 1–2)
  - [x] Add unit tests for new logic without external dependencies:
    - [x] `backend/tests/unit/test_rag_service.py`
    - [x] Use injected/stub `VectorService` and `LlmService` to avoid Chroma server + Groq network calls
    - [x] Cover: happy path (returns answer + citations), threshold miss (fallback message), empty question (schema validation)
  - [x] Add integration tests for the endpoint:
    - [x] `backend/tests/integration/test_documents_ask.py`
    - [x] Cover: unauthenticated → 401 `INVALID_TOKEN`, non-owner → 404 `DOCUMENT_NOT_FOUND`, not-ready doc → expected error, ready doc → 200
  - [x] Keep error JSON format exactly: `{"detail": {"code": ..., "message": ..., "field": null}}`

## Dev Notes

### Developer context (read this first)

This story is the first story of Epic 5 (Conversational Q&A). It introduces the non-streaming, backend-only Q&A API that:
- embeds the user question using the existing Sentence Transformer model
- retrieves the most relevant stored chunks from Chroma
- calls Groq-hosted LLaMA 3.3 70B to produce an answer
- returns the answer with page-level citations and a structured citations array

**Explicitly out of scope (avoid scope creep):**
- SSE streaming output (`Accept: text/event-stream`) — Story 5.2
- Conversation persistence / context window truncation / multi-turn memory — Story 5.3
- Flutter chat UI — Story 5.4

### What already exists (reuse; do not reinvent)

- Document processing pipeline that produces embeddings + Chroma collections:
  - `backend/app/services/processing/pipeline.py::process_document_pipeline(...)`
  - `backend/app/services/processing/embedder.py::Embedder`
  - `backend/app/services/vector_service.py::VectorService.upsert_chunks(...)`
- Collection naming and stored metadata already align with citations:
  - collection name: `user_{user_id}_doc_{document_id}`
  - metadata: `page_number`, `chunk_index`, `chunk_text`
- Document ownership enforcement pattern:
  - `backend/app/services/document_service.py::get_document_for_user(...)` raises `DocumentNotFoundError` (maps to 404)
- Error response shape is standardized via:
  - `backend/app/routers/errors.py::build_error_detail(...)`

### Architectural guardrails (must follow)

- **Gateway boundaries:**
  - Only `StorageService` may call boto3/S3
  - Only `VectorService` may call ChromaDB
  - Only the new `LlmService` may call Groq/LangChain
  - Only `Embedder` owns Sentence Transformers model loading
- **Layering:** routers → services → repositories
- **Async discipline:** any blocking/CPU work must be offloaded (Chroma client calls + embedding inference)
- **Data isolation is security-critical:** never allow cross-user access:
  - validate document ownership via DB
  - compute collection name using the authenticated `user_id` and path param `document_id`

### Key technical decisions to make explicit

- **Similarity metric & thresholding:**
  - PRD success metrics talk about cosine similarity; Chroma query returns distances.
  - Ensure the project uses a consistent metric (recommended: cosine via `{"hnsw:space": "cosine"}`) so `similarity = 1 - distance` is meaningful.
- **Deterministic citations:**
  - The citations array must be built from retrieved chunks (page numbers + source text) to avoid hallucinated citations.
  - The LLM can be instructed to cite pages in the answer text, but the structured citations should not depend on perfect model formatting.

### Testing approach notes

- **Unit tests:** stub `VectorService.query_chunks(...)` to return known chunk/page results; stub `LlmService.generate_answer(...)` to return a fixed string.
- **Integration tests:** avoid real Groq + real Chroma by monkeypatching service factories or injecting fakes at the router/service boundary (follow existing test patterns in document upload/pipeline).

### Project Structure Notes

Expected new/updated paths:
- `backend/app/services/rag_service.py` (new)
- `backend/app/services/llm_service.py` (new)
- `backend/app/services/vector_service.py` (update: add query)
- `backend/app/services/processing/embedder.py` (update: add `embed_texts`)
- `backend/app/schemas/qa.py` (new)
- `backend/app/routers/documents.py` (update: add `/ask`)
- `backend/tests/unit/test_rag_service.py` (new)
- `backend/tests/integration/test_documents_ask.py` (new)

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Epic-5:-Conversational-Q&A-with-Cited-Answers]
- [Source: _bmad-output/planning-artifacts/epics.md#Story-5.1:-RAG-Pipeline-—-Semantic-Retrieval-and-Answer-Generation-API]
- [Source: _bmad-output/project-context.md#RAG-Pipeline-Rules] (citations + chunk metadata requirements)
- [Source: _bmad-output/project-context.md#External-Service-Boundaries] (service boundaries)
- [Source: _bmad-output/planning-artifacts/architecture.md#API-Response-Formats] (error + SSE format constraints; SSE out-of-scope here)
- [Source: _bmad-output/planning-artifacts/prd.md#Technical-Success] (RAG quality + <5s target)
- [Source: https://docs.trychroma.com/reference/python/collection#query] (query API + include fields)
- [Source: https://docs.trychroma.com/docs/querying-collections/query-and-get#results-shape] (column-major results)
- [Source: https://docs.langchain.com/oss/python/integrations/chat/groq#installation] (langchain-groq)

## Dev Agent Record

### Agent Model Used

GPT-5.3-Codex (GitHub Copilot)

### Debug Log References

- Focused tests: `./.venv/bin/python -m pytest tests/unit/test_rag_service.py tests/integration/test_documents_ask.py -q`
- Regression suite: `./.venv/bin/python -m pytest -q`
- Lint checks: `./.venv/bin/python -m ruff check .`

### Completion Notes List

- Implemented `POST /api/v1/documents/{document_id}/ask` with auth, ownership validation, and `DOCUMENT_NOT_READY` handling.
- Added RAG orchestration (`rag_service.py`) with question embedding reuse, vector retrieval, cosine distance-to-similarity thresholding, deterministic citations, and fallback behavior.
- Added Groq gateway service (`llm_service.py`) with configurable model, timeout/retry handling, and structured logging.
- Extended vector and embedding services for query-time retrieval (`query_chunks`) and text embeddings (`embed_texts`).
- Added/updated tests and validated with full backend regression + lint (`63 passed`, `ruff check .`).

### File List

- `backend/app/schemas/qa.py`
- `backend/app/services/processing/embedder.py`
- `backend/app/services/vector_service.py`
- `backend/app/services/llm_service.py`
- `backend/app/services/rag_service.py`
- `backend/app/services/document_service.py`
- `backend/app/routers/documents.py`
- `backend/app/config.py`
- `backend/requirements.txt`
- `backend/.env.example`
- `backend/tests/unit/test_rag_service.py`
- `backend/tests/integration/test_documents_ask.py`
- `_bmad-output/implementation-artifacts/5-1-rag-pipeline-semantic-retrieval-and-answer-generation-api.md`
- `_bmad-output/implementation-artifacts/sprint-status.yaml`

## Change Log

- 2026-03-19: Story context created (ready-for-dev).
- 2026-03-19: Implemented Story 5.1 RAG Q&A API, tests, lint, and regression validation; status set to review.
