# Story 4.1: Document Library API Endpoints

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a user,
I want to retrieve my document list, view document details, and search by title,
so that I can manage my uploaded documents.

## Acceptance Criteria

1. **Given** I am an authenticated user with uploaded documents
   **When** I send a GET request to `/api/v1/documents`
   **Then** a paginated list of my documents is returned (default page_size=20) with id, title, status, page_count, file_size, created_at for each document
   **And** only documents belonging to the authenticated user are returned (server-side enforcement)

2. **Given** I provide a `search` query parameter
   **When** I send a GET request to `/api/v1/documents?search=contract`
   **Then** only documents whose title contains the search term are returned (case-insensitive)

3. **Given** I send a GET request to `/api/v1/documents/{document_id}`
   **When** the document belongs to me
   **Then** full document details are returned including metadata

4. **Given** I try to access another user's document
   **When** I send a GET request with their document_id
   **Then** a 404 Not Found error is returned (not 403, to prevent ID enumeration)

## Tasks / Subtasks

- [x] Add paginated list endpoint `GET /api/v1/documents` (AC: #1, #2)
  - [x] Add query params `page` (default=1, >=1), `page_size` (default=20, >=1), `search` (optional)
  - [x] Return list response in the required list format: `{"items": [...], "total": N, "page": 1, "page_size": 20}`
  - [x] Ensure server-side user isolation: results must be filtered by `current_user.id`
  - [x] Ensure case-insensitive title search when `search` is provided
  - [x] Define deterministic sort order (recommend: newest first via `created_at DESC`)

- [x] Implement repository query + count (AC: #1, #2)
  - [x] Add `list_documents_for_user(...)` in `backend/app/repositories/document_repository.py`
  - [x] Add `count_documents_for_user(...)` (or return `(items, total)` from one helper)
  - [x] Use SQLAlchemy 2.0 async style (`select(...)`), and keep SQLite + Postgres compatibility

- [x] Add service-layer API to orchestrate list retrieval (AC: #1, #2)
  - [x] Add `list_documents_for_user(...)` in `backend/app/services/document_service.py`
  - [x] Ensure service is the boundary for user ownership enforcement (do not trust client-provided user_id)

- [x] Confirm document details endpoint behavior (AC: #3, #4)
  - [x] Verify `GET /api/v1/documents/{document_id}` already returns 404 for non-owner (ID enumeration prevention)
  - [x] If any required metadata is missing from `DocumentPublic`, extend schema carefully (avoid leaking storage paths)

- [x] Add integration tests (AC: #1–#4)
  - [x] Add `backend/tests/integration/test_documents_list.py` to cover:
    - [x] Default pagination (`page_size=20`) and response shape (`items`, `total`, `page`, `page_size`)
    - [x] Only owner documents returned (create docs for two users)
    - [x] Case-insensitive `search` filtering
  - [x] Ensure existing tests for `GET /api/v1/documents/{document_id}` remain valid

## Dev Notes

- **Do not reinvent patterns:** There is already a `documents` router and `DocumentService`; extend these rather than creating a new router/service.
- **Router/service/repository split is mandatory:** routers are HTTP glue only; business logic in services; all SQLAlchemy queries in repositories.
- **Response format is a hard requirement:** list responses must be wrapped in `items/total/page/page_size`.
- **Security-critical:** every list and detail read must enforce `user_id` ownership server-side. For non-owner document access, return **404**.

### Project Structure Notes

- Backend files to touch (expected):
  - `backend/app/routers/documents.py` (add `GET /api/v1/documents`)
  - `backend/app/services/document_service.py` (add list method)
  - `backend/app/repositories/document_repository.py` (add list/count queries)
  - `backend/app/schemas/documents.py` (add paginated response schema)
  - `backend/tests/integration/test_documents_list.py` (new)

### References

- Story requirements + BDD AC: [Source: _bmad-output/planning-artifacts/epics.md#Story 4.1: Document Library API Endpoints]
- Auth + ownership enforcement pattern: [Source: backend/app/dependencies/auth.py]
- Existing document endpoints and error shape: [Source: backend/app/routers/documents.py]
- List response envelope requirement (`items/total/page/page_size`): [Source: _bmad-output/project-context.md#Code Quality & Style Rules]
- Tech stack versions (FastAPI/Pydantic/SQLAlchemy): [Source: _bmad-output/project-context.md#Technology Stack & Versions]

## Dev Agent Record

### Agent Model Used

GPT-5.3-Codex

### Debug Log References

- Added failing integration tests first: `backend/tests/integration/test_documents_list.py` (`pytest` failed with 404 before endpoint implementation)
- Added repository methods for paginated list and count with user ownership filter and case-insensitive search
- Added service method to orchestrate paginated retrieval and list envelope response
- Added `GET /api/v1/documents` router endpoint with validated query parameters
- Ran validations: `ruff check .` and full backend test suite

### Completion Notes List

- Implemented `GET /api/v1/documents` with `page`, `page_size`, and optional `search` query params.
- Enforced server-side user isolation in repository queries using `user_id` filtering.
- Added deterministic sorting (`created_at DESC`, then `id DESC`) to stabilize pagination order.
- Added paginated response schema envelope: `items`, `total`, `page`, `page_size`.
- Verified existing document detail endpoint behavior remains 404 for non-owner access.
- Added integration tests for default pagination/shape, ownership filtering, and case-insensitive search.
- Validation passed: `pytest -q` (51 passed), `ruff check .` (all checks passed).

### File List

- backend/app/routers/documents.py
- backend/app/services/document_service.py
- backend/app/repositories/document_repository.py
- backend/app/schemas/documents.py
- backend/tests/integration/test_documents_list.py

### Change Log

- 2026-03-19: Implemented Story 4.1 document library list API with pagination, search, ownership filtering, and integration tests; validated with full backend tests and lint checks.

