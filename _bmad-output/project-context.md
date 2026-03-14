---
project_name: 'documind-ai'
user_name: 'Avishka Gihan'
date: '2026-03-14'
sections_completed:
  ['technology_stack', 'language_rules', 'framework_rules', 'testing_rules', 'quality_rules', 'workflow_rules', 'anti_patterns']
status: 'complete'
rule_count: 52
optimized_for_llm: true
---

# Project Context for AI Agents

_This file contains critical rules and patterns that AI agents must follow when implementing code in this project. Focus on unobvious details that agents might otherwise miss._

---

## Technology Stack & Versions

**Frontend (Mobile):**

- **Flutter** 3.41 (latest stable, March 2026) — `flutter create --org com.avishkagihan --project-name documind_ai --platforms ios,android ./mobile`
- **Dart** 3.x with null safety enabled by default
- **Riverpod** 3.2.1 — async-first state management (use `AsyncNotifier` exclusively)
- **go_router** — declarative URL-based routing
- **Dio** — HTTP client with interceptors
- **flutter_secure_storage** — iOS Keychain / Android Keystore for JWT tokens
- **Material 3** design system with custom `ThemeExtension` for design tokens
- **@freezed** — immutable state classes with `copyWith()`

**Backend (API):**

- **Python** 3.12+ with type hints
- **FastAPI** 0.135.1 — ASGI web framework
- **Pydantic** v2 — request/response validation and `BaseSettings` for typed config
- **SQLAlchemy** 2.0 — async ORM with `asyncpg` driver
- **Alembic** — database migrations (auto-generated from model changes)
- **Uvicorn** — ASGI server (`uvicorn app.main:app --reload --port 8000` for dev)

**AI/ML Pipeline:**

- **LangChain** 1.2.10 — RAG orchestration (use `langchain-groq` for Groq integration)
- **Groq** API — LLaMA 3.3 70B inference (free tier, rate-limited)
- **Sentence Transformers** 5.3.0 — local embedding generation (zero API cost)
- **ChromaDB** 1.5.5 — vector database (embedded mode for dev, client-server for prod)

**Database:**

- **SQLite** for local development → **PostgreSQL 16** for production
- **ChromaDB** — one collection per user-document pair: `user_{id}_doc_{id}`

**Infrastructure:**

- **Railway/Render** — backend hosting (Docker container)
- **AWS S3/Cloudinary** — PDF file storage with signed URLs
- **GitHub Actions** — CI/CD (pytest + ruff for backend; flutter test + flutter analyze for mobile)

---

## Critical Implementation Rules

### Language-Specific Rules

- **Python:** Always use `snake_case` for files, functions, variables, and modules. Classes use `PascalCase`. Constants use `UPPER_SNAKE_CASE`.
- **Dart:** Always use `snake_case` for files (e.g., `document_card.dart`). Classes use `PascalCase`. Functions and variables use `camelCase`. Constants use `camelCase` with `const`.
- **Python type hints are mandatory** on all function signatures — FastAPI and Pydantic require them.
- **Pydantic v2 syntax only** — use `model_validator` not `validator`, `ConfigDict` not inner `Config` class.
- **SQLAlchemy 2.0 style only** — use `select()` not `session.query()`, use `Mapped[]` type annotations.
- **Async/await everywhere** on backend — all service methods, repository methods, and route handlers must be `async def`.
- **All IDs are UUID4 strings** — use `uuid.uuid4()` in Python, string format in API responses.
- **Dates always UTC ISO 8601** — `2026-03-14T12:00:00Z` format. Never use local time in API responses.

### Framework-Specific Rules

**FastAPI (Backend):**

- **Dependency injection via `Depends()`** for all shared dependencies (database sessions, current user, services).
- **Routers handle HTTP concerns only** — parse request, call service, return response. No business logic in routers.
- **Services contain business logic** — orchestrate repositories and external services.
- **Repositories handle database access** — all SQLAlchemy queries live here, nowhere else.
- **All endpoints versioned** under `/api/v1/` prefix.
- **Pydantic response models required** on all endpoints — never return raw dicts or SQLAlchemy models.
- **`BackgroundTasks`** for document processing pipeline (not Celery for MVP).
- **`structlog`** for all backend logging — structured JSON format.

**Flutter (Frontend):**

- **Riverpod `AsyncNotifier`** for ALL async state — never use raw `setState()` or `StatefulWidget` for async data.
- **Provider naming:** `{feature}{Type}Provider` (e.g., `documentListProvider`, `chatMessagesProvider`, `authStateProvider`).
- **`ref.watch()`** for reactive UI rebuilds; **`ref.read()`** for one-time actions in event handlers only.
- **`ref.invalidateSelf()`** to trigger provider refetch after mutations.
- **State classes use `@freezed`** for immutable data with `copyWith()`.
- **`const` constructors** on all static widgets — mandatory for performance.
- **`ListView.builder`** for all scrollable lists — never `ListView(children: [...])` for dynamic data.
- **All colors, spacing, and fonts from theme tokens** — never hardcode `Color(0xFF...)` or `EdgeInsets.all(16)`.
- **Custom `ThemeExtension`** for DocuMind AI-specific design tokens.
- **`go_router` routes:** `/auth/login`, `/auth/signup`, `/library`, `/chat/:documentId`, `/settings`.

### Testing Rules

- **Backend testing:** `pytest` with `pytest-asyncio` for async tests. `httpx` `TestClient` for API integration tests.
- **Backend test structure:** `tests/unit/` for service logic, `tests/integration/` for API endpoints, `tests/fixtures/` for test data.
- **Frontend testing:** `flutter_test` for widget tests, `integration_test` for end-to-end flows.
- **Frontend test structure:** `test/unit/` for providers, `test/widget/` for custom widgets, `test/integration/` for user flows.
- **Test file naming:** `test_{module_name}.py` (Python), `{feature}_test.dart` (Dart).
- **Shared test fixtures** in `conftest.py` (Python) — test database, test client, authenticated user.
- **Code coverage target:** >80% on backend.
- **Linting:** `ruff` (Python), `flutter_lints` (Dart) — zero lint errors required.

### Code Quality & Style Rules

**API Response Formats (MUST follow exactly):**

- **Single item success:** Return the object directly as JSON.
- **List success:** `{"items": [...], "total": N, "page": 1, "page_size": 20}`.
- **Error response:** `{"detail": {"code": "ERROR_CODE", "message": "Human-readable message", "field": null}}`.
- **SSE streaming:** Events named `token`, `citation`, `done` with JSON data payloads.
- **JSON field naming:** `snake_case` in API (Python convention). Dart models convert to `camelCase` internally.
- **Null handling:** Omit null fields where possible; use explicit `null` only for nullable fields that must be present.

**File Organization:**

- Backend: `app/routers/`, `app/services/`, `app/models/`, `app/repositories/`, `app/schemas/`, `app/middleware/`.
- Frontend: Feature-based — `features/{feature}/data/`, `features/{feature}/providers/`, `features/{feature}/screens/`, `features/{feature}/widgets/`.
- Shared utilities: `app/` root (backend), `core/` and `shared/` (frontend).
- Config files at project root. `.env` is gitignored. `.env.example` is committed.

### Development Workflow Rules

- **Backend dev server:** `uvicorn app.main:app --reload --port 8000`.
- **Frontend dev:** `flutter run` with hot reload. Connects to `http://localhost:8000` in development.
- **API docs:** Auto-generated at `/docs` (Swagger) and `/redoc`. Always keep Pydantic schemas accurate.
- **Environment config:** `Pydantic BaseSettings` for typed config loading from `.env`. Never hardcode secrets.
- **Git CI:** Backend — `pytest` + `ruff` on push/PR. Frontend — `flutter test` + `flutter analyze` on push/PR. Auto-deploy to Railway/Render on merge to `main`.

### Critical Don't-Miss Rules

**Data Isolation (SECURITY-CRITICAL):**

- **Every** database query, vector store query, and file access MUST validate `user_id` ownership at the **service layer** — never trust client-side `user_id`.
- ChromaDB collection naming: `user_{id}_doc_{id}` — ensures physical data isolation.
- Delete operations must cascade: document deletion removes S3 file + ChromaDB collection + all conversations/messages.

**External Service Boundaries:**

- `storage_service.py` is the **sole** interface to S3/Cloudinary — no direct AWS SDK calls elsewhere.
- `vector_service.py` is the **sole** interface to ChromaDB — no direct Chroma client elsewhere.
- `llm_service.py` is the **sole** interface to Groq API — no direct HTTP calls to Groq elsewhere.
- `services/processing/embedder.py` is the **sole** interface to Sentence Transformers.
- **Never bypass** these abstraction layers — they enable testing and future service swaps.

**RAG Pipeline Rules:**

- Processing pipeline order: extractor → chunker → embedder → vector_service. Always sequential.
- Every Q&A response **must** include source page citations — this is the core product differentiator.
- Chunk metadata **must** preserve source page numbers for citation traceability.
- Default chunking: 500 tokens with 50-token overlap (tunable parameters, not hardcoded magic numbers).
- Conversation context window: manage history to stay within LLaMA 3.3 70B's 128K token limit.

**Authentication Rules:**

- JWT access token: 24-hour expiry. Refresh token: 7-day expiry.
- Mobile stores tokens via `flutter_secure_storage` (Keychain/Keystore) — never `SharedPreferences`.
- All endpoints require JWT except `/api/v1/auth/signup` and `/api/v1/auth/login`.
- Passwords: bcrypt hashing, 12-character minimum length.

**Performance Rules:**

- Q&A answer target: <5 seconds p95.
- 50-page PDF processing target: <30 seconds.
- App cold start target: <2 seconds.
- Use shimmer skeletons for loading states, pulsing dots for AI typing, linear progress for uploads.
- Rate limits: 20 Q&A queries/minute, 100 uploads/day per user (via `slowapi`).

**Anti-Patterns to AVOID:**

- ❌ Using `StatefulWidget` for async data — use Riverpod `AsyncNotifier` always.
- ❌ Hardcoding colors, fonts, or spacing — use theme tokens only.
- ❌ Returning raw dicts from API endpoints — use Pydantic response models.
- ❌ Direct database access from routers — go through services → repositories.
- ❌ Accessing external services without the gateway abstraction layer.
- ❌ Omitting `user_id` checks on data access — enforce at service layer.
- ❌ Using `session.query()` (SQLAlchemy 1.x style) — use `select()` (2.0 style).
- ❌ Using `SharedPreferences` for JWT tokens — use `flutter_secure_storage`.
- ❌ Returning API errors in non-standard format — always use `detail.code` + `detail.message`.

---

## Usage Guidelines

**For AI Agents:**

- Read this file before implementing any code
- Follow ALL rules exactly as documented
- When in doubt, prefer the more restrictive option
- Update this file if new patterns emerge

**For Humans:**

- Keep this file lean and focused on agent needs
- Update when technology stack changes
- Review quarterly for outdated rules
- Remove rules that become obvious over time

Last Updated: 2026-03-14
