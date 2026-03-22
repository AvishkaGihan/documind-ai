---
stepsCompleted: [1, 2, 3, 4, 5, 6, 7, 8]
inputDocuments:
  - product-brief-documind-ai-2026-03-14.md
  - prd.md
  - ux-design-specification.md
workflowType: 'architecture'
project_name: 'documind-ai'
user_name: 'Avishka Gihan'
date: '2026-03-14'
lastStep: 8
status: 'complete'
completedAt: '2026-03-14'
---

# Architecture Decision Document

_This document builds collaboratively through step-by-step discovery. Sections are appended as we work through each architectural decision together._

## Project Context Analysis

### Requirements Overview

**Functional Requirements:**

DocuMind AI defines 33 functional requirements (FR1–FR33) organized into 7 categories:

1. **User Management (FR1–FR4):** Account creation, login/logout, password reset — standard authentication flows requiring secure session management and token-based auth.
2. **Document Upload & Storage (FR5–FR8):** PDF upload (up to 50 MB), progress tracking, cloud storage association, and complete document+data deletion — requires multipart upload handling, progress streaming, and cascading data cleanup.
3. **Document Processing (FR9–FR13):** Text extraction with page-level metadata, overlapping chunk splitting, Sentence Transformer embedding generation, ChromaDB vector storage, and pipeline status tracking — this is the core AI pipeline requiring ordered async processing.
4. **Conversational Q&A (FR14–FR18):** Natural-language question input, semantic similarity retrieval (top-k chunks), LLM answer generation via Groq LLaMA 3.3 70B, inline page citations, and streaming answer display — the primary user-facing AI interaction.
5. **Conversation Memory (FR19–FR22):** Per-document session history, contextual follow-up question support, full history viewing, and conversation reset — requires server-side context window management.
6. **Document Library (FR23–FR26):** Document listing with status indicators, document switching with isolated contexts, metadata display, and search/filter — standard CRUD with real-time status updates.
7. **Mobile Experience & Error Handling (FR27–FR33):** Responsive chat UI, offline caching, upload queuing, loading states, error messages, unanswerable question handling, and rate-limit communication — mobile-native UX requirements.

**Architectural Implications:**
- The document processing pipeline (FR9–FR13) is the most architecturally significant — it requires async task orchestration, progress broadcasting, and multi-service coordination (storage → extraction → chunking → embedding → vector DB).
- Streaming answers (FR18) require Server-Sent Events (SSE) or WebSocket support between backend and mobile client.
- Conversation memory (FR19–FR22) requires careful context window management to stay within LLM token limits while maintaining conversation quality.
- Per-user data isolation (security NFR) must be enforced at the database, vector store, and file storage layers.

**Non-Functional Requirements:**

| Category | Key Requirements | Architectural Impact |
|---|---|---|
| **Performance** | Q&A < 5s (p95), 50-page PDF < 30s, app cold start < 2s, 60fps scrolling | Requires Groq's fast inference, efficient chunking pipeline, optimized Flutter rendering |
| **Security** | JWT with secure storage, per-user data isolation, HTTPS/TLS 1.2+, bcrypt passwords, file validation, data deletion within 24h | Needs Keychain/Keystore integration, middleware-level auth, server-side file validation |
| **Scalability** | 100 docs/user (500 pages each), 100K+ vectors/user, stateless backend, rate limiting (20 queries/min) | ChromaDB collection design, stateless FastAPI, rate limiter middleware |
| **Accessibility** | VoiceOver/TalkBack, text scaling 200%, WCAG 2.1 AA contrast, 44×44pt touch targets, reduce motion support | Flutter Semantics widgets, dynamic type, accessible citation chips |
| **Integration** | Groq API (with fallback), Cloudinary/S3, ChromaDB, Sentence Transformers | External service abstraction layer, graceful degradation patterns |

**Scale & Complexity:**

- Primary domain: Mobile App with AI/ML Backend (cross-platform mobile + Python API + RAG pipeline)
- Complexity level: Medium — no regulated industry requirements, but the RAG pipeline, streaming answers, and mobile-first UX add significant technical depth
- Estimated architectural components: 12–15 distinct modules across frontend and backend

### Technical Constraints & Dependencies

1. **Groq Free Tier:** Rate-limited API access for LLaMA 3.3 70B inference — requires request queuing, caching, and graceful degradation.
2. **ChromaDB:** Open-source vector database — must be self-hosted or use Chroma Cloud; collection-per-user design for data isolation.
3. **Sentence Transformers:** Local embedding generation — requires GPU/CPU resources on backend server; zero API cost but compute-bound.
4. **Cloudinary/S3:** File storage — requires signed URL generation for secure access; storage costs scale with document volume.
5. **Mobile Platform Constraints:** iOS Keychain / Android Keystore for token storage; platform file pickers for PDF selection; push notification setup (post-MVP).
6. **Solo Developer:** Architecture must be implementable by a single developer within 8–12 weeks — favoring simplicity and convention over custom infrastructure.

### Cross-Cutting Concerns Identified

1. **Authentication & Authorization:** Spans all API endpoints, file access, vector store queries, and mobile token management.
2. **Error Handling:** Consistent error format across backend API, mobile UI error states, and AI pipeline failures.
3. **Loading & Progress States:** Document processing pipeline, Q&A answer streaming, file upload progress — all require real-time status communication.
4. **Data Isolation:** Per-user enforcement across documents, embeddings, conversations, and file storage.
5. **Offline Support:** Cached document library, chat history, and queued uploads — requires local storage strategy on mobile.
6. **Logging & Monitoring:** Structured logging across backend services for debugging and performance tracking.

---

## Starter Template Evaluation

### Primary Technology Domain

**Mobile App (Flutter) + API Backend (FastAPI)** — identified from PRD classification as "Mobile App (with Backend API)" and the specified tech stack.

This is a **two-project architecture:**
1. **Frontend:** Flutter mobile application (iOS + Android)
2. **Backend:** FastAPI Python application orchestrating the RAG pipeline

### Starter Options Considered

#### Frontend: Flutter

| Option | Description | Status |
|---|---|---|
| **`flutter create`** | Official Flutter SDK project generator | ✅ Selected |
| Expo (React Native) | Alternative cross-platform framework | ❌ PRD prefers Flutter |
| VeryGoodCLI | Opinionated Flutter starter by Very Good Ventures | ❌ Overly opinionated for portfolio project |

**Rationale:** `flutter create` with `--org` flag provides a clean, unopinionated starting point. The PRD specifies Flutter as the preferred framework, and Material 3 is the UX design system foundation. Using the official generator ensures compatibility with Flutter 3.41 (latest stable) and allows full customization per the UX Design Specification.

#### Backend: FastAPI

| Option | Description | Status |
|---|---|---|
| **FastAPI manual setup** | Hand-structured FastAPI project with best practices | ✅ Selected |
| Cookiecutter FastAPI | Template-based FastAPI boilerplate | ❌ Includes unnecessary complexity (Docker, Celery defaults) |
| FastAPI Full-Stack Template | Tiangolo's full-stack template | ❌ Includes frontend; overkill for API-only backend |

**Rationale:** FastAPI's simplicity means a hand-structured project with clear module organization provides more control and learning value for a portfolio project. The RAG pipeline components (LangChain, ChromaDB, Sentence Transformers) require custom integration that templates don't cover.

### Selected Starters

**Frontend — Flutter:**

**Initialization Command:**

```bash
flutter create --org com.avishkagihan --project-name documind_ai --platforms ios,android ./mobile
```

**Architectural Decisions Provided by Starter:**

**Language & Runtime:**
- Dart 3.x with null safety enabled by default
- Flutter 3.41 (latest stable, March 2026)
- Material 3 design system as foundation

**Styling Solution:**
- Material 3 `ThemeData` with custom `ColorScheme` and `ThemeExtension` for DocuMind AI design tokens
- Custom widgets for citation chips, document cards, AI response bubbles (per UX specification)

**Build Tooling:**
- Flutter build system (Gradle for Android, Xcode for iOS)
- `flutter_lints` for code quality

**Testing Framework:**
- `flutter_test` for widget tests
- `integration_test` for end-to-end tests

**Code Organization:**
- Feature-based directory structure (to be defined in Step 6)
- Riverpod 3.2.1 for state management (async-first, testable)

**Development Experience:**
- Hot reload / hot restart
- Flutter DevTools for debugging and performance profiling
- Chrome DevTools integration

---

**Backend — FastAPI:**

**Initialization Command:**

```bash
mkdir backend && cd backend
python -m venv venv
pip install fastapi[standard]==0.135.1 uvicorn[standard] langchain==1.2.10 chromadb==1.5.5 sentence-transformers==5.3.0 python-multipart pydantic[email] python-jose[cryptography] passlib[bcrypt] boto3 aiofiles
```

**Architectural Decisions Provided by Starter:**

**Language & Runtime:**
- Python 3.12+ with type hints
- FastAPI 0.135.1 (latest stable)
- Pydantic v2 for data validation and serialization

**Build Tooling:**
- `uvicorn` ASGI server for development and production
- `pip` with `requirements.txt` for dependency management
- Optional: `pyproject.toml` with `uv` for faster dependency resolution

**Testing Framework:**
- `pytest` with `pytest-asyncio` for async test support
- `httpx` for API testing via `TestClient`

**Code Organization:**
- Modular package structure with routers, services, models, and repositories
- Dependency injection via FastAPI's `Depends()` system

**Development Experience:**
- Auto-reload via `uvicorn --reload`
- Interactive API docs at `/docs` (Swagger UI) and `/redoc`
- Structured logging with `structlog`

**Note:** Project initialization using these commands should be the first implementation story.

---

## Core Architectural Decisions

### Decision Priority Analysis

**Critical Decisions (Block Implementation):**
1. Database selection for application data (users, documents, conversations)
2. Authentication mechanism and token management
3. RAG pipeline architecture (chunking, embedding, retrieval, generation)
4. API communication pattern (REST + SSE for streaming)
5. State management approach (Riverpod)
6. File storage service (Cloudinary vs S3)

**Important Decisions (Shape Architecture):**
1. Caching strategy for repeated queries
2. Background task processing for document pipeline
3. Error handling and retry patterns
4. Mobile local storage for offline support

**Deferred Decisions (Post-MVP):**
1. Horizontal scaling strategy (load balancer, container orchestration)
2. CDN for static assets
3. Push notification infrastructure
4. Cross-document Q&A architecture

### Data Architecture

**Primary Database: SQLite (Development) → PostgreSQL (Production)**
- **Version:** PostgreSQL 16 (latest stable) for production; SQLite for local development
- **ORM:** SQLAlchemy 2.0 with async support (`asyncpg` driver)
- **Rationale:** SQLAlchemy provides a clean abstraction that works with both SQLite (dev) and PostgreSQL (prod). For a portfolio project, SQLite simplifies local setup while PostgreSQL demonstrates production readiness.
- **Migration Tool:** Alembic for schema migrations

**Vector Database: ChromaDB 1.5.5**
- **Deployment:** Self-hosted (embedded mode for development, client-server for production)
- **Collection Strategy:** One collection per user-document pair (`user_{id}_doc_{id}`)
- **Rationale:** Specified by PRD; ChromaDB's simplicity and Python-native API align with the solo developer timeline.

**Data Modeling Approach:**
- SQLAlchemy declarative models for users, documents, conversations, and messages
- Pydantic v2 schemas for API request/response validation
- ChromaDB metadata for chunk-level page references

**Data Validation Strategy:**
- Input validation via Pydantic models at API boundary
- Database-level constraints for integrity (unique emails, foreign keys)
- File validation: magic bytes check for genuine PDF detection server-side

**Migration Approach:**
- Alembic auto-generate migrations from SQLAlchemy model changes
- Version-controlled migration files in `backend/alembic/versions/`

**Caching Strategy:**
- In-memory caching (Python `functools.lru_cache`) for repeated embedding queries
- Optional: Redis for query result caching in production (deferred to post-MVP)

### Authentication & Security

**Authentication Method: JWT (JSON Web Tokens)**
- **Library:** `python-jose[cryptography]` for JWT encoding/decoding
- **Token Expiry:** Access token = 24 hours; Refresh token = 7 days
- **Storage (Mobile):** iOS Keychain via `flutter_secure_storage`, Android Keystore via `flutter_secure_storage`
- **Rationale:** JWT is stateless, scalable, and well-supported in both FastAPI and Flutter ecosystems.

**Authorization Patterns:**
- Middleware-based user extraction from JWT on every authenticated request
- Resource-level ownership checks: every document, conversation, and query validates `user_id` match
- No role-based access control needed for MVP (single-user-type system)

**Security Middleware:**
- CORS middleware configured for mobile app origins
- Rate limiting middleware: 20 queries/minute, 100 uploads/day per user
- Request size limiting: 50 MB max for file uploads

**Password Security:**
- `passlib[bcrypt]` with bcrypt hashing, minimum 12-character passwords
- No password complexity rules beyond length (usability over security theater)

**API Security Strategy:**
- All endpoints over HTTPS/TLS 1.2+
- No API keys exposed in mobile client — all secrets server-side
- Server-side file validation before processing (magic bytes + extension check)

### API & Communication Patterns

**API Design Pattern: RESTful API with SSE for Streaming**
- **Standard Endpoints:** REST with JSON payloads for CRUD operations (auth, documents, conversations)
- **Streaming Endpoint:** Server-Sent Events (SSE) for streaming AI-generated answers character-by-character
- **Rationale:** REST is straightforward and well-documented for portfolio review. SSE provides one-way streaming (server → client) which is exactly what streaming answers need, without the complexity of WebSockets.

**API Documentation Approach:**
- FastAPI auto-generated OpenAPI 3.1 specification
- Swagger UI at `/docs` for interactive testing
- ReDoc at `/redoc` for clean documentation

**Error Handling Standards:**
- Consistent error response format across all endpoints:
  ```json
  {
    "detail": {
      "code": "DOCUMENT_NOT_FOUND",
      "message": "The requested document does not exist or you do not have access.",
      "field": null
    }
  }
  ```
- HTTP status codes: 400 (validation), 401 (unauthorized), 403 (forbidden), 404 (not found), 422 (unprocessable), 429 (rate limited), 500 (server error)

**Rate Limiting Strategy:**
- Per-user rate limiting via `slowapi` library
- Q&A queries: 20/minute
- File uploads: 100/day
- Rate limit headers in responses: `X-RateLimit-Remaining`, `X-RateLimit-Reset`

**Communication Between Services:**
- Direct function calls within the monolithic backend (no microservices for MVP)
- Background task processing via FastAPI `BackgroundTasks` for document pipeline
- Future: Celery + Redis for production-grade task queue (post-MVP)

### Frontend Architecture

**State Management: Riverpod 3.2.1**
- **Rationale:** Riverpod is async-first, highly testable, and the recommended state management solution for Flutter in 2026. Riverpod 3.x provides automatic retry for failed providers and simplified API.
- **Pattern:** Provider-per-feature with `AsyncNotifier` for async state

**Component Architecture:**
- **Design System:** Custom-themed Material 3 with `ThemeExtension` for DocuMind AI tokens (dark mode primary)
- **Custom Widgets:** Citation Chip, Document Card, AI Response Bubble, Processing Animation, AI Typing Indicator
- **Composition:** Small, focused widgets composed into larger feature screens

**Routing Strategy:**
- `go_router` for declarative, URL-based routing
- Routes: `/auth/login`, `/auth/signup`, `/library`, `/chat/:documentId`, `/settings`
- Deep linking support for future use

**Performance Optimization:**
- `const` constructors for static widgets
- `ListView.builder` for lazy-loading chat messages and document lists
- Image caching for any document thumbnails
- Skeletal loading (shimmer) for perceived performance
- Keyboard-aware layouts to prevent content obscuring

**Bundle Optimization:**
- Tree-shaking of unused Material icons
- Deferred loading for settings and profile screens
- Target app size: < 50 MB initial download

### Infrastructure & Deployment

**Hosting Strategy:**
- **Backend:** Railway or Render for FastAPI deployment (Docker container)
- **File Storage:** AWS S3 (or Cloudinary) for PDF persistence with signed URLs
- **Vector DB:** ChromaDB hosted alongside backend (or Chroma Cloud for production)
- **Database:** PostgreSQL managed instance on Railway/Render
- **Rationale:** Railway/Render provide simple, affordable hosting for portfolio projects with free/hobby tiers. Docker-based deployment ensures environment consistency.

**CI/CD Pipeline Approach:**
- GitHub Actions for CI:
  - Backend: `pytest` on push/PR, linting with `ruff`
  - Frontend: `flutter test`, `flutter analyze` on push/PR
- CD: Auto-deploy to Railway/Render on merge to `main`

**Environment Configuration:**
- `.env` files for local development (never committed)
- `.env.example` with documented variables
- Environment variables on hosting platform for production
- Pydantic `BaseSettings` for typed config loading in backend

**Monitoring and Logging:**
- `structlog` for structured JSON logging in backend
- Python `logging` for library integrations
- FastAPI middleware for request/response logging (timing, status codes)
- Flutter: `logger` package for client-side logging in debug mode

**Scaling Strategy (Post-MVP):**
- Stateless backend behind load balancer
- PostgreSQL read replicas for scaling reads
- ChromaDB sharding per user for vector isolation
- Redis for caching and task queuing

### Decision Impact Analysis

**Implementation Sequence:**
1. Backend project setup (FastAPI, SQLAlchemy, Alembic)
2. Authentication system (JWT, user model, login/signup endpoints)
3. File upload and storage (S3/Cloudinary integration)
4. Document processing pipeline (extraction → chunking → embedding → ChromaDB)
5. Q&A endpoint with RAG pipeline (LangChain, Groq, streaming SSE)
6. Flutter project setup (Riverpod, routing, design system)
7. Auth screens and token management
8. Document library UI and upload flow
9. Chat UI with streaming answers and citation chips
10. Conversation memory and document switching

**Cross-Component Dependencies:**
- Authentication → All authenticated endpoints and mobile screens
- Document processing pipeline → Q&A system (depends on stored embeddings)
- Streaming SSE → Chat UI (backend must support SSE, client must parse event stream)
- Riverpod state → All UI screens (single source of truth for app state)
- Design system → All custom widgets (tokens must be defined before component building)

---

## Implementation Patterns & Consistency Rules

### Pattern Categories Defined

**Critical Conflict Points Identified:** 18 areas where AI agents could make different choices, grouped into 5 categories.

### Naming Patterns

**Database Naming Conventions:**
- Tables: `snake_case`, **plural** (e.g., `users`, `documents`, `conversations`, `messages`)
- Columns: `snake_case` (e.g., `user_id`, `created_at`, `file_path`)
- Foreign keys: `{referenced_table_singular}_id` (e.g., `user_id`, `document_id`)
- Indexes: `ix_{table}_{column}` (e.g., `ix_users_email`)
- Example:
  ```sql
  CREATE TABLE documents (
      id UUID PRIMARY KEY,
      user_id UUID REFERENCES users(id),
      title VARCHAR(255),
      file_path TEXT,
      page_count INTEGER,
      status VARCHAR(20),
      created_at TIMESTAMP DEFAULT NOW()
  );
  ```

**API Naming Conventions:**
- REST endpoints: `snake_case`, **plural nouns** (e.g., `/api/v1/documents`, `/api/v1/conversations`)
- Route parameters: `{snake_case}` (e.g., `/api/v1/documents/{document_id}`)
- Query parameters: `snake_case` (e.g., `?page_size=20&sort_by=created_at`)
- API versioning: `/api/v1/` prefix for all endpoints
- Example:
  ```
  POST   /api/v1/auth/signup
  POST   /api/v1/auth/login
  GET    /api/v1/documents
  POST   /api/v1/documents/upload
  DELETE /api/v1/documents/{document_id}
  POST   /api/v1/documents/{document_id}/ask
  GET    /api/v1/documents/{document_id}/conversations
  ```

**Code Naming Conventions:**

| Context | Convention | Example |
|---|---|---|
| **Python files** | `snake_case.py` | `document_service.py`, `auth_router.py` |
| **Python classes** | `PascalCase` | `DocumentService`, `UserModel` |
| **Python functions** | `snake_case` | `process_document()`, `get_user_by_id()` |
| **Python variables** | `snake_case` | `document_id`, `chunk_size` |
| **Python constants** | `UPPER_SNAKE_CASE` | `MAX_FILE_SIZE`, `DEFAULT_CHUNK_SIZE` |
| **Dart files** | `snake_case.dart` | `document_card.dart`, `auth_provider.dart` |
| **Dart classes** | `PascalCase` | `DocumentCard`, `AuthNotifier` |
| **Dart functions** | `camelCase` | `uploadDocument()`, `askQuestion()` |
| **Dart variables** | `camelCase` | `documentId`, `isLoading` |
| **Dart constants** | `camelCase` with `const` | `const defaultChunkSize = 500` |

### Structure Patterns

**Project Organization:**
- **Backend:** Module-based organization (routers, services, models, repositories, core)
- **Frontend:** Feature-based organization (auth, library, chat, settings, shared)
- Tests: Co-located in `tests/` directory mirroring source structure
- Shared utilities: `core/` (backend) and `shared/` (frontend) directories

**File Structure Patterns:**
- Config files: Root of each project (backend and mobile)
- Static assets: `mobile/assets/` for fonts, images, icons
- Environment files: `.env` (local, gitignored), `.env.example` (committed)
- Documentation: Root-level `README.md` for each project

### Format Patterns

**API Response Formats:**

- **Success response (single item):**
  ```json
  {
    "id": "uuid-here",
    "title": "Document Title",
    "status": "ready",
    "created_at": "2026-03-14T12:00:00Z"
  }
  ```

- **Success response (list):**
  ```json
  {
    "items": [...],
    "total": 42,
    "page": 1,
    "page_size": 20
  }
  ```

- **Error response:**
  ```json
  {
    "detail": {
      "code": "ERROR_CODE",
      "message": "Human-readable error message",
      "field": "optional_field_name"
    }
  }
  ```

- **Streaming response (SSE for Q&A):**
  ```
  event: token
  data: {"content": "According to"}

  event: token
  data: {"content": " page 4, the"}

  event: citation
  data: {"page": 4, "text": "Relevant chunk text..."}

  event: done
  data: {"message_id": "uuid"}
  ```

**Data Exchange Formats:**
- JSON field naming: `snake_case` in API responses (Python convention; Dart models convert to `camelCase` internally)
- Dates: ISO 8601 strings (`2026-03-14T12:00:00Z`) — always UTC
- UUIDs: String format for all IDs (`uuid4`)
- Booleans: `true`/`false` (JSON standard)
- Null handling: Omit null fields from responses where possible; use `null` explicitly for nullable fields that must be present

### Communication Patterns

**Event System Patterns:**
- Document processing status updates via polling (MVP) or SSE (future):
  - Event names: `processing.started`, `processing.extracting`, `processing.chunking`, `processing.embedding`, `processing.complete`, `processing.failed`
  - Payload: `{"document_id": "uuid", "status": "extracting", "progress": 45, "message": "Extracting text from page 12 of 25"}`

**State Management Patterns (Riverpod):**
- Immutable state updates using `copyWith()` on state classes
- Provider naming: `{feature}{Type}Provider` (e.g., `documentListProvider`, `chatMessagesProvider`, `authStateProvider`)
- `AsyncNotifier` for all async state (API calls, file operations)
- `ref.watch()` for reactive UI, `ref.read()` for one-time actions (event handlers)
- State classes use `@freezed` for immutable data with `copyWith()`

### Process Patterns

**Error Handling Patterns:**

| Layer | Pattern | Example |
|---|---|---|
| **Backend API** | Custom exception classes → exception handlers → consistent JSON error response | `DocumentNotFoundError` → 404 response |
| **Backend Service** | Try/except with specific exceptions; log error; re-raise as HTTP exception | `try: process() except PdfExtractionError: raise HTTPException(422, ...)` |
| **Mobile API Layer** | `try/catch` on API calls; map HTTP errors to typed `Failure` objects | `catch (DioException e) → DocumentFailure.notFound()` |
| **Mobile UI** | Riverpod `AsyncValue.when()` for loading/data/error states | `asyncValue.when(error: (e, _) => ErrorWidget(e))` |

**Loading State Patterns:**
- Loading state naming: `isLoading`, `isProcessing`, `isUploading` (boolean flags within state classes)
- Global loading: Riverpod `AsyncValue` handles loading state automatically
- Local loading: Button-specific loading via `ValueNotifier<bool>` for non-provider interactions
- Loading UI: Shimmer skeleton for lists; pulsing dots for AI typing; linear progress bar for uploads

### Enforcement Guidelines

**All AI Agents MUST:**

1. Use `snake_case` for all Python identifiers and file names; `camelCase` for Dart identifiers and file names
2. Return consistent error response format (`detail.code`, `detail.message`) from all backend endpoints
3. Use Riverpod `AsyncNotifier` for all async state management — never use raw `setState()` or `StatefulWidget` for async data
4. Include source page citations in every Q&A response — this is the core product differentiator
5. Enforce user data isolation at the service layer (never trust client-side `user_id`)
6. Use design tokens from the theme system — never hardcode colors, spacing, or font sizes

**Pattern Enforcement:**
- Code review checklist includes pattern compliance verification
- `ruff` (Python) and `flutter_lints` (Dart) enforce code style automatically
- API response format validated via Pydantic response models

### Pattern Examples

**Good Examples:**

```python
# Backend: Correct service method with error handling and data isolation
async def get_document(self, document_id: UUID, user_id: UUID) -> Document:
    document = await self.repo.get_by_id(document_id)
    if not document or document.user_id != user_id:
        raise DocumentNotFoundError(f"Document {document_id} not found")
    return document
```

```dart
// Frontend: Correct Riverpod provider with AsyncNotifier
@riverpod
class DocumentList extends _$DocumentList {
  @override
  Future<List<Document>> build() async {
    final api = ref.watch(apiClientProvider);
    return api.getDocuments();
  }

  Future<void> deleteDocument(String documentId) async {
    final api = ref.read(apiClientProvider);
    await api.deleteDocument(documentId);
    ref.invalidateSelf(); // Refetch list
  }
}
```

**Anti-Patterns:**

```python
# ❌ WRONG: No user isolation, inconsistent error format
async def get_document(self, document_id: UUID) -> Document:
    document = await self.repo.get_by_id(document_id)
    if not document:
        return {"error": "Not found"}  # ❌ Wrong format
    return document  # ❌ No user_id check
```

```dart
// ❌ WRONG: Using StatefulWidget for async data, hardcoded colors
class DocumentListScreen extends StatefulWidget {
  // ❌ Should use Riverpod consumer widget
  Color cardColor = Color(0xFF161B22);  // ❌ Hardcoded, should use theme
}
```

---

## Project Structure & Boundaries

### Complete Project Directory Structure

```
documind-ai/
├── README.md
├── .gitignore
├── .github/
│   └── workflows/
│       ├── backend-ci.yml
│       └── mobile-ci.yml
│
├── backend/
│   ├── README.md
│   ├── requirements.txt
│   ├── pyproject.toml
│   ├── .env.example
│   ├── .env                          # (gitignored)
│   ├── alembic.ini
│   ├── alembic/
│   │   ├── env.py
│   │   └── versions/
│   │       └── 001_initial_schema.py
│   ├── app/
│   │   ├── __init__.py
│   │   ├── main.py                   # FastAPI app entry point
│   │   ├── config.py                 # Pydantic BaseSettings config
│   │   ├── database.py               # SQLAlchemy engine & session
│   │   ├── dependencies.py           # Shared FastAPI dependencies
│   │   ├── exceptions.py             # Custom exception classes
│   │   ├── middleware/
│   │   │   ├── __init__.py
│   │   │   ├── auth.py               # JWT authentication middleware
│   │   │   ├── cors.py               # CORS configuration
│   │   │   └── rate_limit.py         # Per-user rate limiting
│   │   ├── models/
│   │   │   ├── __init__.py
│   │   │   ├── user.py               # User SQLAlchemy model
│   │   │   ├── document.py           # Document SQLAlchemy model
│   │   │   ├── conversation.py       # Conversation SQLAlchemy model
│   │   │   └── message.py            # Message SQLAlchemy model
│   │   ├── schemas/
│   │   │   ├── __init__.py
│   │   │   ├── auth.py               # Auth request/response schemas
│   │   │   ├── document.py           # Document request/response schemas
│   │   │   ├── conversation.py       # Conversation schemas
│   │   │   └── message.py            # Message & Q&A schemas
│   │   ├── routers/
│   │   │   ├── __init__.py
│   │   │   ├── auth.py               # /api/v1/auth/* endpoints
│   │   │   ├── documents.py          # /api/v1/documents/* endpoints
│   │   │   └── conversations.py      # /api/v1/conversations/* endpoints
│   │   ├── services/
│   │   │   ├── __init__.py
│   │   │   ├── auth_service.py       # Authentication business logic
│   │   │   ├── document_service.py   # Document CRUD & processing orchestration
│   │   │   ├── processing/
│   │   │   │   ├── __init__.py
│   │   │   │   ├── extractor.py      # PDF text extraction with page metadata
│   │   │   │   ├── chunker.py        # Overlapping chunk splitting
│   │   │   │   ├── embedder.py       # Sentence Transformer embedding generation
│   │   │   │   └── pipeline.py       # End-to-end processing orchestration
│   │   │   ├── rag_service.py        # RAG pipeline: retrieval + generation
│   │   │   ├── llm_service.py        # Groq LLaMA 3.3 70B integration
│   │   │   ├── vector_service.py     # ChromaDB operations
│   │   │   └── storage_service.py    # S3/Cloudinary file operations
│   │   └── repositories/
│   │       ├── __init__.py
│   │       ├── user_repo.py          # User database operations
│   │       ├── document_repo.py      # Document database operations
│   │       ├── conversation_repo.py  # Conversation database operations
│   │       └── message_repo.py       # Message database operations
│   └── tests/
│       ├── __init__.py
│       ├── conftest.py               # Shared fixtures (test DB, test client)
│       ├── unit/
│       │   ├── test_auth_service.py
│       │   ├── test_document_service.py
│       │   ├── test_chunker.py
│       │   ├── test_embedder.py
│       │   └── test_rag_service.py
│       ├── integration/
│       │   ├── test_auth_endpoints.py
│       │   ├── test_document_endpoints.py
│       │   └── test_qa_endpoints.py
│       └── fixtures/
│           ├── sample.pdf
│           └── sample_chunks.json
│
├── mobile/
│   ├── README.md
│   ├── pubspec.yaml
│   ├── analysis_options.yaml
│   ├── .env.example
│   ├── assets/
│   │   ├── fonts/
│   │   │   ├── Inter-Regular.ttf
│   │   │   ├── Inter-Medium.ttf
│   │   │   ├── Inter-SemiBold.ttf
│   │   │   ├── Inter-Bold.ttf
│   │   │   ├── JetBrainsMono-Regular.ttf
│   │   │   └── JetBrainsMono-Medium.ttf
│   │   └── images/
│   │       ├── logo.svg
│   │       ├── empty_library.svg
│   │       └── empty_chat.svg
│   ├── lib/
│   │   ├── main.dart                 # App entry point
│   │   ├── app.dart                  # MaterialApp with theme setup
│   │   ├── router.dart               # GoRouter configuration
│   │   ├── core/
│   │   │   ├── theme/
│   │   │   │   ├── app_theme.dart            # ThemeData + ColorScheme
│   │   │   │   ├── app_colors.dart           # Design token colors
│   │   │   │   ├── app_typography.dart       # Text styles (Inter, JetBrains Mono)
│   │   │   │   ├── app_spacing.dart          # Spacing scale tokens
│   │   │   │   └── theme_extensions.dart     # Custom ThemeExtension definitions
│   │   │   ├── network/
│   │   │   │   ├── api_client.dart           # Dio HTTP client setup
│   │   │   │   ├── api_endpoints.dart        # Endpoint constants
│   │   │   │   ├── api_interceptors.dart     # Auth token injection, error mapping
│   │   │   │   └── sse_client.dart           # Server-Sent Events client for streaming
│   │   │   ├── storage/
│   │   │   │   ├── secure_storage.dart       # flutter_secure_storage wrapper
│   │   │   │   └── local_database.dart       # SQLite/Hive for offline cache
│   │   │   ├── utils/
│   │   │   │   ├── extensions.dart           # Dart extension methods
│   │   │   │   └── validators.dart           # Form validation helpers
│   │   │   └── errors/
│   │   │       ├── failures.dart             # Typed failure classes
│   │   │       └── error_handler.dart        # Global error handling
│   │   ├── features/
│   │   │   ├── auth/
│   │   │   │   ├── data/
│   │   │   │   │   ├── auth_repository.dart  # Auth API calls
│   │   │   │   │   └── auth_models.dart      # Login/Signup DTOs
│   │   │   │   ├── providers/
│   │   │   │   │   └── auth_provider.dart    # Riverpod auth state
│   │   │   │   └── screens/
│   │   │   │       ├── login_screen.dart
│   │   │   │       └── signup_screen.dart
│   │   │   ├── library/
│   │   │   │   ├── data/
│   │   │   │   │   ├── document_repository.dart
│   │   │   │   │   └── document_models.dart
│   │   │   │   ├── providers/
│   │   │   │   │   ├── document_list_provider.dart
│   │   │   │   │   └── upload_provider.dart
│   │   │   │   ├── screens/
│   │   │   │   │   └── library_screen.dart
│   │   │   │   └── widgets/
│   │   │   │       ├── document_card.dart
│   │   │   │       ├── processing_animation.dart
│   │   │   │       ├── upload_button.dart
│   │   │   │       └── empty_library.dart
│   │   │   ├── chat/
│   │   │   │   ├── data/
│   │   │   │   │   ├── chat_repository.dart
│   │   │   │   │   └── chat_models.dart
│   │   │   │   ├── providers/
│   │   │   │   │   ├── chat_provider.dart
│   │   │   │   │   └── streaming_provider.dart
│   │   │   │   ├── screens/
│   │   │   │   │   └── chat_screen.dart
│   │   │   │   └── widgets/
│   │   │   │       ├── ai_response_bubble.dart
│   │   │   │       ├── user_question_bubble.dart
│   │   │   │       ├── citation_chip.dart
│   │   │   │       ├── typing_indicator.dart
│   │   │   │       ├── chat_input_bar.dart
│   │   │   │       └── empty_chat.dart
│   │   │   └── settings/
│   │   │       ├── providers/
│   │   │       │   └── settings_provider.dart
│   │   │       └── screens/
│   │   │           └── settings_screen.dart
│   │   └── shared/
│   │       └── widgets/
│   │           ├── app_scaffold.dart         # Shared scaffold with bottom nav
│   │           ├── loading_shimmer.dart       # Skeleton loading widget
│   │           ├── error_widget.dart          # Reusable error display
│   │           └── glassmorphic_container.dart # Frosted glass container
│   ├── test/
│   │   ├── unit/
│   │   │   ├── auth_provider_test.dart
│   │   │   ├── document_list_provider_test.dart
│   │   │   └── chat_provider_test.dart
│   │   ├── widget/
│   │   │   ├── citation_chip_test.dart
│   │   │   ├── document_card_test.dart
│   │   │   └── ai_response_bubble_test.dart
│   │   └── integration/
│   │       └── app_flow_test.dart
│   ├── android/
│   │   └── ...                               # Android-specific config
│   └── ios/
│       └── ...                               # iOS-specific config
│
└── docs/
    ├── api-reference.md
    ├── architecture-diagram.md
    └── setup-guide.md
```

### Architectural Boundaries

**API Boundaries:**
- All mobile → backend communication via REST API (`/api/v1/*`)
- Streaming answers via SSE endpoint (`/api/v1/documents/{id}/ask` with `Accept: text/event-stream`)
- File upload via multipart POST (`/api/v1/documents/upload`)
- Authentication boundary: JWT token required for all endpoints except `/api/v1/auth/signup` and `/api/v1/auth/login`

**Component Boundaries:**
- **Frontend:** Features are self-contained (auth, library, chat, settings) — each owns its data layer, providers, screens, and widgets
- **Backend:** Routers handle HTTP concerns only; Services contain business logic; Repositories handle database access — strict separation of concerns
- **RAG Pipeline:** `services/processing/` owns the document processing pipeline; `services/rag_service.py` owns retrieval and answer generation — both accessed only through `document_service.py` and routers

**Service Boundaries:**
- `storage_service.py` is the sole interface to S3/Cloudinary — no direct AWS SDK calls elsewhere
- `vector_service.py` is the sole interface to ChromaDB — no direct Chroma client access elsewhere
- `llm_service.py` is the sole interface to Groq API — no direct HTTP calls to Groq elsewhere
- This abstraction allows swapping external services without touching business logic

**Data Boundaries:**
- SQLAlchemy models → accessed only via `repositories/`
- ChromaDB collections → accessed only via `vector_service.py`
- S3/Cloudinary → accessed only via `storage_service.py`
- Mobile local storage → accessed only via `core/storage/`

### Requirements to Structure Mapping

**Feature/Epic Mapping:**

| Feature | Backend | Frontend |
|---|---|---|
| **User Authentication (FR1–FR4)** | `routers/auth.py`, `services/auth_service.py`, `models/user.py`, `repositories/user_repo.py` | `features/auth/` |
| **Document Upload (FR5–FR8)** | `routers/documents.py`, `services/document_service.py`, `services/storage_service.py`, `models/document.py` | `features/library/` (upload_provider, upload_button) |
| **Document Processing (FR9–FR13)** | `services/processing/*` (extractor, chunker, embedder, pipeline), `services/vector_service.py` | `features/library/widgets/processing_animation.dart` |
| **Conversational Q&A (FR14–FR18)** | `routers/conversations.py`, `services/rag_service.py`, `services/llm_service.py` | `features/chat/` (chat_provider, streaming_provider, AI bubbles) |
| **Conversation Memory (FR19–FR22)** | `services/rag_service.py`, `models/conversation.py`, `models/message.py`, `repositories/conversation_repo.py` | `features/chat/providers/chat_provider.dart` |
| **Document Library (FR23–FR26)** | `routers/documents.py`, `services/document_service.py`, `repositories/document_repo.py` | `features/library/` (document_list_provider, document_card) |
| **Mobile Experience (FR27–FR30)** | N/A | `core/storage/`, `shared/widgets/`, `core/network/sse_client.dart` |
| **Error Handling (FR31–FR33)** | `exceptions.py`, `middleware/rate_limit.py` | `core/errors/`, `shared/widgets/error_widget.dart` |

**Cross-Cutting Concerns:**

| Concern | Backend Location | Frontend Location |
|---|---|---|
| **Authentication** | `middleware/auth.py`, `dependencies.py` | `core/storage/secure_storage.dart`, `core/network/api_interceptors.dart` |
| **Error Handling** | `exceptions.py`, per-router exception handlers | `core/errors/failures.dart`, `core/errors/error_handler.dart` |
| **Design System** | N/A | `core/theme/*` |
| **Logging** | `config.py` (structlog setup), middleware | `main.dart` (logger configuration) |

### Integration Points

**Internal Communication:**
- Mobile → Backend: Dio HTTP client with interceptors for auth token injection and error mapping
- Backend Routers → Services: Direct function calls via dependency injection (`Depends()`)
- Services → Repositories: Direct function calls for database access
- Processing Pipeline: Sequential service calls (extractor → chunker → embedder → vector_service)

**External Integrations:**

| Service | Integration Point | Boundary |
|---|---|---|
| **Groq API** | `services/llm_service.py` | REST API calls for LLaMA 3.3 70B inference |
| **S3/Cloudinary** | `services/storage_service.py` | SDK client for file upload/download/delete |
| **ChromaDB** | `services/vector_service.py` | Python client for collection CRUD, embedding storage, similarity search |
| **Sentence Transformers** | `services/processing/embedder.py` | Local model loading and inference |

**Data Flow:**

```
User uploads PDF → Mobile (multipart upload) → Backend (documents router)
    → storage_service (save to S3) → processing pipeline (background task):
        → extractor (PDF → text + page metadata)
        → chunker (text → overlapping chunks with page refs)
        → embedder (chunks → vector embeddings via Sentence Transformers)
        → vector_service (store embeddings + metadata in ChromaDB)
    → Update document status to "ready"

User asks question → Mobile (chat input) → Backend (conversations router)
    → rag_service:
        → embedder (question → query embedding)
        → vector_service (similarity search → top-k chunks with page refs)
        → llm_service (chunks + question + conversation history → Groq LLaMA → streamed answer)
    → SSE stream → Mobile (progressive text rendering with citation chips)
```

### File Organization Patterns

**Configuration Files:**
- Backend: `.env` (secrets), `config.py` (typed settings), `alembic.ini` (migrations)
- Frontend: `.env` (API URL), `pubspec.yaml` (dependencies), `analysis_options.yaml` (lint rules)
- CI/CD: `.github/workflows/` (GitHub Actions)

**Source Organization:**
- Backend follows **clean architecture layers**: routers (HTTP) → services (business logic) → repositories (data access) → models (entities)
- Frontend follows **feature-based organization**: each feature owns data, providers, screens, and widgets

**Test Organization:**
- Backend: `tests/unit/` (service logic), `tests/integration/` (API endpoints), `tests/fixtures/` (test data)
- Frontend: `test/unit/` (providers), `test/widget/` (custom widget rendering), `test/integration/` (user flow)

**Asset Organization:**
- Fonts: `mobile/assets/fonts/` (Inter, JetBrains Mono)
- Images: `mobile/assets/images/` (logo, empty state illustrations)
- Generated: `mobile/lib/gen/` (if using code generation for assets)

### Development Workflow Integration

**Development Server Structure:**
- Backend: `uvicorn app.main:app --reload --port 8000`
- Frontend: `flutter run` with hot reload
- Both run simultaneously; mobile app connects to `http://localhost:8000` in development

**Build Process Structure:**
- Backend: Docker container build from `backend/Dockerfile`
- Frontend: `flutter build apk` (Android) / `flutter build ios` (iOS)

**Deployment Structure:**
- Backend deployed as Docker container on Railway/Render
- Frontend published to App Store / Play Store (or TestFlight for testing)
- Database and ChromaDB provisioned on hosting platform

---

## Architecture Validation Results

### Coherence Validation ✅

**Decision Compatibility:**
All technology choices work together without conflicts:
- Flutter 3.41 + Riverpod 3.2.1 + go_router → well-tested Flutter ecosystem combination
- FastAPI 0.135.1 + SQLAlchemy 2.0 + Pydantic v2 → official FastAPI integration stack
- LangChain 1.2.10 + ChromaDB 1.5.5 + Sentence Transformers 5.3.0 → compatible RAG pipeline components
- Groq API (LLaMA 3.3 70B) + LangChain → supported via `langchain-groq` integration package
- JWT auth workflow is consistent across FastAPI middleware and Flutter secure storage
- SSE streaming is supported by both FastAPI (`StreamingResponse`) and Dart (`EventSource` / Dio streaming)

**Pattern Consistency:**
- Naming conventions are consistently `snake_case` for Python/backend, `camelCase` for Dart/frontend
- API responses use a single consistent format with `detail` for errors
- Riverpod providers follow a uniform naming pattern and use `AsyncNotifier` consistently
- All external services are accessed through dedicated service classes (storage, vector, LLM)

**Structure Alignment:**
- Project structure directly supports the clean architecture decisions (layers are physically separated into directories)
- Feature-based frontend organization aligns with Riverpod's provider-per-feature pattern
- Integration boundaries are respected: each external service has exactly one gateway file

### Requirements Coverage Validation ✅

**Functional Requirements Coverage:**
- **FR1–FR4 (User Management):** ✅ Covered by `auth_service.py`, JWT middleware, Flutter auth feature
- **FR5–FR8 (Document Upload):** ✅ Covered by `storage_service.py`, `document_service.py`, Flutter upload_provider
- **FR9–FR13 (Document Processing):** ✅ Covered by `services/processing/` pipeline (extractor, chunker, embedder, pipeline)
- **FR14–FR18 (Q&A):** ✅ Covered by `rag_service.py`, `llm_service.py`, SSE streaming, Flutter chat feature
- **FR19–FR22 (Conversation Memory):** ✅ Covered by conversation/message models, rag_service context window
- **FR23–FR26 (Document Library):** ✅ Covered by document CRUD endpoints, Flutter library feature
- **FR27–FR30 (Mobile Experience):** ✅ Covered by Flutter theme system, Riverpod state, local storage, network layer
- **FR31–FR33 (Error Handling):** ✅ Covered by exception classes, error response format, rate limiting middleware

**Non-Functional Requirements Coverage:**
- **Performance:** ✅ Groq's fast inference addresses < 5s Q&A; background processing handles pipeline timing; Flutter optimizations address 60fps
- **Security:** ✅ JWT with secure storage, bcrypt passwords, per-user isolation, CORS, rate limiting, HTTPS
- **Scalability:** ✅ Stateless backend, collection-per-user ChromaDB design, rate limiting, PostgreSQL for production
- **Accessibility:** ✅ Flutter Semantics, WCAG 2.1 AA via UX spec compliance, dynamic type support
- **Integration:** ✅ All external services wrapped with abstraction layers for testability and swappability

### Implementation Readiness Validation ✅

**Decision Completeness:**
- All critical technology choices documented with verified current versions
- Authentication flow fully specified (JWT lifecycle, token storage, middleware)
- RAG pipeline architecture complete (extraction → chunking → embedding → retrieval → generation → streaming)
- Data models defined (users, documents, conversations, messages, vector collections)

**Structure Completeness:**
- Complete project directory tree defined with every file and directory
- All integration points mapped between backend and frontend
- Data flow documented from upload through processing to Q&A

**Pattern Completeness:**
- Naming conventions documented for database, API, Python, and Dart code
- API response format standardized with examples
- Error handling patterns defined at every layer
- State management patterns specified with Riverpod conventions
- SSE streaming protocol defined with event types and payloads

### Gap Analysis Results

**No Critical Gaps Found.**

**Important Gaps (Addressable During Implementation):**
1. **Database migration for document status enum:** Alembic migration should define an enum type for document status (`processing`, `extracting`, `chunking`, `embedding`, `ready`, `error`).
2. **Conversation context window management:** The exact strategy for truncating conversation history to fit within LLaMA 3.3 70B's 128K token context window should be finalized during implementation (e.g., most recent N messages + always include system prompt).
3. **Chunk size and overlap parameters:** Default values (chunk_size=500 tokens, overlap=50 tokens) should be tuned based on evaluation against the test query set.

**Nice-to-Have Gaps (Post-MVP):**
1. API versioning strategy for breaking changes
2. Database backup and recovery procedures
3. Monitoring dashboard setup (Grafana, Datadog)
4. Mobile crash reporting integration (Sentry, Crashlytics)

### Validation Issues Addressed

No critical or blocking issues found during validation. All architectural decisions are coherent, requirements are fully covered, and the architecture is ready for implementation.

### Architecture Completeness Checklist

**✅ Requirements Analysis**

- [x] Project context thoroughly analyzed
- [x] Scale and complexity assessed
- [x] Technical constraints identified
- [x] Cross-cutting concerns mapped

**✅ Architectural Decisions**

- [x] Critical decisions documented with versions
- [x] Technology stack fully specified
- [x] Integration patterns defined
- [x] Performance considerations addressed

**✅ Implementation Patterns**

- [x] Naming conventions established
- [x] Structure patterns defined
- [x] Communication patterns specified
- [x] Process patterns documented

**✅ Project Structure**

- [x] Complete directory structure defined
- [x] Component boundaries established
- [x] Integration points mapped
- [x] Requirements to structure mapping complete

### Architecture Readiness Assessment

**Overall Status:** READY FOR IMPLEMENTATION

**Confidence Level:** High — based on validated technology compatibility, complete requirements coverage, and comprehensive pattern specifications.

**Key Strengths:**
1. **Clear separation of concerns** across backend (routers → services → repos) and frontend (feature-based with Riverpod)
2. **External service abstraction** — every third-party integration has a single gateway, enabling easy testing and future swaps
3. **Streaming architecture** defined for the core differentiating feature (cited AI answers with SSE)
4. **Comprehensive naming and pattern conventions** that prevent AI agent implementation conflicts
5. **Verified current technology versions** ensuring compatibility and access to latest features

**Areas for Future Enhancement:**
1. Horizontal scaling infrastructure (container orchestration, load balancers)
2. Production monitoring and alerting stack
3. Cross-document Q&A architecture (requires collection aggregation strategy)
4. Push notification integration for processing completion
5. Web version architecture (Flutter web or separate SPA)

### Implementation Handoff

**AI Agent Guidelines:**

- Follow all architectural decisions exactly as documented
- Use implementation patterns consistently across all components
- Respect project structure and boundaries
- Refer to this document for all architectural questions
- Always use the specified technology versions
- Never bypass the service abstraction layer for external integrations

**First Implementation Priority:**
1. Initialize Flutter project: `flutter create --org com.avishkagihan --project-name documind_ai --platforms ios,android ./mobile`
2. Initialize Backend project: Create `backend/` directory with FastAPI structure, install dependencies
3. Set up database models and Alembic migrations
4. Implement authentication endpoints and Flutter auth flow
