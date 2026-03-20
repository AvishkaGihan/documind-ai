# Story 5.5: Conversation Management and Document Switching

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a mobile user,
I want to switch between documents' conversations and start new conversations,
so that I can work with multiple documents without losing context.

## Acceptance Criteria

1. **Given** I am in a chat with Document A
   **When** I tap the document selector in the top bar
   **Then** a bottom sheet shows all my "ready" documents, and I can tap to switch to Document B
   **And** Document B's chat loads its own conversation history (context isolation — no bleed from Document A)

2. **Given** I want a fresh start with the current document
   **When** I tap "New Conversation"
   **Then** a confirmation is shown, and upon confirming, the chat clears and a new conversation session is created
   **And** the previous conversation is preserved and accessible from the conversation history

3. **Given** I return to a document I previously chatted with
   **When** I open the chat for that document
   **Then** my previous conversation messages are loaded and displayed in the chat

## Tasks / Subtasks

- [x] Add document selector entry point in the Chat top bar (AC: 1)
  - [x] Make the selector discoverable from `ChatScreen` app bar (e.g., tappable title row and/or trailing icon)
  - [x] Ensure it opens a bottom sheet (not a new page) and respects safe areas

- [x] Implement "Switch document" bottom sheet using existing Library data (AC: 1)
  - [x] Source of truth for documents should reuse existing API/provider patterns:
    - [x] Prefer `documentListProvider` and refresh it when the sheet opens (avoid duplicate networking)
    - [x] Filter to `status == "ready"` only (per AC wording)
  - [x] Render a simple list of ready documents (title is required; metadata optional but keep minimal)
  - [x] On selecting a document:
    - [x] Navigate to `/chat/:documentId` using `go_router` (e.g., `context.go('/chat/$id')`)
    - [x] Close the bottom sheet
    - [x] Ensure the chat loads the selected document’s messages and title

- [x] Ensure strict per-document context isolation when switching (AC: 1)
  - [x] When the active `documentId` changes, reset chat UI state that must not carry over:
    - [x] message list
    - [x] in-flight answer state (`isStreaming`, `inFlightAnswerId`)
    - [x] citation expansion state + excerpts map
    - [x] draft input text
  - [x] Use the existing bootstrap approach (Story 5.4):
    - [x] `GET /api/v1/documents/{document_id}/conversations/latest/messages` to load the active/latest conversation messages
    - [x] Document title via `DocumentsApi.getDocumentById`

- [x] Add "New Conversation" action with confirmation (AC: 2)
  - [x] Add an entry point in the chat UI (keep it minimal; must be reachable from Chat screen)
  - [x] Confirmation must be a dialog (per UX patterns for confirmations)
  - [x] On confirm:
    - [x] Call `POST /api/v1/documents/{document_id}/conversations/new`
    - [x] Clear the chat immediately (optimistic), then re-bootstrap to show the empty latest conversation
    - [x] Show a lightweight info SnackBar: "Conversation cleared." (or similar)
  - [x] Ensure `/ask` continues to work without passing `conversation_id` (backend uses latest conversation semantics)

- [x] Conversation history access (minimal but real) (AC: 2)
  - [x] Problem to solve: after starting a new conversation, the prior conversation’s messages must remain reachable in UI.
  - [x] Backend (minimal additions; keep patterns consistent with existing 5.3/5.4 endpoints):
    - [x] Add `GET /api/v1/documents/{document_id}/conversations` to list conversation sessions for the document (auth + ownership enforced)
    - [x] Add `POST /api/v1/documents/{document_id}/conversations/{conversation_id}/activate` to make a prior conversation the "latest" (recommended implementation: reuse repository `touch_conversation(...)` so the chosen conversation becomes latest by `updated_at`)
    - [x] Keep response envelope consistent with project list response format (`items`, `total`, `page`, `page_size`)
  - [x] Mobile (minimal UI surface):
    - [x] Provide a chat-accessible entry point (e.g., overflow action) named "Conversation history"
    - [x] Show a bottom sheet listing conversations (newest first) with a basic label (e.g., timestamp and/or last message preview)
    - [x] Selecting a conversation should:
      - [x] Call the activate endpoint
      - [x] Re-bootstrap chat (`latest/messages`) so the selected conversation appears

- [x] Testing requirements (AC: 1–3)
  - [x] Backend integration tests for new endpoints:
    - [x] list conversations: auth required, ownership enforced, sorted newest first
    - [x] activate conversation: auth required, ownership enforced, updates which conversation is returned by `latest/messages`
  - [x] Mobile widget tests (deterministic):
    - [x] opening document selector bottom sheet shows ready documents
    - [x] switching document triggers reload and updates title/messages
    - [x] "New Conversation" confirmation clears chat state and calls API
  - [x] Guardrail: avoid `pumpAndSettle()` timeouts around TextField/caret and animations; use bounded `pump(const Duration(...))` steps

## Dev Notes

### Developer context (read this first)

Story 5.4 already delivered the Chat screen and a backend "latest messages" bootstrap endpoint, specifically to avoid needing the client to manage `conversation_id` for the happy path.

Story 5.5 builds on that:
- Add in-chat document switching via a top-bar selector + bottom sheet.
- Add "New Conversation" (clears current chat + creates a new backend conversation).
- Provide minimal but real access to older conversations so "preserved" is true.

### What already exists (reuse; do not reinvent)

**Mobile:**
- Routing already supports document switching via route parameter changes:
  - `/chat/:documentId` route: `mobile/lib/router.dart`
  - `ChatScreen.didUpdateWidget` already reloads when `documentId` changes
- Chat bootstrap and streaming:
  - `mobile/lib/features/chat/data/chat_api.dart` uses:
    - `GET /api/v1/documents/{document_id}/conversations/latest/messages`
    - `POST /api/v1/documents/{document_id}/ask` SSE stream
  - `mobile/lib/features/chat/providers/chat_controller.dart` holds chat state and streaming pipeline
- Library list provider:
  - `mobile/lib/features/library/providers/document_list_provider.dart` loads the document list

**Backend:**
- Conversation primitives and message retrieval exist:
  - `POST /api/v1/documents/{document_id}/conversations/new`
  - `GET /api/v1/documents/{document_id}/conversations/latest/messages`
  - `GET /api/v1/documents/{document_id}/conversations/{conversation_id}/messages`
- Repository helper exists for "activate by touch":
  - `backend/app/repositories/conversation_repository.py::touch_conversation`

### Architecture + project guardrails (must follow)

- Flutter:
  - Use Riverpod `AsyncNotifier` patterns for async state; don’t introduce `setState()`-driven networking.
  - Do not hardcode colors/spacing/fonts; use `DocuMindTokens` + `AppSpacing`.
  - Keep new UI scoped to `mobile/lib/features/chat/` as much as possible.
- Backend:
  - Keep routers thin; add business logic in `ConversationService`, DB access in repositories.
  - Enforce ownership: every new conversation/history endpoint must validate `{user_id, document_id}` scope.
  - Preserve error response shape (`detail.code`, `detail.message`, `detail.field`).

### UX requirements (must follow)

- Document selector is a bottom sheet triggered from the Chat top bar.
- "New Conversation" requires confirmation.
- Use SnackBars for non-critical feedback.

### Scope boundaries (avoid scope creep)

- Do not add cross-document conversation memory.
- Do not introduce offline caching (Epic 6).
- Do not redesign the chat UI; only add the selector + conversation actions.
- Do not change the SSE contract.

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story-5.5:-Conversation-Management-and-Document-Switching]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#Navigation-Patterns] (document selector in chat + bottom sheet patterns)
- [Source: _bmad-output/implementation-artifacts/5-4-flutter-chat-screen-with-streaming-answers.md] (mobile chat architecture + bootstrap contract)
- [Source: _bmad-output/implementation-artifacts/5-3-conversation-memory-and-context-management.md] (conversation endpoints + active conversation semantics)
- [Source: _bmad-output/project-context.md#Critical-Implementation-Rules] (Riverpod/DI/testing guardrails)

## Dev Agent Record

### Agent Model Used

GPT-5.3-Codex (GitHub Copilot)

### Debug Log References

- Backend focused: `cd backend && .venv/bin/python -m pytest tests/integration -q`
- Mobile focused: `cd mobile && flutter test`
- Mobile lint: `cd mobile && flutter analyze`

### Completion Notes List

- Implemented backend conversation history endpoints:
  - `GET /api/v1/documents/{document_id}/conversations` (ownership-enforced, newest-first)
  - `POST /api/v1/documents/{document_id}/conversations/{conversation_id}/activate` (ownership-enforced, reuses activation-by-touch semantics)
- Added backend schema/service/repository support for list envelope responses and scoped activation.
- Added deterministic backend integration tests covering auth, ownership, ordering, and latest-conversation switching behavior.
- Implemented Chat top-bar document selector bottom sheet using `documentListProvider` refresh-on-open and `status == "ready"` filtering.
- Implemented strict context isolation on document switches by resetting message list, draft, in-flight stream metadata, and citation UI state before bootstrap.
- Added "New Conversation" chat action with confirmation dialog, optimistic clear, re-bootstrap, and info snackbar.
- Added "Conversation history" overflow action with bottom-sheet session list and activation flow that re-bootstrap loads selected history.
- Added deterministic widget tests for selector readiness filtering, document switch reload behavior, and new-conversation confirmation flow.
- Full validation passed:
  - `cd backend && .venv/bin/python -m pytest -q` -> 85 passed
  - `cd mobile && flutter test` -> all tests passed
  - `cd mobile && flutter analyze` -> no issues found

### File List

- backend/app/routers/documents.py
- backend/app/services/conversation_service.py
- backend/app/repositories/conversation_repository.py
- backend/app/schemas/conversations.py
- backend/tests/integration/test_conversations_list.py
- backend/tests/integration/test_conversations_activate.py
- mobile/lib/features/chat/screens/chat_screen.dart
- mobile/lib/features/chat/providers/chat_controller.dart
- mobile/lib/features/chat/data/chat_api.dart
- mobile/lib/features/chat/models/chat_models.dart
- mobile/test/widget/chat_document_switching_test.dart
- mobile/test/widget/chat_new_conversation_test.dart

## Change Log

- 2026-03-20: Implemented story 5.5 end-to-end (backend conversation list/activate APIs, mobile chat document switching/new conversation/history UI, and full backend/mobile test coverage updates).
