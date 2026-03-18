# Story 3.3: Embedding Generation and Vector Storage

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a system,
I want to generate vector embeddings for document chunks and store them in ChromaDB,
so that semantic similarity search can be performed during Q&A.

## Acceptance Criteria

1. **Given** text chunks with page metadata have been created from a document
   **When** the embedding stage runs
   **Then** the document status is updated to `embedding`
   **And** `backend/app/services/processing/embedder.py` generates vector embeddings for each chunk using Sentence Transformers (local model)
   **And** `backend/app/services/vector_service.py` creates a ChromaDB collection named `user_{user_id}_doc_{document_id}`
   **And** all chunk embeddings are stored in the collection with metadata: `page_number`, `chunk_text`, `chunk_index`
   **And** upon successful completion, the document status is updated to `ready`

2. **Given** embedding generation or ChromaDB storage fails
   **When** an error occurs during the embedding stage
   **Then** the document status is updated to `error` with a descriptive error message
   **And** partial embeddings are cleaned up

## Tasks / Subtasks

- [x] Implement embedding generation service (AC: 1–2)
  - [x] Create `backend/app/services/processing/embedder.py`
  - [x] Use `sentence-transformers==5.3.0` (already in `backend/requirements.txt`)
  - [x] Offload CPU-heavy embedding to a worker thread using `anyio.to_thread.run_sync(...)` (avoid blocking the event loop)
  - [x] Avoid re-downloading models in tests: design the `Embedder` so its underlying model can be injected/mocked
  - [x] Keep a single default model name as a constant (do not scatter magic strings)

- [x] Implement ChromaDB gateway abstraction (AC: 1–2)
  - [x] Create `backend/app/services/vector_service.py` as the ONLY place that talks to ChromaDB
  - [x] Use settings from `backend/app/config.py` (`CHROMA_HOST`, `CHROMA_PORT`) for client configuration
  - [x] Implement `collection_name = f"user_{user_id}_doc_{document_id}"` exactly (security/isolation guardrail)
  - [x] Implement an upsert method that stores:
    - vectors/embeddings
    - documents (chunk text) AND metadata fields including `page_number`, `chunk_index`, `chunk_text`
  - [x] Ensure stable per-chunk IDs (recommendation): `f"{document_id}:{page_number}:{chunk_index}"`
  - [x] Implement cleanup helpers:
    - delete/reset collection for a given `user_id` + `document_id` (used on failures)
    - optional: delete only IDs inserted if you prefer partial cleanup (but simplest is delete collection)

- [x] Extend the processing pipeline to embed and store (AC: 1–2)
  - [x] Update `backend/app/services/processing/pipeline.py` to:
    - capture the output of `chunker.chunk_pages(...)` (it already returns `list[Chunk]`)
    - set status to `DocumentStatus.EMBEDDING` before embedding begins
    - call `Embedder.embed_chunks(chunks)` (or similar) and then `VectorService.upsert_chunks(...)`
    - on success: set status to `DocumentStatus.READY` and clear `error_message`
    - on failure: set status to `DocumentStatus.ERROR` with a descriptive message, and ensure partial embeddings are cleaned up
  - [x] Preserve existing behavior from Story 3.2:
    - keep extraction/chunking status transitions
    - do not move any boto3 calls outside `StorageService`
    - keep the pipeline injectable (session_factory + service injection) for tests

- [x] Error handling and cleanup strategy (AC: 2)
  - [x] If ANY failure occurs after the Chroma collection is created, ensure cleanup is executed
  - [x] Ensure `Document.error_message` is meaningful (surface likely cause: model load failure, chroma connectivity, etc.)
  - [x] Prefer catching and re-raising domain-specific exceptions at the service boundary so the pipeline can set an accurate error message

- [x] Tests (AC: 1–2)
  - [x] Add unit tests for embedder:
    - deterministic embedding shape and number of vectors for N chunks
    - uses thread offload or injectable model so tests don’t download real models
  - [x] Add unit tests for vector service using an in-memory/ephemeral Chroma client (no external server dependency)
    - asserts collection naming
    - asserts stored metadatas include `page_number`, `chunk_index`, `chunk_text`
  - [x] Extend existing pipeline tests in `backend/tests/unit/test_processing_pipeline.py`:
    - success path updates status to `READY` and clears error_message
    - failure path after partial vector insert triggers cleanup and sets `ERROR`
    - use monkeypatch/injection to avoid real Chroma + real SentenceTransformer model

## Dev Notes

### Developer context (read this first)

This story completes the backend document processing pipeline from Story 3.2 by adding:
- embedding generation (Sentence Transformers)
- vector storage (ChromaDB)
- status transition to `ready` on success

The pipeline already exists in `backend/app/services/processing/pipeline.py` and is explicitly written to be extended for Story 3.3.

### What already exists (reuse; do not reinvent)

- Processing orchestration entrypoint:
  - `backend/app/services/processing/pipeline.py::process_document_pipeline(...)`
- Extraction/chunking building blocks:
  - `backend/app/services/processing/extractor.py` returns per-page `PageText`
  - `backend/app/services/processing/chunker.py` returns `list[Chunk]` with `text`, `page_number`, `chunk_index`, `document_id`
- Document status enum already includes required states:
  - `DocumentStatus.EMBEDDING`, `READY`, `ERROR` in `backend/app/models/document.py`
- Error persistence:
  - `Document.error_message` exists (nullable) and is updated via `update_document_status(...)`
- Upload flow + background kickoff:
  - `POST /api/v1/documents/upload` returns immediately and enqueues `process_document_pipeline` via `BackgroundTasks`

### Architectural guardrails (must follow)

- **Gateway boundaries:**
  - Only `StorageService` may call boto3/S3
  - Only `VectorService` may call ChromaDB
  - Embedding logic lives in `services/processing/embedder.py` (do not embed inside routers)
- **Backend layering:** routers → services → repositories
- **Async everywhere:** pipeline and service methods must be `async def` when doing I/O; CPU-heavy work must be offloaded to a thread
- **Security/data isolation:** collection naming must be exactly `user_{user_id}_doc_{document_id}`
- **No regressions:** preserve Story 3.2 test patterns (inject dependencies; no external services required for unit tests)

### Key design decisions to communicate to the dev agent

- Chunk IDs must be stable and unique so embeddings can be overwritten/upserted safely.
- ChromaDB metadata must preserve `page_number` and `chunk_index` for future citation features (Epic 5).
- Cleanup behavior should be deterministic:
  - recommended MVP: delete the entire collection on failure so no partial state remains.

### Project Structure Notes

Expected new/updated paths:
- `backend/app/services/processing/embedder.py` (new)
- `backend/app/services/vector_service.py` (new)
- `backend/app/services/processing/pipeline.py` (update)
- `backend/tests/unit/test_embedder.py` (new or extend existing tests)
- `backend/tests/unit/test_vector_service.py` (new)
- `backend/tests/unit/test_processing_pipeline.py` (extend)

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story-3.3-Embedding-Generation-and-Vector-Storage]
- [Source: _bmad-output/project-context.md#External-Service-Boundaries] (vector_service as sole Chroma interface)
- [Source: _bmad-output/project-context.md#RAG-Pipeline-Rules] (citation-critical metadata + collection naming)
- [Source: _bmad-output/planning-artifacts/architecture.md#Vector-Database:-ChromaDB-1.5.5] (collection strategy)
- [Source: _bmad-output/implementation-artifacts/3-2-document-processing-pipeline-text-extraction-and-chunking.md#Dev-Notes] (pipeline injection/test patterns)

## Dev Agent Record

### Agent Model Used

GPT-5.2 (GitHub Copilot)

### Debug Log References

- Unit tests: `./.venv/bin/python -m pytest tests/unit/test_embedder.py tests/unit/test_vector_service.py tests/unit/test_processing_pipeline.py -q`
- Regression suite: `./.venv/bin/python -m pytest -q`
- Lint checks: `./.venv/bin/python -m ruff check .`

### Completion Notes List

- Added `Embedder` service with lazy model loading, injectable model support, a default model constant, and thread-offloaded embedding generation via `anyio.to_thread.run_sync`.
- Added `VectorService` as the sole ChromaDB gateway with settings-based default client config, required collection naming isolation (`user_{user_id}_doc_{document_id}`), stable chunk IDs, upsert metadata persistence, and collection cleanup helpers.
- Extended processing pipeline to run chunk -> embedding -> vector upsert, transition statuses through `EMBEDDING` and `READY`, and set `ERROR` with descriptive messages plus best-effort vector cleanup on failures.
- Added Story 3.3 unit tests for embedder and vector service, expanded pipeline unit tests for success/failure cleanup, and updated integration pipeline expectation to `READY` using injected test doubles.
- Verified quality gates: backend test suite passes (`46 passed`), and Ruff lint checks pass.

### File List

- `_bmad-output/implementation-artifacts/3-3-embedding-generation-and-vector-storage.md`
- `_bmad-output/implementation-artifacts/sprint-status.yaml`
- `backend/app/services/processing/embedder.py`
- `backend/app/services/processing/pipeline.py`
- `backend/app/services/vector_service.py`
- `backend/tests/integration/test_document_processing_pipeline.py`
- `backend/tests/unit/test_embedder.py`
- `backend/tests/unit/test_processing_pipeline.py`
- `backend/tests/unit/test_vector_service.py`

## Change Log

- 2026-03-18: Implemented embedding generation and ChromaDB vector storage in the processing pipeline, added cleanup/error handling, and added/updated test coverage for Story 3.3.
