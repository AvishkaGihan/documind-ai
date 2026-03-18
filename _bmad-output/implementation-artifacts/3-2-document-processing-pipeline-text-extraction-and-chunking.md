# Story 3.2: Document Processing Pipeline — Text Extraction and Chunking

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a system,
I want to extract text from uploaded PDFs with page-level metadata and split it into overlapping chunks,
so that the content is prepared for embedding generation and semantic search.

## Acceptance Criteria

1. **Given** a PDF has been uploaded and stored in cloud storage
   **When** the background processing task starts
   **Then** the document status is updated to `extracting`
   **And** `app/services/processing/extractor.py` extracts all text content with page number metadata preserved for each text segment
   **And** the document status is updated to `chunking`
   **And** `app/services/processing/chunker.py` splits the extracted text into overlapping chunks (default: 500 tokens, 50 token overlap) with source page numbers preserved
   **And** each chunk retains metadata: `page_number`, `chunk_index`, `document_id`

2. **Given** the PDF has poor OCR quality or is empty
   **When** text extraction fails or yields minimal text
   **Then** the document status is updated to `error` with an error message describing the issue

## Tasks / Subtasks

- [x] Add PDF text extraction dependency (AC: 1–2)
  - [x] Add `pypdf==6.9.1` to backend dependencies
    - Rationale: pure-Python, avoids PyMuPDF’s AGPL license; sufficient for non-OCR text extraction MVP
  - [x] Do NOT add PyMuPDF unless licensing is explicitly acceptable

- [x] Create processing module structure (AC: 1)
  - [x] Create `backend/app/services/processing/__init__.py`
  - [x] Create `backend/app/services/processing/extractor.py`
  - [x] Create `backend/app/services/processing/chunker.py`
  - [x] (Recommended) Create `backend/app/services/processing/pipeline.py` to orchestrate “extract → chunk” in one place, so Story 3.3 can extend it with “→ embed → store” without refactors

- [x] Extend `StorageService` for reading PDFs back (AC: 1)
  - [x] Add `StorageService.download_pdf_bytes(*, object_key: str) -> bytes` (or similar) using `boto3.get_object`
  - [x] Keep `storage_service.py` as the ONLY place that calls AWS SDK (`boto3`) (project rule)
  - [x] Use `anyio.to_thread.run_sync(...)` for boto3 calls to avoid blocking the event loop

- [x] Add document repository update primitives (AC: 1–2)
  - [x] Add `get_document_by_id(session, *, document_id) -> Document | None`
  - [x] Add `update_document_status(session, *, document_id, status, error_message=None) -> Document`
  - [x] Add `update_document_page_count(session, *, document_id, page_count) -> Document`
  - [x] Ensure updates commit and refresh consistently (follow `create_document` pattern)

- [x] Add a place to store extraction/chunking errors (AC: 2)
  - [x] Add nullable `error_message: str | None` column to `backend/app/models/document.py`
  - [x] Add Alembic migration to add `documents.error_message` (nullable)
  - [x] (Optional but recommended now) expose `error_message` in a “document details” schema used by future Epic 4 list/detail endpoints

- [x] Implement `Extractor` (AC: 1–2)
  - [x] Implement `extract_text_by_page(*, pdf_bytes: bytes) -> list[PageText]` returning per-page text + `page_number`
  - [x] Use `pypdf.PdfReader(io.BytesIO(pdf_bytes))`
  - [x] Compute `page_count = len(reader.pages)` and update `Document.page_count` early in the pipeline
  - [x] If a page has no extractable text, treat as empty string (do not crash)
  - [x] If the whole document yields minimal text (see threshold guidance below), fail the pipeline with `DocumentStatus.ERROR` and `error_message`
  - [x] Run CPU-heavy parsing in a thread (`anyio.to_thread.run_sync`) if it shows latency under load

- [x] Implement `Chunker` (AC: 1)
  - [x] Implement a token-based chunker with defaults:
    - `chunk_size_tokens = 500`
    - `chunk_overlap_tokens = 50`
    - parameters must be configurable (constants/config), not scattered magic numbers
  - [x] Preserve `page_number` and compute `chunk_index` per page (0..N-1)
  - [x] Preserve `document_id` in each chunk’s metadata
  - [x] Recommended MVP approach to preserve citations: chunk per page (do not span pages) so every chunk has exactly one `page_number`

- [x] Orchestrate background processing and status transitions (AC: 1–2)
  - [x] Add a processing entrypoint callable from FastAPI `BackgroundTasks`
    - Must create its own DB session via `async_session_factory()` (do not reuse request-scoped session)
  - [x] Status transitions (minimum required for this story):
    - set `EXTRACTING` before extraction begins
    - set `CHUNKING` before chunking begins
    - on failure/minimal extraction: set `ERROR` and `error_message`
  - [x] IMPORTANT: Do not move to `EMBEDDING` or `READY` here (that is Story 3.3)

- [x] Wire processing kickoff from upload flow (AC: 1)
  - [x] Update `backend/app/routers/documents.py` to accept `BackgroundTasks`
  - [x] After `DocumentService.upload_document_for_user(...)` returns, enqueue the processing task using the returned document id
  - [x] Ensure the HTTP response still returns immediately (do not block upload response waiting for extraction)

- [x] Add tests (AC: 1–2)
  - [x] Unit tests for chunker token overlap behavior:
    - given a page with N tokens, output chunks sized ≤ 500 tokens, with exactly 50-token overlap between consecutive chunks
    - metadata (`page_number`, `chunk_index`, `document_id`) preserved
  - [x] Unit tests for extractor error path:
    - invalid PDF bytes → extractor raises a domain error and pipeline sets document to `error`
    - empty/minimal-text PDF → pipeline sets `error` with explanatory message
  - [x] Integration test for status transition wiring (best-effort):
    - monkeypatch storage download to return a small fixture PDF
    - trigger processing entrypoint directly (recommended) rather than relying on BackgroundTasks scheduling semantics

## Dev Notes

### Previous Story Intelligence (Story 3.1 learnings to reuse)

- `Document.page_count` is non-nullable today; Story 3.1 sets it to `0` on upload. This story should compute the real `page_count` during extraction and persist it.
- Upload flow already enforces PDF magic-bytes validation and 50MB size limit; do not re-validate file type/size during processing unless you’re handling storage corruption cases.
- Storage is already user-scoped: `users/{user_id}/documents/{document_id}.pdf`. Reuse this for downloads and future deletion.
- The upload endpoint currently returns immediately; processing should remain async/off-thread via FastAPI `BackgroundTasks`.

### What already exists (reuse; do not reinvent)

- Document status enum already includes required states: `DocumentStatus.EXTRACTING`, `CHUNKING`, `ERROR` in backend/app/models/document.py.
- Upload endpoint exists: `POST /api/v1/documents/upload` in backend/app/routers/documents.py.
- Upload service persists documents with `status=processing` and `page_count=0` placeholder in backend/app/services/document_service.py.
- Storage abstraction exists in backend/app/services/storage_service.py and MUST remain the only boto3/S3 touchpoint.
- Standard API error payload builder: backend/app/routers/errors.py::build_error_detail().

### Architectural guardrails (must follow)

- Backend layering: routers → services → repositories. No DB logic in routers; no boto3 calls outside `StorageService`.
- Async everywhere: route handlers, services, repositories, and background pipeline entrypoint must be `async def`.
- IDs are UUID4; API uses `snake_case`.
- Chunking defaults must be configurable (project-context mandates: 500 tokens, 50 overlap; tunable, not magic constants sprinkled around).

### Minimal-text threshold guidance (to avoid false positives)

The AC requires failing on “poor OCR quality or empty” PDFs. Since we are not doing OCR in MVP, treat “image-only PDFs” as minimal-text.

Recommended heuristic:
- After extraction, normalize whitespace and compute total extracted non-whitespace character count.
- If total < 200 characters (or a similar conservative threshold), treat as minimal and mark document `error` with message like:
  - `"No extractable text found. This PDF may be scanned or image-only."`

Keep the threshold as a named constant (so it can be tuned after real-world testing).

### Git Intelligence (recent work patterns)

- Recent history indicates Epic 3 Story 3.1 was merged and completed right before this story.
- Keep patterns consistent with the Story 3.1 implementation (router/service/repo boundaries, standard error payloads, integration testing style).

### Latest Technical Notes (version sanity)

- `pypdf` latest on PyPI: `6.9.1` (released 2026-03-17).
- `PyMuPDF` latest on PyPI: `1.27.2` (released 2026-03-10) but it is AGPL/commercial; avoid unless licensing is explicitly acceptable.

### Project Structure Notes

Expected new/updated paths:
- backend/app/services/processing/extractor.py
- backend/app/services/processing/chunker.py
- backend/app/services/processing/pipeline.py (recommended)
- backend/app/services/storage_service.py (add download method)
- backend/app/repositories/document_repository.py (add update/get helpers)
- backend/app/models/document.py + backend/alembic/versions/* (add `error_message` column)
- backend/tests/unit/test_chunker.py (or similar)
- backend/tests/unit/test_extractor.py (or similar)

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story-3.2-Document-Processing-Pipeline-—-Text-Extraction-and-Chunking]
- [Source: _bmad-output/project-context.md#RAG-Pipeline-Rules] (chunk size/overlap + metadata preservation)
- [Source: _bmad-output/project-context.md#External-Service-Boundaries] (storage_service sole interface)
- [Source: _bmad-output/planning-artifacts/architecture.md#API-&-Communication-Patterns] (background tasks in monolith; stateless backend)
- [Source: backend/app/models/document.py] (DocumentStatus enum)

## Dev Agent Record

### Agent Model Used

GPT-5.3-Codex (GitHub Copilot)

### Debug Log References

- Added `pypdf==6.9.1` and created processing package (`extractor`, `chunker`, `pipeline`) with async background entrypoint.
- Implemented repository status/page count update helpers and storage download method using `anyio.to_thread.run_sync`.
- Added nullable `error_message` on `Document` plus Alembic migration `8f3c2a6d4b10_add_error_message_to_documents.py`.
- Wired document upload route to enqueue processing via `BackgroundTasks` and return immediately.
- Resolved test DB session mismatch by injecting `session_factory` into pipeline (default remains `async_session_factory`).
- Validated with focused and full backend suites: `pytest` (40 passed) and `ruff check app tests` (all checks passed).

### Completion Notes List

- Implemented Story 3.2 processing flow from PDF download through extract/chunk status transitions.
- Added robust extraction failure handling for invalid/minimal-text PDFs with persisted `error_message`.
- Added unit and integration tests for chunk overlap behavior, error paths, and processing status wiring.
- Confirmed no regressions across backend test and lint pipelines.

### File List

- backend/requirements.txt
- backend/app/models/document.py
- backend/alembic/versions/8f3c2a6d4b10_add_error_message_to_documents.py
- backend/app/repositories/document_repository.py
- backend/app/services/storage_service.py
- backend/app/services/document_service.py
- backend/app/routers/documents.py
- backend/app/services/processing/__init__.py
- backend/app/services/processing/extractor.py
- backend/app/services/processing/chunker.py
- backend/app/services/processing/pipeline.py
- backend/tests/unit/test_chunker.py
- backend/tests/unit/test_processing_pipeline.py
- backend/tests/integration/test_document_processing_pipeline.py
- backend/tests/integration/test_documents_upload.py
- backend/tests/unit/test_database_models.py

## Change Log

- 2026-03-18: Implemented Story 3.2 end-to-end (processing modules, repository/storage updates, upload kickoff wiring, migration, and tests).
