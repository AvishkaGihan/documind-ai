# Story 4.4: Document Library Search and Filter

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a mobile user,
I want to search and filter my document library,
so that I can quickly find specific documents when I have many uploaded.

## Acceptance Criteria

1. **Given** I am on the Document Library screen
   **When** I tap the search icon
   **Then** a search text field appears at the top of the screen

2. **Given** I type a search query
   **When** I enter text in the search field
   **Then** the document list filters in real-time to show only documents whose titles match the query (case-insensitive)
   **And** if no documents match, the "No documents match your search" empty state is displayed with a "Clear search" action

3. **Given** I want to sort my documents
   **When** I access the sort options
   **Then** I can sort by: Date (newest first, default), Name (alphabetical), Status (processing first)

## Tasks / Subtasks

- [x] Add search UI entrypoint (AC: #1)
  - [x] Add a search action in the Library `AppBar` (IconButton)
  - [x] When tapped, show a search text field at the top of the screen content (not a separate page)
  - [x] Provide an explicit way to exit/clear search (either an X in the field or a "Cancel"/"Clear" action)

- [x] Implement real-time, case-insensitive filtering (AC: #2)
  - [x] Filter the already-loaded document list in memory (max 100 docs/user; no per-keystroke API calls)
  - [x] Matching rule: `document.title` contains query substring, case-insensitive
  - [x] Ensure filtering applies only to the documents list (keep the upload card behavior unchanged)
  - [x] When query is non-empty and there are zero matches, show the "No documents match your search" empty state with a clear action

- [x] Add sort options UI + behavior (AC: #3)
  - [x] Provide a sort affordance (e.g., sort icon in `AppBar`) that opens a bottom sheet or menu
  - [x] Sorting modes:
    - [x] Date (default): newest first (`createdAt` descending)
    - [x] Name: alphabetical by title (case-insensitive)
    - [x] Status: processing first (see status grouping guidance below)
  - [x] Sorting must compose with search filtering (filter first, then sort)

- [x] Preserve accessibility + design-system constraints (AC: #1–#3)
  - [x] No hardcoded colors/spacing/fonts; use `DocuMindTokens` + `AppSpacing`
  - [x] Ensure search field and sort controls meet 44×44pt minimum touch targets
  - [x] Add `Semantics` labels for search and sort actions

- [x] Add/update widget tests (AC: #1–#3)
  - [x] Extend `mobile/test/widget/library_screen_document_list_test.dart` (preferred) or add a new widget test file under `mobile/test/widget/`
  - [x] Cover at minimum:
    - [x] Search icon reveals the search field
    - [x] Typing filters items in real-time and is case-insensitive
    - [x] No-results UI shows the exact message and the clear action restores the full list
    - [x] Sort by Name produces deterministic ordering
    - [x] Sort by Status puts processing documents first

## Dev Notes

### Do not reinvent patterns (critical)

- Keep using the existing `documentListProvider` and `DocumentListNotifier` for async loading.
- Do not add new backend endpoints; this is a pure mobile/library UX enhancement.
- Keep the existing upload flow and upload card placement (upload card is currently rendered as the first item when active).

### Where to implement (expected files)

- Mobile UI:
  - `mobile/lib/features/library/screens/library_screen.dart`
- Tests:
  - `mobile/test/widget/library_screen_document_list_test.dart`

### Suggested state approach (choose simplest that fits existing patterns)

- Option A (minimal, recommended): keep `LibraryScreen` as a `ConsumerWidget` and manage ephemeral UI state with Riverpod `StateProvider`s for:
  - `isSearching` (bool)
  - `searchQuery` (String)
  - `sortMode` (enum/string)

- Option B: convert `LibraryScreen` to `ConsumerStatefulWidget` and keep search query + sort mode in local state.

Either option is acceptable as long as:
- async document loading remains provider-driven (no fetching in `build()`), and
- the UI remains token-driven.

### Status grouping for "Status (processing first)" sort

Reuse the same conceptual grouping already encoded in `DocumentCard`:
- `ready` = ready
- `error` = error
- everything else = processing

For the Status sort, group ordering should be:
1. processing
2. ready
3. error

Within each group, keep a deterministic secondary sort (recommend: `createdAt` desc, then `id` asc).

### UI behavior details (avoid UX drift)

- "Search text field appears at the top of the screen": implement as a top-of-body element above the list.
- "Filters in real-time": update filtered list on every keystroke (debounce not required).
- "Clear search" action:
  - Clears the query and restores the full list.
  - If you also collapse the field, keep behavior simple and explicit (no hidden state).

### Testing gotchas

- Prefer bounded `pump(Duration(...))` loops (like the existing `pumpFrames`) over `pumpAndSettle()` to avoid timeouts from animations/glow effects.
- Add stable Keys for testability (recommended):
  - `Key('library-search-button')`
  - `Key('library-search-field')`
  - `Key('library-clear-search')`
  - `Key('library-sort-button')`

## Project Structure Notes

- This story should only touch the Library screen/search/sort behavior and related widget tests.
- Do not introduce new shared UI components or new pages; keep UX strictly within the Library tab.

### References

- Story requirements + BDD AC: [Source: _bmad-output/planning-artifacts/epics.md#Story 4.4: Document Library Search and Filter]
- UX guidance (empty states, accessibility, token usage): [Source: _bmad-output/planning-artifacts/ux-design-specification.md]
- Mobile guardrails (Riverpod, tokens, routing): [Source: _bmad-output/project-context.md]
- Current Library implementation (baseline): [Source: mobile/lib/features/library/screens/library_screen.dart]
- Previous story patterns for Library UI/tests: [Source: _bmad-output/implementation-artifacts/4-3-flutter-document-library-screen.md]

## Dev Agent Record

### Agent Model Used

GPT-5.3-Codex

### Debug Log References

- Auto-selected from `_bmad-output/implementation-artifacts/sprint-status.yaml` as the first `ready-for-dev` story in order: `4-4-document-library-search-and-filter`.
- Loaded project guardrails from `_bmad-output/project-context.md` and story-specific implementation constraints from this story's Dev Notes.
- Updated sprint status to `in-progress` before development began and to `review` after completion.
- Validation commands run:
  - `flutter test test/widget/library_screen_document_list_test.dart`
  - `flutter test`
  - `flutter analyze`

### Completion Notes List

- Extracted Story 4.4 acceptance criteria and mapped directly to current `LibraryScreen` structure.
- Anchored implementation guidance to existing Epic 4 patterns (Riverpod providers, token-driven UI, bottom-sheet usage, widget test style).
- Added Library `AppBar` search and sort actions with semantics and stable test keys.
- Implemented top-of-body search field with explicit clear and cancel behavior.
- Implemented in-memory, real-time, case-insensitive title filtering with no per-keystroke API calls.
- Added no-results state message: `No documents match your search` with `Clear search` action.
- Added sort modes for Date, Name, and Status with deterministic tie-breaking.
- Kept upload card behavior unchanged while applying filtering/sorting only to document list items.
- Extended widget tests to cover search reveal, case-insensitive filtering, no-results clear behavior, and Name/Status sort ordering.
- Full mobile test suite and analyzer passed after implementation.

### File List

- mobile/lib/features/library/screens/library_screen.dart
- mobile/test/widget/library_screen_document_list_test.dart
- _bmad-output/implementation-artifacts/4-4-document-library-search-and-filter.md
- _bmad-output/implementation-artifacts/sprint-status.yaml

## Change Log

- 2026-03-19: Implemented document library search and sort UX (in-memory filtering, composable sorting, no-results clear action), added accessibility/test keys, and expanded widget tests for AC coverage.
