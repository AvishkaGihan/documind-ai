# Story 3.4: Flutter Document Upload UI with Progress

Status: done

## Story

As a mobile user,
I want to upload a PDF from my phone with a visible progress indicator,
so that I know the upload is working and can see when it completes.

## Acceptance Criteria

1. **Given** I am on the Document Library screen **when** I tap the Upload/FAB button (+) **then** the native file picker opens filtered for PDF files.
2. **Given** I select a PDF file from the file picker **when** the upload begins **then** a Document Card appears in the library with a linear progress bar showing upload percentage **and** the upload uses multipart form data with progress tracking via Dio's `onSendProgress`.
3. **Given** the upload completes successfully **when** the server responds with the document record **then** the Document Card transitions to show "Processing..." status with an animated glow border **and** the card displays the document title, file size, and page count.
4. **Given** the upload fails (network error, file too large) **when** an error occurs **then** an error SnackBar appears (persistent, red) with a "Retry" action **and** the failed upload can be retried.

## Tasks / Subtasks

- [x] Add file picking capability (AC: 1)
  - [x] Add `file_picker` dependency (use latest known `10.3.10` unless repo pins differently).
  - [x] Implement pick-PDF flow using native picker with PDF-only filtering.
  - [x] Handle cancel/no-selection (no UI changes).

- [x] Implement authenticated multipart upload with progress (AC: 2)
  - [x] Add an auth header mechanism for API calls (e.g., Dio interceptor that reads access token from `tokenStorageProvider`).
  - [x] Implement `uploadDocument(file, onProgress)` client using Dio `FormData` + `MultipartFile` and `onSendProgress`.
  - [x] Ensure request headers do not force `application/json` for multipart uploads.
  - [x] Map backend error payloads (FastAPI `detail.code/message/field`) into a typed app error, consistent with `AuthApi._mapError()`.

- [x] Add upload state management with retry (AC: 2, 4)
  - [x] Create a Riverpod controller (AsyncNotifier or StateNotifier) that manages:
    - selected file metadata
    - upload progress (0–100)
    - upload success -> returned document
    - upload failure -> error + retry
  - [x] Keep the UI responsive: progress updates should not rebuild the entire screen unnecessarily.

- [x] Update Document Library UI to show card states (AC: 2, 3, 4)
  - [x] Replace the placeholder [Library screen](mobile/lib/features/library/screens/library_screen.dart) with:
    - [x] Upload FAB (+) meeting 44×44pt touch target
    - [x] A list area that can show an "uploading" card immediately after file selection
  - [x] Implement a minimal Document Card widget variant for this story:
    - [x] Uploading state: title + linear progress bar + percent label
    - [x] Processing state: "Processing..." label + animated glow border
    - [x] Failed state: visually indicate error, and enable retry via SnackBar action
  - [x] Ensure card uses design tokens via `DocuMindTokens` (no hardcoded colors).
  - [x] Announce progress/status changes for accessibility (Semantics / live region as appropriate).

- [x] Ensure backend response supports UI metadata (AC: 3)
  - [x] Confirm the upload response model contains `title`, `file_size`, and `page_count`.
  - [x] If missing (currently `DocumentPublic` only exposes `id/title/status/created_at`), update backend response schema to include `file_size` and `page_count` (and keep types aligned with DB model).

- [x] Tests (minimum) (AC: 1–4)
  - [x] Unit test upload controller state transitions (start → progress → success; start → failure → retry).
  - [x] Widget test that the Library screen:
    - [x] shows the uploading card after file selection (mock picker)
    - [x] shows error SnackBar with Retry on simulated failure

## Dev Notes

### Key Constraints / Guardrails

- **Do not reinvent auth header handling**: currently there is no `Authorization: Bearer ...` injection in [Dio provider](mobile/lib/core/networking/dio_provider.dart). The upload endpoint requires auth via `CurrentUser` on the backend. Add a single, reusable mechanism (prefer an interceptor) rather than manually adding headers in each API.
- **Multipart vs global headers**: `dioProvider` sets `Content-Type: application/json` globally. Multipart uploads should use `FormData` and let Dio set the boundary/content-type; override headers per-request or remove the global content-type.
- **Backend response mismatch vs AC**: backend `DocumentPublic` currently omits `file_size` and `page_count` even though the DB row has them. AC requires the UI display those after upload.
- **Token access is async**: `SecureTokenStorage.readSession()` is async; plan interceptor code accordingly (async `onRequest`).
- **Design system**: use `DocuMindTokens` (`theme.extension<DocuMindTokens>()`) for colors/spacing/typography; do not hardcode new colors.

### Suggested File/Module Touch Points

Mobile:
- [Dio provider](mobile/lib/core/networking/dio_provider.dart) (auth + multipart header guard)
- [Token storage](mobile/lib/features/auth/data/token_storage.dart)
- [Library screen](mobile/lib/features/library/screens/library_screen.dart)
- New: `mobile/lib/features/library/data/documents_api.dart` (or similar) for upload API
- New: `mobile/lib/features/library/providers/document_upload_controller.dart` (or similar)
- New: `mobile/lib/features/library/widgets/document_card.dart` (minimal implementation for upload/progress/processing)

Backend (only if needed to satisfy AC):
- [Document schema](backend/app/schemas/documents.py)
- [Upload route](backend/app/routers/documents.py)

### API Contract (current)

- Endpoint: `POST /api/v1/documents/upload`
- Auth: required (JWT bearer)
- Body: multipart form-data with a single file field named `file`
- Current response model: `DocumentPublic` (missing `file_size` and `page_count`)

### Testing Notes

- Prefer deterministic widget tests (avoid unbounded `pumpAndSettle()` when progress animations are involved; use bounded pumps).

### Project Structure Notes

- The app currently uses an `AppScaffold` with bottom navigation and each tab screen is itself a `Scaffold` (nested `Scaffold` pattern). Keep changes consistent with this until a dedicated refactor story exists.

### References

- Story requirements: `_bmad-output/planning-artifacts/epics.md` → "Story 3.4: Flutter Document Upload UI with Progress"
- Mobile Dio setup: [mobile/lib/core/networking/dio_provider.dart](mobile/lib/core/networking/dio_provider.dart)
- Auth token storage: [mobile/lib/features/auth/data/token_storage.dart](mobile/lib/features/auth/data/token_storage.dart)
- Backend route prefixing: [backend/app/main.py](backend/app/main.py)
- Backend upload route: [backend/app/routers/documents.py](backend/app/routers/documents.py)
- Backend upload response schema: [backend/app/schemas/documents.py](backend/app/schemas/documents.py)
- Backend file size calculation/source of truth: [backend/app/services/document_service.py](backend/app/services/document_service.py)
- File picker latest known version (for Flutter/Dart >= 3.22/3.4 toolchains): https://pub.dev/api/packages/file_picker (latest: 10.3.10)

## Dev Agent Record

### Agent Model Used

GPT-5.3-Codex

### Debug Log References

- 2026-03-19: Added auth token injection to Dio interceptor and removed forced JSON content-type to support multipart uploads safely.
- 2026-03-19: Added upload API, file picker abstraction, upload controller, and stateful upload card UI with accessibility announcements and retry flow.
- 2026-03-19: Extended backend `DocumentPublic` schema with `file_size` and `page_count`, then updated upload integration test assertions.

### Implementation Plan

- Use `file_picker` through a provider-backed service to keep native picker integration mockable in widget/unit tests.
- Keep upload orchestration in a Riverpod notifier that emits progress and status phases for responsive UI updates.
- Keep API concerns in `DocumentsApi` (multipart request + backend error mapping), while `LibraryScreen` handles user interaction and feedback (SnackBar + retry).
- Align backend upload response model with UI metadata requirements so processing cards can show size/page details immediately.

### Completion Notes List

- Implemented PDF-only selection flow via `file_picker` with graceful no-selection handling.
- Implemented authenticated multipart upload using Dio `FormData` and `onSendProgress`, with app-typed error mapping (`code/message/field`).
- Replaced library placeholder with upload-first UI: FAB trigger, uploading card (progress), processing card (animated glow), and failure handling via persistent red SnackBar + Retry action.
- Added accessibility support with live-region semantics and explicit status announcements.
- Updated backend upload response schema to include `file_size` and `page_count` and validated via integration tests.
- Added unit and widget tests for controller transitions and upload UI error/retry behavior.
- Validation results:
  - `flutter test` (full mobile suite): pass
  - `flutter analyze`: pass
  - `pytest` (full backend suite): pass
  - `ruff check .`: pass

### File List

- backend/app/schemas/documents.py
- backend/tests/integration/test_documents_upload.py
- mobile/pubspec.yaml
- mobile/pubspec.lock
- mobile/lib/core/networking/dio_provider.dart
- mobile/lib/features/library/models/document_upload_models.dart
- mobile/lib/features/library/data/file_picker_service.dart
- mobile/lib/features/library/data/documents_api.dart
- mobile/lib/features/library/providers/document_upload_controller.dart
- mobile/lib/features/library/widgets/document_upload_card.dart
- mobile/lib/features/library/screens/library_screen.dart
- mobile/test/unit/document_upload_controller_test.dart
- mobile/test/widget/library_screen_upload_test.dart
- mobile/test/widget_test.dart

## Change Log

- 2026-03-19: Implemented Story 3.4 end-to-end (mobile upload UI/progress/retry, backend response metadata update, and test coverage additions).
