# Story 6.2: Offline Caching and Upload Queuing

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a mobile user,
I want to view my document library and chat history even when offline, and have uploads queued for later,
so that I can use the app during commutes with intermittent connectivity.

## Acceptance Criteria

1. **Given** I have previously loaded my document library and chat history
   **When** I lose network connectivity
   **Then** the document library (titles, metadata, status) is displayed from local cache (SQLite or Hive)
   **And** previous chat conversations are viewable from local cache

2. **Given** I am offline and try to ask a question
   **When** I tap Send
   **Then** a clear message is shown: "Q&A requires an internet connection. Your question will be sent when connectivity restores." (or equivalent)

3. **Given** I select a PDF to upload while offline
   **When** I choose the file
   **Then** the upload is queued locally with a visual indicator ("Queued — will upload when online")
   **And** when connectivity restores, the queued upload automatically begins and the UI updates

## Tasks / Subtasks

- [x] Add connectivity monitoring as a Riverpod dependency (AC: 1, 2, 3)
  - [x] Add `connectivity_plus: ^7.0.0` to `mobile/pubspec.yaml`
  - [x] Create a small connectivity abstraction under `mobile/lib/core/networking/` (or `mobile/lib/core/` if conventions demand) that exposes:
    - [x] a synchronous "is online" helper for controllers (best-effort)
    - [x] a stream/provider of connectivity changes so queues can flush when connectivity returns
  - [x] Guardrail: connectivity type is not the same as internet reachability; queue flushing must still tolerate request failures and back off (do not assume online == request succeeds)

- [x] Implement local cache persistence for library + chat + queues (AC: 1, 3)
  - [x] Choose and implement one local storage mechanism: **Hive** (recommended for MVP) OR SQLite
    - [x] If Hive: add `hive: ^2.2.3` and `hive_flutter: ^1.1.0` (and run `flutter pub get`)
  - [x] Create a minimal local cache module (new folder) at `mobile/lib/core/storage/` with a single responsibility: read/write cached JSON payloads and queued items
    - [x] Cache keys MUST be namespaced per user to prevent cross-account data leakage on shared devices (e.g., use authenticated user id/email hash if available from auth state)
    - [x] Store:
      - [x] document list cache (document id/title/status/file size/page count/created_at)
      - [x] per-document chat message cache (the message list returned by bootstrap)
      - [x] queued uploads (file path + filename + size + enqueuedAt)
      - [x] queued questions (documentId + question + enqueuedAt) — required to make the "will be sent" message true
  - [x] Add a simple cache metadata envelope (e.g., `cachedAt` timestamp and `schemaVersion`) so future migrations are possible

- [x] Make Document Library resilient offline using the cache (AC: 1)
  - [x] Update `mobile/lib/features/library/providers/document_list_provider.dart`:
    - [x] On successful API fetch, persist the list to the local cache
    - [x] When API fetch fails with a network-style error, load last cached document list and return it (if present)
    - [x] When offline at startup, load cached list instead of erroring
  - [x] UX guardrail: do not add new screens; the existing list UI should render normally from cached data

- [x] Make Chat history viewable offline using cache (AC: 1)
  - [x] Update `mobile/lib/features/chat/data/chat_api.dart` / `mobile/lib/features/chat/providers/chat_controller.dart` flow so that:
    - [x] When online bootstrap succeeds, cache the message list per document
    - [x] When offline, `ChatController.load(documentId)` loads cached messages for that document and populates the chat UI
  - [x] Ensure cached messages preserve:
    - [x] message order
    - [x] roles (user/assistant)
    - [x] citations (page number + excerpt)

- [x] Queue questions while offline and flush on reconnect (AC: 2)
  - [x] Update `mobile/lib/features/chat/providers/chat_controller.dart` `send()`:
    - [x] If offline, do not call streaming endpoint
    - [x] Persist the question to the "queued questions" store
    - [x] Show the required user-facing message (SnackBar or in-chat system message) without introducing a new page/modal
  - [x] Add a small queue flush routine:
    - [x] Flush when connectivity changes to online (best effort)
    - [x] Also flush when the user opens the chat (so reconnection while backgrounded still works)
    - [x] Send queued questions in FIFO order, one at a time, using the existing streaming flow
    - [x] If a flush fails, leave queued items in place and retry on next online signal

- [x] Queue uploads while offline and auto-start on reconnect (AC: 3)
  - [x] Extend the upload UI state model in `mobile/lib/features/library/models/document_upload_models.dart`:
    - [x] Add a new phase to `UploadCardPhase` such as `queued`
  - [x] Update `mobile/lib/features/library/providers/document_upload_controller.dart`:
    - [x] When offline, selecting a PDF enqueues it instead of uploading
    - [x] Update `DocumentUploadState` so the library shows an upload card with the queued indicator
    - [x] On reconnect (or on app resume + online), automatically dequeue and upload the next queued item
    - [x] After each successful upload:
      - [x] refresh the document list provider (so server-side document appears)
      - [x] begin polling for processing status as currently implemented
  - [x] Update `mobile/lib/features/library/widgets/document_upload_card.dart` to display queued state text: "Queued — will upload when online"
  - [x] Guardrail: do not implement background uploading while the app is terminated; best-effort flush while the app is in foreground is acceptable unless the architecture already includes background task infra

- [x] Tests (must be deterministic; avoid `pumpAndSettle()` timeouts) (AC: 1, 2, 3)
  - [x] Unit tests for caching behavior:
    - [x] `document_list_provider_test.dart`: when API throws `NETWORK_ERROR`, provider returns cached list
    - [x] new test for chat offline bootstrap: controller loads cached messages when offline
  - [x] Unit tests for upload queue:
    - [x] Extend `document_upload_controller_test.dart` to cover offline enqueue and online flush (use a fake connectivity provider + fake local storage)
  - [x] Widget tests (minimal):
    - [x] Library shows queued upload indicator when upload is enqueued
    - [x] Chat shows offline Q&A message when send is tapped offline

## Dev Notes

- **Primary files to touch (existing):**
  - `mobile/lib/features/library/providers/document_list_provider.dart` (persist + fallback to cache)
  - `mobile/lib/features/library/providers/document_upload_controller.dart` (enqueue + flush)
  - `mobile/lib/features/library/models/document_upload_models.dart` (add queued state + any queued model)
  - `mobile/lib/features/library/widgets/document_upload_card.dart` (render queued indicator)
  - `mobile/lib/features/chat/providers/chat_controller.dart` (offline bootstrap + question queue)
  - `mobile/lib/features/chat/data/chat_api.dart` (may stay unchanged; prefer keeping caching in controller/repository layer)

- **New internal module (recommended):**
  - `mobile/lib/core/storage/` (local cache + queues)
  - `mobile/lib/core/networking/` additions for connectivity state (existing folder already contains `dio_provider.dart`)

- **Consistency rules to preserve (project-wide):**
  - Riverpod async state should stay in providers/controllers; avoid moving network I/O into widgets.
  - Error UI uses SnackBars for actionable failures (see `LibraryScreen` pattern).
  - Do not store JWT tokens outside `flutter_secure_storage`.
  - Use existing theme tokens only (no hardcoded colors/spacing).

- **Data model note:**
  - Current models are hand-written immutable classes (not fully `@freezed` yet in all features). Keep the same style unless the repo already migrated a feature to `freezed`.

### Project Structure Notes

- Avoid adding new pages/routes; implement within existing Library and Chat flows.
- Keep caching isolated behind a small storage abstraction so controllers can be tested with fakes.
- If a shared key-namespacing helper is needed (for per-user cache separation), place it under `mobile/lib/core/` (e.g., `core/storage/cache_keys.dart`) and keep it purely computational.

### References

- Story definition and AC:
  - `_bmad-output/planning-artifacts/epics.md` → "Epic 6" → "Story 6.2: Offline Caching and Upload Queuing"

- Offline capabilities and local storage guidance:
  - `_bmad-output/planning-artifacts/prd.md` → "Offline Capabilities" + "Technical Architecture Considerations" (Local Storage: SQLite or Hive)
  - `_bmad-output/planning-artifacts/ux-design-specification.md` → "Platform Strategy" (Offline Support: cached library + chat history; Q&A requires network)

- Project rules and guardrails:
  - `_bmad-output/project-context.md` → "Flutter (Frontend)" rules (Riverpod, tokens, testing guidance)

- Prior story patterns to reuse:
  - `_bmad-output/implementation-artifacts/6-1-responsive-mobile-chat-and-library-layout.md` → responsive helper placement + deterministic widget testing guidance

- Package references (web research):
  - https://pub.dev/packages/connectivity_plus (current version shown: 7.0.0)
  - https://pub.dev/packages/hive (current version shown: 2.2.3)
  - https://pub.dev/packages/hive_flutter (current version shown: 1.1.0)

## Dev Agent Record

### Agent Model Used

GPT-5.3-Codex

### Debug Log References

- `flutter pub get`
- `flutter test`
- `flutter analyze`

### Completion Notes List

- Added connectivity monitoring abstraction with sync online state and connectivity change stream provider.
- Implemented local cache and queue storage module with namespaced keys, metadata envelope, and cached document/chat payload persistence.
- Updated document list provider to cache successful server fetches and fall back to cache on offline or network-style errors.
- Updated chat controller to support offline chat bootstrap, queued question persistence, FIFO flush on reconnect/open-chat, and retry backoff.
- Updated upload controller, upload state model, and upload card UI to support offline queueing and reconnect/resume upload flush.
- Added deterministic unit and widget tests for cache fallback, offline chat bootstrap, upload queue behavior, queued upload UI indicator, and offline chat send message.
- Verified mobile quality gates with full test suite and analyzer.

### File List

- mobile/pubspec.yaml
- mobile/lib/main.dart
- mobile/lib/core/networking/connectivity_provider.dart
- mobile/lib/core/storage/local_cache_store.dart
- mobile/lib/features/library/providers/document_list_provider.dart
- mobile/lib/features/chat/providers/chat_controller.dart
- mobile/lib/features/library/providers/document_upload_controller.dart
- mobile/lib/features/library/models/document_upload_models.dart
- mobile/lib/features/library/widgets/document_upload_card.dart
- mobile/lib/features/library/screens/library_screen.dart
- mobile/test/unit/document_list_provider_test.dart
- mobile/test/unit/document_upload_controller_test.dart
- mobile/test/unit/chat_controller_test.dart
- mobile/test/widget/library_screen_upload_test.dart
- mobile/test/widget/chat_screen_streaming_test.dart
- mobile/test/widget/library_screen_document_list_test.dart

## Change Log

- 2026-03-20: Implemented offline caching for library/chat, offline upload and question queues, reconnect/resume flush behavior, and full test/analyzer validation for Story 6.2.

