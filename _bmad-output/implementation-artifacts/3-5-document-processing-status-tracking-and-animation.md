# Story 3.5: Document Processing Status Tracking and Animation

Status: done

<!-- Ultimate context engine analysis completed - comprehensive developer guide created -->

## Story

As a mobile user,
I want to see real-time processing status for my uploaded documents,
so that I know the system is working and when my document is ready for Q&A.

## Acceptance Criteria

1. **Given** a document has been uploaded and is being processed **when** I view the Document Library **then** the document card shows a Processing Animation Widget with descriptive stages:
   - 📖 "Extracting text..." (with page counter if available)
   - 🧩 "Creating knowledge chunks..."
   - 🧠 "Building intelligence index..."
   - ✅ "Ready to answer your questions!"

2. **Given** the document processing completes **when** the status changes to `ready` **then** the Processing Animation transitions to a green success dot with a subtle celebration animation **and** the card becomes tappable to open the Chat screen.

3. **Given** the document processing fails **when** the status changes to `error` **then** the card shows a red error dot with the error message and a "Retry" option.

4. **And** status polling uses periodic API calls (every 3 seconds) to check document status.

## Scope Notes (Read First)

- This story is **about processing status tracking for the uploaded document(s)** and showing the multi-stage processing UI + ready/error transitions.
- The current Library screen (Story 3.4) only renders the most recent upload card, not a full document list. For this story, the **simplest compliant implementation** is to enhance the existing upload/processing card to:
  - poll backend status every 3 seconds after upload
  - render stage animation + transitions
  - become tappable when `ready`
- Do **not** implement a full document library list/search UI here (that is Epic 4).

## Tasks / Subtasks

### Backend — Status Fetch Endpoint (AC: 4, enables mobile polling)

- [x] Add `GET /api/v1/documents/{document_id}` that returns the current document status payload
  - [x] Must require JWT auth (`CurrentUser`)
  - [x] Must enforce ownership at service layer: if document not found OR not owned by current user → return **404** (not 403) to prevent ID enumeration
  - [x] Response model should include at least: `id`, `title`, `file_size`, `page_count`, `status`, `created_at`, and **`error_message` (nullable)**
  - [x] Error response must follow standard format: `{"detail": {"code": "...", "message": "...", "field": null}}`

- [x] Implement service/repo support for ownership checks
  - [x] Prefer adding a repository helper like `get_document_for_user(session, document_id, user_id)` (or service method) rather than duplicating ownership logic in routers

- [x] Backend tests
  - [x] Integration test: owner can fetch their document by id and sees status updates
  - [x] Integration test: different user fetching someone else’s document id returns 404

### Mobile — Polling + Processing Animation UI (AC: 1–4)

- [x] Extend `DocumentsApi` with a document status fetch
  - [x] Add `getDocumentById(String documentId)` (or similar) calling `GET /api/v1/documents/{documentId}`
  - [x] Reuse existing error mapping style (`LibraryApiError(code/message/field)`)

- [x] Add polling orchestration to the existing `DocumentUploadController`
  - [x] When upload completes and card enters `processing`, start a periodic poll loop **every 3 seconds**
  - [x] Stop polling when status becomes `ready` or `error`
  - [x] Ensure polling is cancelled on provider dispose (use `ref.onDispose` and cancel `Timer`)
  - [x] Avoid overlapping polls: if a poll is in-flight, skip starting another

- [x] Update UI to show multi-stage Processing Animation Widget
  - [x] Render stages based on backend `DocumentStatus` values:
    - `processing` → treat as pre-extraction / "Processing..." (optional)
    - `extracting` → 📖 "Extracting text..."
    - `chunking` → 🧩 "Creating knowledge chunks..."
    - `embedding` → 🧠 "Building intelligence index..." (this maps to the backend’s embedding/index step)
    - `ready` → ✅ "Ready to answer your questions!"
    - `error` → error UI
  - [x] Keep all colors/spacing/typography from `DocuMindTokens` (no hardcoded values)
  - [x] The existing glow border animation from Story 3.4 may be reused, but must respect Reduce Motion (see guardrails)

- [x] Ready state interaction (AC: 2)
  - [x] When status becomes `ready`, show a green success dot and a subtle celebration animation
  - [x] Card becomes tappable; tapping navigates to `/chat/:documentId` using the uploaded document id

- [x] Error state interaction (AC: 3)
  - [x] When status becomes `error`, show a red error dot and the backend `error_message` if present (fallback to a generic message)
  - [x] Provide a "Retry" option.
    - Recommended minimal interpretation: reuse the existing retry flow from Story 3.4 (re-upload the same file) since the backend does not currently expose a retry-processing endpoint.

- [x] Accessibility
  - [x] Stage transitions should be announced (similar to Story 3.4 announcements)
  - [x] Ensure the processing widget remains screen-reader friendly (Semantics, liveRegion where appropriate)

- [x] Mobile tests
  - [x] Unit test the polling loop behavior (starts after upload, stops on ready/error, cancels on dispose)
  - [x] Widget test verifies stage text updates and ready state tap affordance (avoid unbounded `pumpAndSettle()` due to animations)

## Dev Notes

### Existing Code Reality (Ground Truth)

- Backend currently has:
  - status pipeline updates in `services/processing/pipeline.py` (extracting → chunking → embedding → ready/error)
  - **no** document GET/list endpoints in `routers/documents.py` (currently upload-only)
  - `Document` includes `error_message`, but `DocumentPublic` schema does **not** currently expose it

- Mobile currently has:
  - `DocumentsApi.uploadDocument()` only
  - `DocumentUploadController` that transitions into a `processing` phase but **does not** poll status
  - `DocumentUploadCard` with an animated glow for processing, but no stage-based animation

### Guardrails (Prevent Common LLM Dev Mistakes)

- Do not bypass service boundaries:
  - Backend: routers should remain thin; ownership checks should live in service/repo layer.
- Do not break Story 3.4:
  - Keep upload progress behavior and snack bar retry flow intact.
- Do not hardcode UI tokens:
  - Use `Theme.of(context).extension<DocuMindTokens>()`.
- Respect Reduce Motion:
  - If `MediaQuery.disableAnimations` (or equivalent) indicates reduced motion, use static states (no pulsing glow / no celebration animation).
- Polling correctness:
  - Timer must be cancelled (memory leak + background network risk if not).
  - Avoid overlapping calls; keep polling deterministic for tests.

### Suggested Implementation Shape (Minimal + Compliant)

- Backend:
  - Add `GET /api/v1/documents/{document_id}`
  - Extend `DocumentPublic` to include `error_message: str | None`

- Mobile:
  - Add `DocumentsApi.getDocumentById(...)`
  - Update `DocumentUploadState` to store last-known backend status + optional error message (either inside `UploadedDocument` model or as a separate field)
  - Evolve `DocumentUploadCard` into a small state machine UI:
    - uploading → progress bar
    - processing (status != ready/error) → stage widget
    - ready → green dot + tappable
    - error → red dot + message + retry

### Project Structure Notes

- Keep changes within existing feature boundaries:
  - mobile: `features/library/{data,providers,widgets}`
  - backend: `routers/`, `services/`, `repositories/`, `schemas/`

## References

- Story definition and ACs: `_bmad-output/planning-artifacts/epics.md` → "Story 3.5: Document Processing Status Tracking and Animation"
- UX stage language: `_bmad-output/planning-artifacts/ux-design-specification.md` → Processing states and "Processing Animation Widget"
- Backend status pipeline: `backend/app/services/processing/pipeline.py`
- Backend document model/status enum: `backend/app/models/document.py`
- Existing upload endpoint: `backend/app/routers/documents.py`
- Existing mobile upload flow:
  - `mobile/lib/features/library/providers/document_upload_controller.dart`
  - `mobile/lib/features/library/data/documents_api.dart`
  - `mobile/lib/features/library/widgets/document_upload_card.dart`
  - `mobile/lib/features/library/screens/library_screen.dart`
- Routing target for ready tap: `mobile/lib/router.dart` (`/chat/:documentId`)

## Dev Agent Record

### Agent Model Used

GPT-5.2

### Debug Log References

- Backend tests (red/green):
  - `/home/avishkagihan/Documents/documind-ai/backend/.venv/bin/python -m pytest tests/integration/test_documents_get.py -q` (red, failed before endpoint implementation)
  - `/home/avishkagihan/Documents/documind-ai/backend/.venv/bin/python -m pytest tests/integration/test_documents_get.py tests/integration/test_documents_upload.py -q` (green)
- Full validations:
  - `/home/avishkagihan/Documents/documind-ai/backend/.venv/bin/python -m pytest -q`
  - `/home/avishkagihan/Documents/documind-ai/backend/.venv/bin/python -m ruff check .`
  - `flutter test`
  - `flutter analyze`

### Implementation Plan

- Backend: add an authenticated `GET /api/v1/documents/{document_id}` route, enforce ownership in service/repository (`get_document_for_user`), and return standardized 404 errors for missing/non-owned documents.
- Mobile data: extend `UploadedDocument` with nullable `errorMessage`, add `DocumentsApi.getDocumentById`, and reuse existing API error mapping.
- Mobile state orchestration: implement a timer-based 3-second poll loop in `DocumentUploadController`, guard against overlapping polls, cancel on dispose, and stop on `ready`/`error` terminal states.
- Mobile UI: evolve `DocumentUploadCard` into stage-driven rendering for `extracting/chunking/embedding`, plus ready celebration+tappable affordance and processing-error retry UI.
- Accessibility and motion: retain live region semantics and emit stage announcements; disable glow/celebration effects when reduce-motion is enabled.

### Completion Notes List

- Added backend status fetch endpoint: `GET /api/v1/documents/{document_id}` with JWT auth, ownership enforcement in service/repo, and standardized 404 error payload for not-found/non-owned documents.
- Extended `DocumentPublic` payload with nullable `error_message` and aligned upload tests for the new response field.
- Added backend integration coverage for owner fetch success and cross-user 404 behavior in `backend/tests/integration/test_documents_get.py`.
- Added `DocumentsApi.getDocumentById` and extended `UploadedDocument` parsing to include backend `error_message`.
- Implemented 3-second polling in `DocumentUploadController` with disposal cleanup, overlap prevention, terminal-state stop logic, and status announcement updates.
- Updated upload card UX to render stage text (`extracting/chunking/embedding`), ready state success/tap affordance, and processing error state with retry.
- Added reduce-motion safeguards for processing glow and ready celebration animations.
- Wired ready-state navigation to `/chat/:documentId` and retry action through the existing controller flow.
- Added mobile tests for polling behavior and stage/ready affordance widget behavior using bounded pump durations.
- Validation result: backend tests pass (`48 passed`), backend lint passes (`ruff check .`), mobile tests pass (`13 passed`), mobile analyze passes (no issues).

### File List

- `_bmad-output/implementation-artifacts/3-5-document-processing-status-tracking-and-animation.md`
- `_bmad-output/implementation-artifacts/sprint-status.yaml`
- `backend/app/routers/documents.py`
- `backend/app/services/document_service.py`
- `backend/app/repositories/document_repository.py`
- `backend/app/schemas/documents.py`
- `backend/tests/integration/test_documents_get.py`
- `backend/tests/integration/test_documents_upload.py`
- `mobile/lib/features/library/models/document_upload_models.dart`
- `mobile/lib/features/library/data/documents_api.dart`
- `mobile/lib/features/library/providers/document_upload_controller.dart`
- `mobile/lib/features/library/widgets/document_upload_card.dart`
- `mobile/lib/features/library/screens/library_screen.dart`
- `mobile/test/unit/document_upload_controller_test.dart`
- `mobile/test/widget/library_screen_upload_test.dart`
- `mobile/test/widget/document_upload_card_test.dart`

## Change Log

- 2026-03-19: Implemented Story 3.5 end-to-end (backend document status endpoint, mobile polling+processing state machine, ready/error interactions, accessibility/motion guardrails, and regression test coverage).
