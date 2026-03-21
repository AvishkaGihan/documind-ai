# Story 7.3: Account Deletion Backend Endpoint

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a user,
I want to delete my account and all my data from the system,
so that I have full control over my data privacy (NFR10).

## Acceptance Criteria

1. **Given** I am an authenticated user
   **When** I send a DELETE request to `/api/v1/user/me`
   **Then** the user record is deleted
   **And** ALL associated documents, vectors in ChromaDB, and conversations are cascade-deleted
   **And** 204 No Content is returned

## Tasks / Subtasks

- [x] API: add authenticated account-deletion endpoint (AC: #1)
  - [x] Create a new router `backend/app/routers/user.py` (do not add this to `auth.py`)
  - [x] Add `DELETE /me` under router prefix `/api/v1/user`
  - [x] Require auth via `CurrentUser` dependency (same pattern used in `backend/app/routers/documents.py`)
  - [x] Return **204 No Content** with an empty body (`fastapi.Response(status_code=204)` or `Response(status_code=status.HTTP_204_NO_CONTENT)`)
  - [x] Register the router in `backend/app/main.py` with `app.include_router(user_router, prefix="/api/v1/user", tags=["user"])

- [x] Service: orchestrate full account deletion (AC: #1)
  - [x] Create `backend/app/services/user_service.py` containing the business logic for account deletion
  - [x] Implement `async def delete_account(self, *, user_id: UUID) -> None`
  - [x] MUST be reuse-first: leverage existing `DocumentService.delete_document_for_user(...)` for each user document to avoid duplicating cascade logic and external boundary calls
  - [x] Ensure the implementation works in SQLite tests even if FK cascades are not enforced (do not rely on database cascades alone)
  - [x] For any external cleanup failure (storage/vector), abort and return a standardized 500 error envelope (see router task)

- [x] Repositories: add minimal helpers for deletion orchestration (AC: #1)
  - [x] Extend `backend/app/repositories/document_repository.py`
    - [x] Add `list_document_ids_for_user(session, *, user_id: UUID) -> list[UUID]` (no pagination)
  - [x] Extend `backend/app/repositories/user_repository.py`
    - [x] Add `delete_user_by_id(session, *, user_id: UUID) -> int` (returns rows deleted)

- [x] Error handling: consistent envelope + non-leaky messaging (AC: #1)
  - [x] Use `build_error_detail(...)` from `backend/app/routers/errors.py` for any 401/500 error response payloads
  - [x] Define a dedicated error code for failures during account deletion, e.g. `USER_DELETION_FAILED`
  - [x] Keep error messages non-leaky and user-safe (do not include object keys, document ids, or stack traces)

- [x] Tests: integration coverage for account deletion (AC: #1)
  - [x] Add `backend/tests/integration/test_user_delete_me.py`
  - [x] Test unauthenticated request returns 401 with the standard error shape (`INVALID_TOKEN`)
  - [x] Test happy path returns 204 and deletes:
    - [x] `users` row for the current user
    - [x] all `documents` for that user
    - [x] all `conversations` and `messages` associated with those documents
  - [x] Test external boundaries invoked per document:
    - [x] monkeypatch `StorageService.delete_pdf` and `VectorService.delete_document_collection` like `backend/tests/integration/test_documents_delete.py`
    - [x] Assert both are called once per deleted document
  - [x] Optional but recommended: after deletion, verify the same access token no longer authenticates (any authenticated endpoint should return 401 because user no longer exists)

## Dev Notes

### Ground truth: existing deletion patterns to reuse (do NOT reinvent)

- Document-level cascading deletion is already implemented and tested:
  - Router: `backend/app/routers/documents.py` → `DELETE /api/v1/documents/{document_id}`
  - Service orchestration: `backend/app/services/document_service.py` → `delete_document_for_user(...)`
  - External cleanup boundaries:
    - `backend/app/services/storage_service.py` → `delete_pdf(object_key=...)`
    - `backend/app/services/vector_service.py` → `delete_document_collection(user_id, document_id)`
  - SQLite cascade safety is handled explicitly (messages/conversations deleted manually):
    - `backend/app/repositories/conversation_repository.py`

**Reuse-first guidance (strongly preferred):**
- In `UserService.delete_account(...)`, list the user’s document IDs and call `DocumentService.delete_document_for_user(user_id=user_id, document_id=doc_id)` for each.
- This automatically ensures:
  - Vector collection removal (`user_{user_id}_doc_{document_id}`)
  - Storage object deletion
  - Explicit message + conversation cleanup
  - Document row deletion
  - Commit behavior consistent with existing endpoint

### Account deletion ordering

Recommended sequence inside the service:
1. List all document IDs for the user
2. Delete each document via `DocumentService.delete_document_for_user(...)`
3. Delete the user record via `user_repository.delete_user_by_id(...)`
4. Commit

Rationale:
- External deletes are irreversible; delete external + related DB rows before removing the owning user.
- After the user is deleted, JWT auth becomes invalid automatically (`get_current_user` fails because user no longer exists).

### Security and privacy expectations

- Endpoint must require authentication.
- Do not allow specifying a `user_id` in the request (no path params, no query params).
- Return 204 with empty body for success.

### Latest tech constraints / versions

- FastAPI in this repo is pinned at `fastapi[standard]==0.135.1` (see architecture + dependencies). Keep patterns consistent with current routers.
- A 204 response should not include a JSON body.

### Previous story intelligence (Epic 7)

- Story 7.1 and 7.2 established the Settings screen layout and test harness patterns on mobile.
- Story 7.4 (UI) will call this backend endpoint and expects:
  - A 204 success with empty body
  - A standardized error envelope for failures (so the UI can show a consistent error SnackBar)

### Git intelligence (recent patterns)

- Recent commits are dominated by Epic 7 mobile settings work (Stories 7.1 and 7.2). Keep this backend change consistent with existing backend patterns (especially Story 4.2 delete behavior) and avoid introducing new response conventions.

### Latest technical notes (web research)

- FastAPI docs for current versions show `status_code` and returning a `Response` directly are the standard ways to emit status-only responses; keep the route implementation consistent with the existing `DELETE /api/v1/documents/{document_id}` style in this repo.

### References

- Epic 7, Story 7.3 BDD AC: `_bmad-output/planning-artifacts/epics.md` → Epic 7 → Story 7.3
- Data deletion requirement (NFR10): `_bmad-output/planning-artifacts/prd.md` → Non-Functional Requirements → Security → Data Deletion
- Backend layering rules + error envelope: `_bmad-output/project-context.md` → FastAPI rules + API response formats
- Existing cascade deletion implementation: `_bmad-output/implementation-artifacts/4-2-document-deletion-with-cascading-data-cleanup.md`
- Existing tested endpoint pattern: `backend/tests/integration/test_documents_delete.py`
- Existing deletion orchestrator: `backend/app/services/document_service.py` → `delete_document_for_user(...)`
- Auth dependency: `backend/app/dependencies/auth.py` → `CurrentUser`

## Dev Agent Record

### Agent Model Used

GPT-5.3-Codex

### Debug Log References

- `python -m pytest -q tests/integration/test_user_delete_me.py`
- `python -m pytest -q`
- `python -m ruff check .`

### Completion Notes List

- Implemented authenticated `DELETE /api/v1/user/me` endpoint returning 204 with empty body.
- Added `UserService.delete_account(...)` using reuse-first orchestration via `DocumentService.delete_document_for_user(...)` for each user document.
- Added repository helpers for listing user document IDs and deleting user rows.
- Added integration coverage for unauthenticated access, successful cascade deletion, per-document external boundary invocation, token invalidation after deletion, and standardized 500 error handling.
- Validation complete: backend regression tests and lint checks pass.

### File List

- `backend/app/routers/user.py` (new)
- `backend/app/services/user_service.py` (new)
- `backend/app/repositories/user_repository.py` (extend)
- `backend/app/repositories/document_repository.py` (extend)
- `backend/app/main.py` (register router)
- `backend/tests/integration/test_user_delete_me.py` (new)

## Change Log

- 2026-03-22: Implemented Story 7.3 account deletion backend endpoint and tests; validated with full backend test suite and ruff lint.

## Story Completion Status

- Status set to `done`
