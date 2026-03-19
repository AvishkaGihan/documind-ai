# Story 4.3: Flutter Document Library Screen

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a mobile user,
I want to view my document library as a polished list of document cards,
so that I can see all my documents, their status, and quickly access any document for Q&A.

## Acceptance Criteria

1. **Given** I am logged in
   **When** I navigate to the Library tab
   **Then** I see a list of Document Cards (glassmorphic style) showing: PDF icon, document title, metadata row (page count, file size, upload date), and status indicator (green dot = ready, animated glow = processing, red dot = error)
   **And** the list uses `ListView.builder` for efficient lazy-loading
   **And** pull-to-refresh reloads the document list

2. **Given** I have no uploaded documents
   **When** I view the Library screen
   **Then** I see an Empty State with "Upload your first PDF" message and a prominent Upload CTA button

3. **Given** I tap on a "ready" document card
   **When** the card is tapped
   **Then** a Hero animation transitions the card to the Chat screen for that document

4. **Given** I long-press on a document card
   **When** the context menu appears
   **Then** I see options: "Delete" (with confirmation dialog) and "Info" (shows full metadata)

## Tasks / Subtasks

- [x] Add documents list API support on mobile (AC: #1, #2)
  - [x] Extend `DocumentsApi` to fetch the paginated list via `GET /api/v1/documents`
  - [x] Add a lightweight response envelope model for `DocumentListResponse` (`items`, `total`, `page`, `page_size`)
  - [x] Reuse existing `UploadedDocument` model for items (matches backend `DocumentPublic` shape)

- [x] Add document deletion API support on mobile (AC: #4)
  - [x] Extend `DocumentsApi` with `deleteDocument(documentId)` via `DELETE /api/v1/documents/{document_id}`
  - [x] Handle `204` as success (no body)
  - [x] For `404` show a non-leaky message (e.g., "Document not found.") and refresh list

- [x] Add Riverpod provider for document list state (AC: #1, #2)
  - [x] Use an `AsyncNotifier` (preferred) or equivalent Riverpod async pattern used elsewhere (`auth_provider.dart`)
  - [x] Load documents using the backend defaults or choose a safe `page_size` (recommend: `page_size=100` since product max is 100 docs/user)
  - [x] Expose a `refresh()` method and wire it to pull-to-refresh (`RefreshIndicator`)
  - [x] Recommended naming:
    - [x] Provider: `documentListProvider`
    - [x] Notifier: `DocumentListNotifier extends AsyncNotifier<DocumentListResponse>` (or `AsyncNotifier<List<UploadedDocument>>` if you intentionally ignore pagination metadata)

- [x] Implement the full Library UI (AC: #1, #2)
  - [x] Update `LibraryScreen` to render:
    - [x] Empty state (when list is empty and not uploading)
    - [x] Upload UI (reuse existing `DocumentUploadCard` for in-flight upload/processing)
    - [x] Document list using `ListView.builder`
  - [x] Ensure the screen remains token-driven (no hardcoded colors/spacing/fonts)
  - [x] Keep the existing Upload FAB behavior (`documentUploadControllerProvider.pickAndUpload()`)

- [x] Implement `DocumentCard` widget for library items (AC: #1, #3, #4)
  - [x] New widget under `mobile/lib/features/library/widgets/document_card.dart`
  - [x] Visual requirements:
    - [x] PDF icon
    - [x] Title (1 line, ellipsis)
    - [x] Metadata row: pages, file size, upload date
    - [x] Status indicator:
      - [x] `ready` → green dot
      - [x] `processing|extracting|chunking|embedding` → animated glow border (reuse the glow technique from `DocumentUploadCard`)
      - [x] `error` → red dot (and optionally show short error text)
    - [x] Glassmorphic styling:
      - [x] Prefer a frosted-glass look using Flutter primitives (`ClipRRect` + `BackdropFilter`) rather than inventing new color values
      - [x] Use existing palette/tokens for surface colors and borders (e.g., `tokens.colors.surfaceSecondary`, `tokens.colors.borderDefault`) and apply translucency via `.withValues(alpha: ...)`
  - [x] Interaction requirements:
    - [x] Tap (only when `ready`) navigates to `/chat/:documentId` using `go_router`
    - [x] Long-press opens context menu with Delete/Info actions
    - [x] Wrap interactive elements with `Semantics` labels and maintain 44×44pt touch targets

- [x] Implement Delete + Info flows (AC: #4)
  - [x] Delete
    - [x] Show confirmation dialog before calling API
    - [x] On confirm: call `DocumentsApi.deleteDocument`, then refresh list
    - [x] On failure: show SnackBar using token colors (error = `tokens.colors.accentError`, destructive actions are explicit)
  - [x] Info
    - [x] Show a dialog or bottom sheet displaying full metadata (title, status, created_at, page_count, file_size; include error_message if present)

- [x] Add widget tests for the library screen (AC: #1–#4)
  - [x] Tests live under `mobile/test/widget/` (match existing style in `library_screen_upload_test.dart`)
  - [x] Minimum coverage recommended:
    - [x] Empty state shows message + Upload CTA when API returns zero items
    - [x] Non-empty state renders list items via `ListView.builder`
    - [x] Tap ready card navigates to chat route (or calls `GoRouter` navigation)
    - [x] Long-press shows context menu; delete path invokes fake API and refresh

## Dev Notes

### Do not reinvent patterns

- Keep using Dio + `dioProvider` for authenticated requests.
- Reuse the existing upload flow and polling in `document_upload_controller.dart`.
- Reuse the `UploadedDocument` model for both upload/status polling and list items to avoid duplicate models.

### Backend contracts (must follow)

- List documents: `GET /api/v1/documents`
  - Response: `{"items": [DocumentPublic...], "total": N, "page": 1, "page_size": 20}`
  - Document shape fields: `id`, `title`, `file_size`, `page_count`, `status`, `error_message`, `created_at`
- Delete document: `DELETE /api/v1/documents/{document_id}`
  - Success: `204 No Content`
  - Errors: standard error envelope `{"detail": {"code": "...", "message": "...", "field": null}}`

### Architecture + style guardrails (must follow)

- Riverpod for async state (avoid `StatefulWidget` for async data).
- No hardcoded colors/spacing/fonts; use `DocuMindTokens` + `AppSpacing`.
- Use `ListView.builder` for the document list.
- Accessibility:
  - Add `Semantics` labels for document cards and menu actions.
  - Ensure 44×44pt minimum touch targets.
  - Prefer clear announcements for state changes where appropriate (pattern already exists in `LibraryScreen` for upload announcements).

### Navigation + Hero animation

- Routes are already defined in `mobile/lib/router.dart` for `/library` and `/chat/:documentId`.
- Implement a Hero transition by:
  - Wrapping the `DocumentCard` in a `Hero(tag: 'document-${doc.id}', ...)`.
  - Adding a matching Hero in `mobile/lib/features/chat/screens/chat_screen.dart` for the selected document.

### Status mapping (backend → UI)

- Treat `DocumentPublic.status` as a string enum coming from the backend.
- Recommended mapping:
  - `ready` → tappable card + green dot + navigate to chat
  - `error` → non-tappable card + red dot + show error text (if present)
  - Any other value (`processing`, `extracting`, `chunking`, `embedding`) → non-tappable card + processing glow

### Common pitfalls to avoid

- Don’t fetch documents inside `build()` without a provider; use Riverpod.
- Don’t treat `204` delete responses as JSON.
- Don’t show non-owner leakage; if delete returns 404, handle it as “not found” and refresh.

### Project Structure Notes

- Mobile files expected to touch/add:
  - `mobile/lib/features/library/screens/library_screen.dart` (update UI to list + empty state + refresh)
  - `mobile/lib/features/library/data/documents_api.dart` (add list + delete)
  - `mobile/lib/features/library/providers/` (add `document_list_provider.dart`)
  - `mobile/lib/features/library/widgets/` (add `document_card.dart`)
  - `mobile/lib/features/chat/screens/chat_screen.dart` (add minimal Hero target)
  - Tests: `mobile/test/widget/` (add new tests for list/empty/context menu)

## References

- Story requirements + BDD AC: [Source: _bmad-output/planning-artifacts/epics.md#Story 4.3: Flutter Document Library Screen]
- UX design patterns for document cards, empty states, and accessibility: [Source: _bmad-output/planning-artifacts/ux-design-specification.md]
- Frontend stack + rules (tokens, Riverpod, routes): [Source: _bmad-output/project-context.md]
- Backend list contract: [Source: backend/app/routers/documents.py]
- Backend schemas for list and document public model: [Source: backend/app/schemas/documents.py]
- Prior epic implementation patterns:
  - Document list backend story: [Source: _bmad-output/implementation-artifacts/4-1-document-library-api-endpoints.md]
  - Document delete backend story: [Source: _bmad-output/implementation-artifacts/4-2-document-deletion-with-cascading-data-cleanup.md]
- Existing upload UI and polling to integrate with the list:
  - [Source: mobile/lib/features/library/screens/library_screen.dart]
  - [Source: mobile/lib/features/library/providers/document_upload_controller.dart]
  - [Source: mobile/lib/features/library/widgets/document_upload_card.dart]

## Dev Agent Record

### Agent Model Used

GPT-5.3-Codex

### Debug Log References

- Auto-selected from `_bmad-output/implementation-artifacts/sprint-status.yaml` as the first `ready-for-dev` story in order: `4-3-flutter-document-library-screen`.
- Implemented in strict task order with red-green-refactor cycles:
  - Added failing unit tests for `DocumentsApi.getDocuments` and `DocumentsApi.deleteDocument`, then implemented methods and envelope model.
  - Added failing unit test for Riverpod list provider, then implemented `DocumentListNotifier` and `documentListProvider`.
  - Added failing widget tests for empty/list/navigation/long-press flows, then implemented `LibraryScreen` + `DocumentCard` + Hero target in `ChatScreen`.
- Fixed regressions uncovered by full-suite validation (`library_screen_upload_test.dart` and `widget_test.dart`) and re-ran all checks to green.

### Implementation Plan

- API layer:
  - Extend `DocumentsApi` for paginated list and delete operations.
  - Keep backend error-envelope mapping centralized in `LibraryApiError` mapping.
- State layer:
  - Add `DocumentListNotifier extends AsyncNotifier<DocumentListResponse>`.
  - Default fetch to `page=1, page_size=100`; expose `refresh()` and wire to pull-to-refresh.
- UI layer:
  - Build token-driven `DocumentCard` with frosted glass styling and status indicators.
  - Update `LibraryScreen` to show empty state, upload card, list via `ListView.builder`, and long-press actions.
  - Add delete confirm + metadata info flows and maintain existing upload FAB behavior.
- Navigation/animation:
  - Add Hero source on library cards and matching Hero target in chat screen.
- Validation:
  - Add/execute new unit + widget tests and run full `flutter test` + `flutter analyze`.

### Completion Notes List

- Added `DocumentListResponse` and `DocumentsApi.getDocuments/deleteDocument` with 204 handling and backend envelope error mapping.
- Added `DocumentListNotifier`/`documentListProvider` with async loading and `refresh()` wired to `RefreshIndicator`.
- Implemented full library UI states:
  - Empty state with "Upload your first PDF" CTA.
  - Upload card integration for in-flight uploads.
  - Document cards rendered with `ListView.builder`.
- Added `DocumentCard` with:
  - PDF icon, title ellipsis, metadata row, and status indicator mapping (ready/error/processing).
  - Frosted glass treatment (`ClipRRect` + `BackdropFilter`) using token colors/translucency.
  - Semantics labels and 44px+ touch targets.
- Implemented long-press context actions:
  - Delete with confirmation dialog and refresh.
  - Info dialog with full metadata and optional error text.
  - 404 handling surfaced as "Document not found." with list refresh.
- Added Hero transition from library card to chat screen via matching tags.
- Added new tests:
  - `documents_api_test.dart`
  - `document_list_provider_test.dart`
  - `library_screen_document_list_test.dart`
- Updated existing tests for deterministic behavior under animated/loading UI.
- Validation passed:
  - `flutter test` (full suite)
  - `flutter analyze`

### File List

- mobile/lib/features/library/models/document_upload_models.dart
- mobile/lib/features/library/data/documents_api.dart
- mobile/lib/features/library/providers/document_list_provider.dart
- mobile/lib/features/library/widgets/document_card.dart
- mobile/lib/features/library/screens/library_screen.dart
- mobile/lib/features/chat/screens/chat_screen.dart
- mobile/test/unit/documents_api_test.dart
- mobile/test/unit/document_list_provider_test.dart
- mobile/test/widget/library_screen_document_list_test.dart
- mobile/test/widget/library_screen_upload_test.dart
- mobile/test/widget_test.dart
- _bmad-output/implementation-artifacts/4-3-flutter-document-library-screen.md

## Change Log

- 2026-03-19: Implemented Story 4.3 end-to-end (API list/delete, Riverpod list state, full library UI, document card, delete/info flows, Hero transition, and tests).
- 2026-03-19: Ran full mobile validation (`flutter test`, `flutter analyze`) and fixed resulting deterministic test issues.
