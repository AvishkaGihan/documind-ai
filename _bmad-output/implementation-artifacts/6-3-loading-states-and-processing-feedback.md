# Story 6.3: Loading States and Processing Feedback

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a mobile user,
I want to see clear, informative loading states during all operations,
so that I always know the app is working and never feel stuck.

## Acceptance Criteria

1. **Given** the document library is loading
   **When** the API call is in progress
   **Then** skeleton shimmer cards (3 placeholder rectangles) are displayed

2. **Given** I am waiting for an AI answer
   **When** the question has been submitted
   **Then** the AI Typing Indicator (3 pulsing dots with #79C0FF glow) is shown in the chat

3. **Given** a document is being processed
   **When** I view the library
   **Then** the Processing Animation Widget shows multi-stage progress with descriptive icons and text

4. **And** all loading animations respect the system "Reduce Motion" preference (static alternatives provided)

5. **And** loading shimmer widgets use the `loading_shimmer.dart` shared component for consistency

## Tasks / Subtasks

- [x] Add shared loading shimmer component (AC: 1, 4, 5)
  - [x] Create `mobile/lib/shared/widgets/loading_shimmer.dart` as the single shared primitive for skeleton/shimmer rendering
  - [x] Ensure it uses `DocuMindTokens` colors only (no hardcoded colors) and `AppSpacing` for spacing
  - [x] Respect Reduce Motion:
    - [x] When `MediaQuery.disableAnimations == true`, render the skeleton statically (no animation controller / no ticker)
    - [x] When animations are enabled, use a subtle shimmer sweep suitable for dark mode
  - [x] Provide a minimal API that supports the Library use case without adding new design variants (e.g., `LoadingShimmer(child: ...)` or a `LoadingShimmerBox(...)`)

- [x] Replace library loading spinner with skeleton shimmer cards (AC: 1, 4, 5)
  - [x] Update `mobile/lib/features/library/screens/library_screen.dart` `documentsAsync.when(loading: ...)` branch
  - [x] Render exactly 3 placeholder cards that roughly match `DocumentCard` dimensions (icon + title line + metadata line)
  - [x] Keep the placeholder count at **exactly 3** across all breakpoints; layout may adapt (list vs grid) but count must not change
  - [x] Use `ListView`/`ListView.builder` and existing breakpoint padding logic (already in the screen)
  - [x] Guardrails:
    - [x] Do not add new routes/screens
    - [x] Keep RefreshIndicator behavior intact
    - [x] Keep the existing error UI and retry button intact

- [x] Ensure AI typing indicator is shown while waiting for answers (AC: 2, 4)
  - [x] Verify `mobile/lib/features/chat/screens/chat_screen.dart` shows `AiTypingIndicator` when a question is submitted and before/while tokens stream
  - [x] Verify Reduce Motion behavior remains correct (already uses `MediaQuery.disableAnimations`)
  - [x] Guardrail: do not introduce a new typing indicator widget; reuse the existing `AiTypingIndicator`

- [x] Implement / reuse Processing Animation Widget for processing documents in the library (AC: 3, 4)
  - [x] Identify current processing UI in:
    - [x] `mobile/lib/features/library/widgets/document_card.dart` (processing glow + status indicator)
    - [x] `mobile/lib/features/library/widgets/document_upload_card.dart` (multi-stage status text)
  - [x] Create a single reusable widget for processing feedback (suggested location: `mobile/lib/features/library/widgets/processing_animation.dart` or `.../processing_animation_widget.dart`) that:
    - [x] Takes the server status string (`extracting|chunking|embedding|processing|ready|error`) and optional metadata (like pageCount)
    - [x] Renders a small icon + descriptive text for each stage (no new theme colors)
    - [x] Optionally renders a lightweight animated affordance when animations are enabled (e.g., subtle indeterminate progress)
    - [x] Renders a static equivalent when Reduce Motion is enabled
  - [x] Update `DocumentCard` to show the processing widget inline when `document.status` is not `ready`/`error`
  - [x] Keep existing tap/long-press behavior and semantics intact

- [x] Tests (deterministic; avoid `pumpAndSettle()` timeouts) (AC: 1, 2, 3, 4, 5)
  - [x] Widget test: Library loading renders 3 skeleton cards (no CircularProgressIndicator)
    - [x] Prefer updating `mobile/test/widget/library_screen_document_list_test.dart` or add a focused new test file
  - [x] Widget test: Typing indicator appears when chat enters streaming state (if not already covered)
    - [x] Prefer extending `mobile/test/widget/chat_screen_streaming_test.dart`
  - [x] Widget test: Processing widget renders for a processing document in the library
    - [x] Prefer extending `mobile/test/widget/library_screen_document_list_test.dart` with a processing-status fixture
  - [x] Reduce Motion smoke test: pump key widgets with `MediaQueryData(disableAnimations: true)` and assert no exceptions

## Dev Notes

- **Primary goal:** Replace "mystery spinners" with informative, consistent feedback.
- **Do not reinvent:**
  - `AiTypingIndicator` already exists at `mobile/lib/features/chat/widgets/ai_typing_indicator.dart` and is already used in `ChatScreen`.
  - Processing stage strings already exist in `DocumentUploadCard` (`extracting`, `chunking`, `embedding`). Reuse the stage mapping rather than duplicating.

- **Likely files to touch:**
  - `mobile/lib/shared/widgets/loading_shimmer.dart` (new)
  - `mobile/lib/features/library/screens/library_screen.dart` (replace loading branch)
  - `mobile/lib/features/library/widgets/document_card.dart` (render processing widget inline)
  - `mobile/lib/features/library/widgets/document_upload_card.dart` (optional: reuse the shared processing widget)
  - `mobile/lib/features/chat/screens/chat_screen.dart` (verify typing indicator timing)

- **UX constraints:**
  - Exactly 3 skeleton shimmer cards during library loading.
  - All animations must respect Reduce Motion (`MediaQuery.disableAnimations`).

- **Architecture and codebase guardrails:**
  - Use Riverpod `AsyncValue.when()` patterns; do not move async work into widgets.
  - Use theme tokens only (`DocuMindTokens`, `AppSpacing`); do not hardcode new colors/spacings.
  - Keep builder-based lists for performance (`ListView.builder` / `GridView.builder`).

### Project Structure Notes

- Shared UI primitives belong under `mobile/lib/shared/widgets/` (this repo currently has `app_scaffold.dart` there).
- Prefer small, composable widgets (shimmer primitive + skeleton layout) instead of a large, highly-configurable skeleton system.

### Previous Story Intelligence (from 6.2)

- Connectivity/offline work introduced deterministic widget/unit test patterns; keep new widget tests bounded and avoid `pumpAndSettle()` timeouts.
- Prefer provider-driven UI state (Riverpod `AsyncValue.when()`) and keep loading UI purely presentational.
- Reduce Motion handling is already established via `MediaQuery.disableAnimations`; follow the same pattern for shimmer and processing UI.

### Git Intelligence Summary

- Recent story commits to mirror:
  - `e0316b0` (Story 6.2) touched providers/controllers, `LibraryScreen`, and added deterministic unit/widget tests.
  - `482f759` (Story 6.1) established breakpoint patterns in `responsive_breakpoints.dart` and updated `LibraryScreen` + `ChatScreen`.
- File touch patterns (keep consistent paths and naming):
  - `mobile/lib/features/library/screens/library_screen.dart`
  - `mobile/lib/features/library/widgets/document_upload_card.dart`
  - `mobile/lib/features/library/widgets/document_card.dart`
  - `mobile/test/widget/library_screen_document_list_test.dart`
  - `mobile/test/widget/chat_screen_streaming_test.dart`

### References

- Story definition and AC:
  - `_bmad-output/planning-artifacts/epics.md` → "Epic 6" → "Story 6.3: Loading States and Processing Feedback"

- Loading and UX patterns:
  - `_bmad-output/planning-artifacts/ux-design-specification.md` → "Processing Wait States" + "Interaction Patterns" (skeletal loading, typing indicator)

- Architecture guidance:
  - `_bmad-output/planning-artifacts/architecture.md` → "Loading State Patterns" (shimmer skeleton for lists; pulsing dots for typing)

- Project-wide guardrails:
  - `_bmad-output/project-context.md` → "Flutter (Frontend)" rules (tokens, Riverpod, deterministic tests)

- Previous story learnings (avoid repeating mistakes):
  - `_bmad-output/implementation-artifacts/6-2-offline-caching-and-upload-queuing.md` → deterministic testing notes + provider patterns
  - `_bmad-output/implementation-artifacts/6-1-responsive-mobile-chat-and-library-layout.md` → breakpoint patterns + reduce-motion handling

## Dev Agent Record

### Agent Model Used

GPT-5.3-Codex

### Debug Log References

- `flutter analyze`
- `flutter test test/widget/library_screen_document_list_test.dart test/widget/chat_screen_streaming_test.dart`
- `flutter test`

### Completion Notes List

- Added shared `LoadingShimmer` primitives with a no-ticker reduce-motion path and a `LibraryDocumentSkeletonCard` layout.
- Replaced Library loading spinner with exactly three shimmer skeleton placeholders while preserving existing refresh/error behavior.
- Added reusable `ProcessingAnimation` widget with stage-specific icon/text mapping and reduce-motion static fallback.
- Updated `DocumentCard` and `DocumentUploadCard` to use the shared processing feedback component.
- Verified `ChatScreen` typing indicator behavior remained intact and added reduce-motion coverage in widget tests.
- Updated theme splash behavior to `InkRipple` to keep Material 3 interactions stable in widget test runtime.
- Validation passed: `flutter analyze` and full `flutter test` in `mobile/`.

### File List

- `mobile/lib/shared/widgets/loading_shimmer.dart`
- `mobile/lib/features/library/widgets/processing_animation.dart`
- `mobile/lib/features/library/screens/library_screen.dart`
- `mobile/lib/features/library/widgets/document_card.dart`
- `mobile/lib/features/library/widgets/document_upload_card.dart`
- `mobile/lib/core/theme/app_theme.dart`
- `mobile/test/widget/library_screen_document_list_test.dart`
- `mobile/test/widget/chat_screen_streaming_test.dart`
- `_bmad-output/implementation-artifacts/6-3-loading-states-and-processing-feedback.md`
- `_bmad-output/implementation-artifacts/sprint-status.yaml`

## Change Log

- 2026-03-21: Implemented Story 6.3 loading/processing feedback UI, added deterministic widget coverage, and validated with full mobile test/analyze suite.
