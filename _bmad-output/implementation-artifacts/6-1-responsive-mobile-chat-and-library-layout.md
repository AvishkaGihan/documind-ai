# Story 6.1: Responsive Mobile Chat and Library Layout

Status: done

## Story

As a mobile user,
I want the app to look and feel great on any phone or tablet screen size,
so that I have a premium experience regardless of my device.

## Acceptance Criteria

1. **Given** I am using a small phone (320px width)
   **When** I use the app
   **Then** all layouts adapt with compact spacing, readable font sizes, and no content clipping or overflow

2. **Given** I am using a standard phone (375px–427px)
   **When** I use the app
   **Then** the default layout applies with standard spacing and component sizing

3. **Given** I am using a tablet in portrait (768px+)
   **When** I use the app
   **Then** the document library shows a two-column grid and the chat view optionally shows a split layout

4. **And** all screens use `MediaQuery` and `LayoutBuilder` for responsive behavior

5. **And** no fixed pixel widths are used — layouts use `Flexible`, `Expanded`, and percentage-based sizing

6. **And** the chat interface scroll performance is consistently 60fps

## Tasks / Subtasks

- [x] Implement breakpoint-driven responsive layout decisions (AC: 1, 2, 3, 4)
  - [x] Use `MediaQuery.sizeOf(context)` (and/or `LayoutBuilder` constraints) to classify screen width into: small phone (320–374), standard phone (375–427), large phone (428–767), tablet portrait (768–1023), tablet landscape (1024+)
  - [x] Ensure the responsive logic is applied in both primary screens touched by this story: library and chat
  - [x] Prefer `MediaQuery` specific getters (e.g. `MediaQuery.sizeOf`) over `MediaQuery.of` when only a subset is needed (avoid unnecessary rebuilds)

- [x] Make Document Library responsive, including tablet 2-column grid (AC: 1, 2, 3, 4, 5)
  - [x] Update `mobile/lib/features/library/screens/library_screen.dart` to use `LayoutBuilder` to switch between:
    - [x] Phone: single-column list layout
    - [x] Tablet portrait+: two-column grid layout
  - [x] Ensure the list/grid uses builder variants for performance (`ListView.builder` / `GridView.builder`) and to align with project rules for dynamic data
  - [x] Adjust outer padding / spacing per breakpoint using existing spacing tokens (`AppSpacing`) rather than hardcoded values
    - [x] Small phone: compact padding (e.g., `md`/`sm` instead of `lg` where feasible)
    - [x] Standard phone: keep current default spacing
  - [x] Verify long titles and metadata never overflow at 320px width (use `Flexible`/`Expanded`, ellipsis, wrapping where appropriate)
  - [x] Keep current UX behavior (search, sort, upload card, empty state) functionally identical; only layout/spacing should change

- [x] Add tablet split-view option to Chat (AC: 3, 4, 5)
  - [x] Update `mobile/lib/features/chat/screens/chat_screen.dart` to use `LayoutBuilder` and render a split layout at tablet widths (768px+), aligned with UX spec:
    - [x] Left pane: document list / selector (ready docs) to switch documents
    - [x] Right pane: existing chat view + input bar
  - [x] Keep existing bottom-sheet document selector for phones (and optionally for tablets as an alternative entry point)
  - [x] Ensure the split view does not introduce new routes/pages; it should be an adaptive layout for the existing chat screen
  - [x] Ensure no fixed pixel widths are introduced; use `Flexible`/`Expanded` and proportional `flex` values for pane sizing

- [x] Ensure 60fps chat scroll performance (AC: 6)
  - [x] Profile/inspect the message list for rebuild/animation hotspots (Flutter DevTools)
  - [x] Avoid per-item animations that retrigger during scrolling or frequent rebuilds; ensure any “message arrival” animation only applies to newly inserted items
  - [x] Respect “Reduce Motion” by disabling non-essential chat animations when `MediaQuery.disableAnimations` is true

- [x] Update/add widget tests for key breakpoints (AC: 1, 2, 3)
  - [x] Library:
    - [x] Add a test that pumps `LibraryScreen` at 320px width and asserts no overflow exceptions and that the single-column layout renders
    - [x] Add a test that pumps `LibraryScreen` at 800px width and asserts the grid layout is used (and that document cards still render)
  - [x] Chat:
    - [x] Add a test that pumps `ChatScreen` at 800px width and asserts the split layout is present (document list pane + chat pane)
  - [x] Use bounded pumping (avoid `pumpAndSettle()` timeouts in TextField/scrolling flows)

## Dev Notes

- **Mobile target files (likely):**
  - `mobile/lib/features/library/screens/library_screen.dart`
  - `mobile/lib/features/chat/screens/chat_screen.dart`
  - Potentially: reuse existing library models/providers (`documentListProvider`) for the tablet chat left pane

- **Design system constraints:**
  - Use `DocuMindTokens` theme extension for colors and typography; do not introduce new color values.
  - Use `AppSpacing` constants for padding/spacing; do not hardcode new spacing numbers.

- **State management constraints:**
  - Do not move async fetching into widgets; keep using Riverpod providers (`documentListProvider`, `chatControllerProvider`).

- **Accessibility & responsive considerations:**
  - Ensure touch targets remain at least 44×44 for interactive elements.
  - Verify text scaling up to 200% does not clip key UI (especially app bar title and document list tiles).

### Project Structure Notes

- This story should not require new pages/routes.
- If a shared breakpoint helper is created, prefer placing it under `mobile/lib/core/` (or the existing core layout/theme area) and keep it minimal and purely computational.

### References

- Story definition and acceptance criteria:
  - `_bmad-output/planning-artifacts/epics.md` → "Epic 6" → "Story 6.1: Responsive Mobile Chat and Library Layout"

- Responsive breakpoints and tablet split-view guidance:
  - `_bmad-output/planning-artifacts/ux-design-specification.md` → "Responsive Design & Accessibility" → "Breakpoint Strategy" + "Tablet Strategy (Secondary)"

- Architecture and enforcement guidelines:
  - `_bmad-output/planning-artifacts/architecture.md` → "Enforcement Guidelines" (design tokens; Riverpod async patterns)
  - `_bmad-output/project-context.md` → "Flutter (Frontend)" rules (tokens, ListView.builder guidance)

- Flutter API docs (web research):
  - https://api.flutter.dev/flutter/widgets/MediaQuery-class.html
  - https://api.flutter.dev/flutter/widgets/LayoutBuilder-class.html
  - https://api.flutter.dev/flutter/widgets/MediaQueryData/disableAnimations.html

## Dev Agent Record

### Agent Model Used

GPT-5.3-Codex

### Debug Log References

- Added red-phase tests first and verified failures for missing responsive layout keys.
- Validation commands:
  - `flutter test mobile/test/widget/library_screen_document_list_test.dart mobile/test/widget/chat_document_switching_test.dart mobile/test/widget/chat_screen_streaming_test.dart`
  - `flutter test`
  - `flutter analyze`

### Completion Notes List

- Added shared responsive breakpoint classifier in `mobile/lib/core/layout/responsive_breakpoints.dart` with small/standard/large phone and tablet classes.
- Refactored `LibraryScreen` content rendering to adaptive list/grid behavior using `MediaQuery.sizeOf` + `LayoutBuilder`, with compact spacing on small phones and 2-column tablet grid.
- Kept library behavior intact (search, sort, upload, empty/no-results, navigation), while switching to builder-based list/grid rendering.
- Added tablet split layout to `ChatScreen` with left ready-document pane and right chat pane using `Flexible` flex ratios; retained existing bottom-sheet selector flow.
- Optimized chat message animation behavior to animate only newly inserted messages and respect reduce-motion (`MediaQuery.disableAnimations`) for message and auto-scroll transitions.
- Added/updated responsive widget tests for 320px library list behavior, 800px library grid behavior, and 800px chat split-view behavior with bounded pumping.

### File List

- `mobile/lib/core/layout/responsive_breakpoints.dart`
- `mobile/lib/features/library/screens/library_screen.dart`
- `mobile/lib/features/chat/screens/chat_screen.dart`
- `mobile/test/widget/library_screen_document_list_test.dart`
- `mobile/test/widget/chat_document_switching_test.dart`
- `_bmad-output/implementation-artifacts/sprint-status.yaml`
- `_bmad-output/implementation-artifacts/6-1-responsive-mobile-chat-and-library-layout.md`

## Change Log

- 2026-03-20: Implemented responsive library/chat layouts, reduce-motion aware chat animation updates, and breakpoint widget coverage for Story 6.1.
