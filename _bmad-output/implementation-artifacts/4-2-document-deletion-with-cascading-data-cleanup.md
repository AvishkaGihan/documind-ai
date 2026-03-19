# Story 4.2: Document Deletion with Cascading Data Cleanup

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a user,
I want to delete a document and have all associated data removed,
so that I maintain control over my data and storage.

## Acceptance Criteria

1. **Given** I am the owner of a document
   **When** I send a DELETE request to `/api/v1/documents/{document_id}`
   **Then** the PDF file is deleted from cloud storage (S3/Cloudinary)
   **And** the ChromaDB collection (`user_{user_id}_doc_{document_id}`) is deleted with all embeddings
   **And** all conversation and message records associated with the document are deleted
   **And** the document record is deleted from the database
   **And** a 204 No Content response is returned

2. **Given** I try to delete a document that doesn't exist or isn't mine
   **When** I send a DELETE request
   **Then** a 404 Not Found error is returned

## Tasks / Subtasks

- [x] Add DELETE endpoint `DELETE /api/v1/documents/{document_id}` (AC: #1, #2)
  - [x] Implement in existing router `backend/app/routers/documents.py` (do not create a new router)
  - [x] Require auth via `CurrentUser` (same pattern as list/get/upload)
  - [x] Return **204 No Content** with an empty body (use `fastapi.Response(status_code=204)` or equivalent)
  - [x] For non-owner and non-existent documents, return **404** with the standard error format and **do not leak** document existence

- [x] Implement service orchestration in `DocumentService` (AC: #1)
  - [x] Add `delete_document_for_user(user_id: UUID, document_id: UUID) -> None`
  - [x] MUST validate ownership server-side by loading the document via `get_document_for_user(...)` first; if missing → raise `DocumentNotFoundError`
  - [x] Capture `file_path` before deleting DB row (needed for storage deletion)
  - [x] Delete external resources via abstraction layers only:
    - [x] Storage: add + call `StorageService.delete_pdf(object_key: str) -> None`
    - [x] Vector: call `VectorService.delete_document_collection(user_id, document_id)`
  - [x] Delete DB rows in a way that also works on SQLite tests where FK cascades may be disabled by default:
    - [x] Delete `messages` rows associated with the document’s conversations
    - [x] Delete `conversations` rows for that document
    - [x] Delete the `documents` row
  - [x] Ensure delete operation is idempotent at the external boundaries where possible:
    - [x] Vector deletion should be a no-op if collection doesn’t exist (already supported by `VectorService`)
    - [x] Storage deletion should not error if the object is already gone (treat `NoSuchKey` as success)

- [x] Add repository helpers for cascade-safe deletion (AC: #1)
  - [x] Keep all SQLAlchemy `delete(...)` / `select(...)` in repositories, not in routers/services
  - [x] Preferred structure:
    - [x] `backend/app/repositories/conversation_repository.py`
      - [x] `list_conversation_ids_for_document(session, *, document_id: UUID) -> list[UUID]`
      - [x] `delete_messages_for_conversation_ids(session, *, conversation_ids: Sequence[UUID]) -> int`
      - [x] `delete_conversations_for_document(session, *, document_id: UUID) -> int`
    - [x] Extend `backend/app/repositories/document_repository.py`
      - [x] `delete_document_for_user(session, *, document_id: UUID, user_id: UUID) -> int` (returns rows deleted)
  - [x] Commit once after all DB deletions succeed

- [x] Implement storage deletion API (AC: #1)
  - [x] Add `delete_pdf(self, *, object_key: str) -> None` to `backend/app/services/storage_service.py`
  - [x] Use `boto3` client `delete_object(Bucket=..., Key=...)` via `anyio.to_thread.run_sync` (match existing style)

- [x] Add integration tests for document deletion (AC: #1, #2)
  - [x] Add `backend/tests/integration/test_documents_delete.py`
  - [x] Tests to include:
    - [x] DELETE requires authentication → 401 with standard error shape
    - [x] Owner can delete document → 204 and DB rows removed
    - [x] Non-owner delete returns 404 (not 403)
    - [x] Cascading cleanup verified (conversations/messages deleted even on SQLite)
    - [x] External boundaries invoked:
      - [x] monkeypatch `StorageService.delete_pdf` to assert called with `Document.file_path`
      - [x] monkeypatch `VectorService.delete_document_collection` to assert called with `(user_id, document_id)`

## Dev Notes

### Do not reinvent patterns

- Extend the existing `documents` router + `DocumentService` + repositories pattern (routers are HTTP glue only; repositories contain SQLAlchemy; services orchestrate).
- Use existing error format helper `build_error_detail(...)` from `backend/app/routers/errors.py`.

### Security + data isolation (must follow)

- Ownership enforcement is mandatory and must happen server-side.
- For non-owner access, return **404** to prevent ID enumeration.
- Chroma collection naming is a hard requirement: `user_{user_id}_doc_{document_id}` (already implemented in `VectorService`).

### Cascading delete gotcha (SQLite tests)

- Even though the ORM models specify `ondelete="CASCADE"`, SQLite requires `PRAGMA foreign_keys=ON` to enforce cascades.
- The test harness creates tables via `Base.metadata.create_all` without enabling FK pragmas; therefore, the implementation must explicitly delete `messages` and `conversations` rows (do not rely on DB cascade in tests).

### Error handling expectations

- 204 responses must not return a JSON body.
- 404 response should match the existing `DOCUMENT_NOT_FOUND` style used by `GET /api/v1/documents/{document_id}`.
- For external deletion failures (S3/Chroma), return 500 with the standard error envelope and a non-leaky message.

### Project Structure Notes

- Backend:
  - `backend/app/routers/documents.py`
  - `backend/app/services/document_service.py`
  - `backend/app/services/storage_service.py`
  - `backend/app/services/vector_service.py` (likely no changes; reuse existing `delete_document_collection`)
  - `backend/app/repositories/document_repository.py`
  - `backend/app/repositories/conversation_repository.py` (new)
  - (If needed) `backend/app/repositories/message_repository.py` (prefer keeping message deletion in conversation repository)
- Tests:
  - `backend/tests/integration/test_documents_delete.py` (new)

### Cross-story context

- Story 4.1 established conventions for router/service/repository split, 404 for non-owner, deterministic patterns, and integration test style. Reuse those conventions.

### References

- Story requirements + BDD AC: [Source: _bmad-output/planning-artifacts/epics.md#Story 4.2: Document Deletion with Cascading Data Cleanup]
- API patterns + layer boundaries: [Source: _bmad-output/project-context.md#Critical Implementation Rules]
- External service boundaries (storage/vector only): [Source: _bmad-output/project-context.md#External Service Boundaries]
- Chroma collection naming strategy: [Source: _bmad-output/project-context.md#Data Isolation (SECURITY-CRITICAL)]
- Prior implementation patterns (Epic 4): [Source: _bmad-output/implementation-artifacts/4-1-document-library-api-endpoints.md]
- Existing router location: [Source: backend/app/routers/documents.py]
- Existing storage boundary: [Source: backend/app/services/storage_service.py]
- Existing vector boundary: [Source: backend/app/services/vector_service.py]
- Test DB setup (SQLite, create_all): [Source: backend/tests/conftest.py]

## Dev Agent Record

### Agent Model Used

GPT-5.3-Codex

### Implementation Plan

- Extend existing `documents` router to add authenticated DELETE endpoint with 204/404/500 behavior matching existing API error patterns.
- Add deletion orchestration to `DocumentService` with strict ownership check first, external cleanup through storage/vector abstractions, then explicit repository-driven DB cleanup for SQLite cascade safety.
- Add repository helper functions for conversation/message/document deletion while committing once at the service boundary.
- Add integration coverage for auth requirements, owner/non-owner behavior, explicit cascade cleanup, and external service invocation contracts.
- Run targeted and full backend validation (`pytest`, `ruff`) and only then mark story status/tasks complete.

### Debug Log References

- Story created via BMad create-story workflow (auto-selected from sprint-status.yaml).
- Updated `_bmad-output/implementation-artifacts/sprint-status.yaml` from `ready-for-dev` to `in-progress` before implementation.
- Implemented endpoint/service/repository/storage changes and added integration tests for deletion behavior.
- Ran targeted validation: `pytest tests/integration/test_documents_delete.py -q`.
- Ran full regression and quality checks: `pytest -q` (56 passed), `ruff check .` (all checks passed).

### Completion Notes List

- Extracted Story 4.2 AC from epics and aligned with existing backend layering conventions.
- Added explicit guardrails for cascade deletion in SQLite tests (do not rely on FK cascades).
- Specified concrete file paths, error behavior, and test strategy with monkeypatching external services.
- Added `DELETE /api/v1/documents/{document_id}` to existing router with 204 response and standardized 404/500 envelopes.
- Implemented `DocumentService.delete_document_for_user(...)` with ownership validation, file path capture, external resource cleanup, explicit conversation/message/document deletion, and single transaction commit.
- Added `conversation_repository.py` with helper queries/deletes and extended `document_repository.py` with `delete_document_for_user(...)`.
- Implemented `StorageService.delete_pdf(...)` with idempotent no-op handling for missing keys.
- Updated `VectorService` to lazily initialize Chroma client to avoid eager connectivity side effects during non-vector paths.
- Added integration tests in `backend/tests/integration/test_documents_delete.py` covering all AC scenarios.

### File List

- _bmad-output/implementation-artifacts/4-2-document-deletion-with-cascading-data-cleanup.md
- _bmad-output/implementation-artifacts/sprint-status.yaml
- backend/app/routers/documents.py
- backend/app/services/document_service.py
- backend/app/services/storage_service.py
- backend/app/services/vector_service.py
- backend/app/repositories/document_repository.py
- backend/app/repositories/conversation_repository.py
- backend/tests/integration/test_documents_delete.py

## Change Log

- 2026-03-19: Implemented Story 4.2 document deletion with cascading cleanup, added integration tests, and passed full backend regression/lint validation.
