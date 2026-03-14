---
stepsCompleted:
  - step-01-validate-prerequisites
  - step-02-design-epics
  - step-03-create-stories
  - step-04-final-validation
inputDocuments:
  - prd.md
  - architecture.md
  - ux-design-specification.md
workflowType: epics
project_name: documind-ai
user_name: Avishka Gihan
date: 2026-03-14
status: complete
---

# DocuMind AI - Epic Breakdown

## Overview

This document provides the complete epic and story breakdown for DocuMind AI, decomposing the requirements from the PRD, UX Design Specification, and Architecture document into implementable stories.

## Requirements Inventory

### Functional Requirements

FR1: Users can create an account using email and password.
FR2: Users can log in with existing credentials and receive a secure session token.
FR3: Users can log out, invalidating their current session.
FR4: Users can reset their password via email link.
FR5: Users can upload a PDF file (up to 50 MB) from their mobile device.
FR6: Users can view upload progress with a percentage indicator.
FR7: The system stores uploaded PDFs in cloud storage (Cloudinary/S3) associated with the user's account.
FR8: Users can delete an uploaded document and all associated data (vectors, chat history).
FR9: The system extracts text content from uploaded PDFs with page-level metadata preservation.
FR10: The system splits extracted text into overlapping chunks optimized for semantic search.
FR11: The system generates vector embeddings for each chunk using Sentence Transformers.
FR12: The system stores embeddings in ChromaDB with source page number metadata.
FR13: The system updates the document status (processing → ready → error) throughout the pipeline.
FR14: Users can type a natural-language question about a selected document.
FR15: The system retrieves the top-k most relevant document chunks based on semantic similarity to the question.
FR16: The system generates an answer using the retrieved chunks as context via LLaMA 3.3 70B.
FR17: Every answer includes source page reference citations (e.g., "According to page 4…").
FR18: Users can view streaming answer text as it is generated.
FR19: The system maintains conversation history within a Q&A session for a given document.
FR20: Follow-up questions incorporate prior conversation context for accurate interpretation.
FR21: Users can view the full conversation history for a document session.
FR22: Users can start a new conversation session for the same document, clearing prior context.
FR23: Users can view a list of all their uploaded documents with titles and status indicators.
FR24: Users can switch between documents for Q&A, each maintaining its own conversation context.
FR25: Users can see document metadata (upload date, page count, file size, processing status).
FR26: Users can search or filter their document library by document title.
FR27: The app provides a responsive chat interface optimized for mobile screen sizes.
FR28: The app caches document library metadata and chat history for offline viewing.
FR29: The app queues PDF uploads initiated while offline for processing when connectivity restores.
FR30: The app displays clear loading states during document processing and answer generation.
FR31: The system provides clear error messages when document processing fails (unsupported format, corrupted file, excessive size).
FR32: The system notifies users when a question cannot be answered from the available document content.
FR33: The system communicates rate limit status and expected wait times if Groq API limits are reached.

### Non-Functional Requirements

NFR1: API response time for Q&A queries < 5 seconds for 95th percentile.
NFR2: Document processing throughput — 50-page PDF processed in < 30 seconds.
NFR3: Mobile app cold start time < 2 seconds.
NFR4: Chat interface scroll performance — 60fps consistent.
NFR5: Concurrent user support — 10 simultaneous users minimum.
NFR6: JWT tokens with secure storage (iOS Keychain / Android Keystore); tokens expire after 24 hours.
NFR7: Users can only access their own documents and conversations; server-side enforcement.
NFR8: All API communication over HTTPS/TLS 1.2+.
NFR9: Server validates uploaded files are genuine PDFs before processing; reject non-PDF files.
NFR10: Full deletion of user data (documents, embeddings, chat history) upon user request within 24 hours.
NFR11: Passwords hashed using bcrypt with minimum 12-character requirement.
NFR12: Document storage supports up to 100 documents per user, up to 500 pages each.
NFR13: ChromaDB collections scale to 100,000+ vectors per user.
NFR14: Backend designed for stateless deployment behind load balancer.
NFR15: Per-user rate limits prevent abuse (20 queries/minute, 100 uploads/day).
NFR16: Screen reader support — VoiceOver (iOS) and TalkBack (Android) compatible for all primary flows.
NFR17: Text scaling — supports system font size preferences up to 200%.
NFR18: Color contrast — WCAG 2.1 AA contrast ratios (4.5:1 for normal text).
NFR19: Minimum 44×44pt touch targets for all interactive elements.
NFR20: Respects system "Reduce Motion" preferences.
NFR21: Groq API integration with graceful fallback on API unavailability.
NFR22: Cloud file storage (Cloudinary/S3) with signed URLs for secure document access.

### Additional Requirements

- Architecture specifies a **starter template** for both frontend and backend:
  - Frontend: `flutter create --org com.avishkagihan --project-name documind_ai --platforms ios,android ./mobile`
  - Backend: Manual FastAPI project setup with `requirements.txt` dependencies
  - This must be implemented as Epic 1, Story 1 (project initialization)
- SQLAlchemy 2.0 with async support and Alembic for database migrations
- Pydantic v2 for API request/response validation with consistent error response format
- Riverpod 3.2.1 for state management (AsyncNotifier pattern)
- go_router for declarative routing
- SSE (Server-Sent Events) for streaming AI answers to the mobile client
- structlog for structured JSON logging in backend
- `slowapi` for per-user rate limiting middleware
- Feature-based frontend directory structure and module-based backend organization
- `flutter_secure_storage` for secure token storage on mobile
- All external services accessed through dedicated abstraction layers (storage_service, vector_service, llm_service)
- Docker-based deployment to Railway/Render for the backend
- GitHub Actions CI/CD pipeline for both backend and frontend

### UX Design Requirements

UX-DR1: Implement custom design token system — color tokens (surface-primary #0D1117, accent-primary #58A6FF, accent-citation #D2A8FF, etc.), spacing scale (4px base unit, xs through 3xl), and typography tokens (Inter for UI, JetBrains Mono for code/citations).
UX-DR2: Implement dark mode as the primary theme using "Hybrid Premium" direction — deep dark surfaces with glassmorphic accents, purple/lilac citation chips, electric blue primary accent, green success states.
UX-DR3: Implement light mode as a secondary toggle option with the documented light mode color equivalents.
UX-DR4: Build the Citation Chip custom widget — inline tappable page reference badges (Icon + "Page X" label + purple accent background), with tap-to-expand showing source text excerpt, disabled state, single/range/group variants, and accessibility labels.
UX-DR5: Build the Document Card custom widget — glassmorphic card with PDF icon/thumbnail, title, metadata row (pages, size, date), and status indicator (processing = animated glow border, ready = green dot, error = red dot + retry); tap opens chat, long-press shows context menu.
UX-DR6: Build the AI Response Bubble custom widget — chat bubble with avatar/icon, streaming text rendering (ChatGPT-style character-by-character), inline citation chips, timestamp; states: typing, streaming, complete, error; variants: text-only, text-with-citations, code-block.
UX-DR7: Build the User Question Bubble custom widget — visually distinct from AI Response Bubble, consistent styling with the design system.
UX-DR8: Build the AI Typing Indicator widget — three pulsing dots with subtle AI glow effect (#79C0FF), respects Reduce Motion preference.
UX-DR9: Build the Processing Animation Widget — multi-stage progress (Extracting → Chunking → Indexing → Complete → Failed) with circular progress, stage icon, and descriptive text.
UX-DR10: Build the Chat Input Bar — bottom-anchored single-line text field with auto-expand (max 4 lines), send button disabled until text entered, placeholder "Ask a question about this document...", keyboard-aware layout.
UX-DR11: Implement Empty State illustrations and messaging — Empty Library ("Upload your first PDF" + upload CTA), Empty Chat ("Ask your first question about [Document Name]" + suggested questions), No Search Results.
UX-DR12: Implement bottom tab navigation with Library (📚), Chat (💬), and Settings (⚙️) tabs, including badge counts for processing documents.
UX-DR13: Implement glassmorphic container widget using BackdropFilter for document cards, bottom sheets, and overlays.
UX-DR14: Implement button hierarchy — Primary (filled, accent blue), Secondary (outlined), Tertiary (text-only), Destructive (filled, red), Icon (circular); maximum 1 primary per screen, 44×44pt minimum touch area.
UX-DR15: Implement feedback patterns — success (green SnackBar, 3s), error (red SnackBar, persistent), warning (amber, 5s), info (blue, 4s), loading (skeleton shimmer), progress (linear bar + text).
UX-DR16: Implement responsive layouts with breakpoints: Small Phone (320–374px), Standard Phone (375–427px), Large Phone (428–767px), Tablet Portrait (768–1023px), Tablet Landscape (1024px+).
UX-DR17: Implement accessibility: WCAG 2.1 AA contrast, Semantics widget wrapping on all interactive elements, live region announcements for streaming AI answers, tooltip on all icon buttons, FocusNode management for keyboard navigation, text scaling at 200%.
UX-DR18: Implement spring-based animation system (Curves.easeOutBack) for page transitions, chat bubble entry, and document card interactions; Hero animation for document card → chat transition.

### FR Coverage Map

FR1: Epic 2 — User Registration with Email and Password
FR2: Epic 2 — User Login with Secure Session Token
FR3: Epic 2 — User Logout
FR4: Epic 2 — Password Reset via Email
FR5: Epic 3 — PDF Upload from Mobile Device
FR6: Epic 3 — Upload Progress Indicator
FR7: Epic 3 — Cloud Storage Association
FR8: Epic 4 — Document Deletion with Cascading Data Cleanup
FR9: Epic 3 — Text Extraction with Page Metadata
FR10: Epic 3 — Overlapping Chunking for Semantic Search
FR11: Epic 3 — Vector Embedding Generation
FR12: Epic 3 — ChromaDB Storage with Page Metadata
FR13: Epic 3 — Document Processing Status Updates
FR14: Epic 5 — Natural-Language Question Input
FR15: Epic 5 — Semantic Similarity Retrieval
FR16: Epic 5 — LLM Answer Generation via Groq
FR17: Epic 5 — Source Page Citation in Answers
FR18: Epic 5 — Streaming Answer Display
FR19: Epic 5 — Conversation History Maintained Per Session
FR20: Epic 5 — Follow-Up Questions with Context
FR21: Epic 5 — Full Conversation History Viewing
FR22: Epic 5 — New Conversation Session
FR23: Epic 4 — Document Library List with Status
FR24: Epic 4 — Document Switching with Isolated Context
FR25: Epic 4 — Document Metadata Display
FR26: Epic 4 — Document Library Search and Filter
FR27: Epic 6 — Responsive Mobile Chat Interface
FR28: Epic 6 — Offline Caching for Library and Chat
FR29: Epic 6 — Offline Upload Queuing
FR30: Epic 6 — Loading States for Processing and Answers
FR31: Epic 6 — Error Messages for Processing Failures
FR32: Epic 6 — Unanswerable Question Notification
FR33: Epic 6 — Rate Limit Status Communication

## Epic List

### Epic 1: Project Foundation & Design System Setup
Set up both Flutter mobile and FastAPI backend projects from scratch using the specified starter templates, establish the design token system, and configure the development environment so that all subsequent epics build on a consistent, well-structured foundation.
**FRs covered:** None directly (infrastructure epic enabling all FRs)

### Epic 2: User Authentication & Account Management
Users can create an account, log in, log out, and reset their password — enabling secure, per-user document isolation across the entire application.
**FRs covered:** FR1, FR2, FR3, FR4

### Epic 3: Document Upload & AI Processing Pipeline
Users can upload PDF documents from their mobile device, view upload progress, and have the system automatically process documents through the full RAG pipeline (extraction → chunking → embedding → vector storage) with real-time status updates.
**FRs covered:** FR5, FR6, FR7, FR9, FR10, FR11, FR12, FR13

### Epic 4: Document Library & Management
Users can view, browse, search, and manage their uploaded documents in a polished library interface, switch between documents, and delete documents with full data cleanup.
**FRs covered:** FR8, FR23, FR24, FR25, FR26

### Epic 5: Conversational Q&A with Cited Answers
Users can ask natural-language questions about their documents and receive streaming, cited answers powered by RAG, maintain conversation memory for follow-up questions, and manage conversation sessions.
**FRs covered:** FR14, FR15, FR16, FR17, FR18, FR19, FR20, FR21, FR22

### Epic 6: Mobile Experience Polish, Error Handling & Accessibility
The app delivers a polished, accessible mobile experience with responsive layouts, offline capabilities, comprehensive error handling, loading states, and full WCAG 2.1 AA accessibility compliance.
**FRs covered:** FR27, FR28, FR29, FR30, FR31, FR32, FR33

---

## Epic 1: Project Foundation & Design System Setup

Enable all future development by initializing the Flutter mobile and FastAPI backend projects using the architecture-specified starter templates, establishing the design token system, and configuring routing, state management, and CI/CD infrastructure.

### Story 1.1: Initialize Backend Project with FastAPI and Dependencies

As a developer,
I want to set up the FastAPI backend project with the correct directory structure and all required dependencies installed,
So that I have a working backend foundation to build all API features upon.

**Acceptance Criteria:**

**Given** no backend project exists
**When** I create the `backend/` directory and initialize the FastAPI project
**Then** the directory structure matches the architecture specification (app/, app/routers/, app/services/, app/models/, app/schemas/, app/repositories/, app/middleware/, tests/)
**And** `requirements.txt` contains all specified dependencies: fastapi[standard]==0.135.1, uvicorn[standard], langchain==1.2.10, chromadb==1.5.5, sentence-transformers==5.3.0, python-multipart, pydantic[email], python-jose[cryptography], passlib[bcrypt], boto3, aiofiles, sqlalchemy[asyncio], alembic, asyncpg, slowapi, structlog, pytest, pytest-asyncio, httpx, ruff
**And** `app/main.py` creates a FastAPI app instance with CORS middleware configured
**And** `app/config.py` uses Pydantic `BaseSettings` for typed environment configuration
**And** `.env.example` documents all required environment variables
**And** `uvicorn app.main:app --reload --port 8000` starts the server and `/docs` returns the Swagger UI

### Story 1.2: Initialize Flutter Mobile Project with Design System Foundation

As a developer,
I want to create the Flutter mobile project with the design token system, theme configuration, and custom fonts,
So that all UI components built in future epics use consistent, premium styling from the start.

**Acceptance Criteria:**

**Given** no mobile project exists
**When** I run `flutter create --org com.avishkagihan --project-name documind_ai --platforms ios,android ./mobile`
**Then** the Flutter project is created with iOS and Android platform support
**And** `pubspec.yaml` includes dependencies: flutter_riverpod (^3.2.1), go_router, dio, flutter_secure_storage, freezed_annotation, json_annotation, build_runner, freezed, json_serializable
**And** Inter and JetBrains Mono font files are added to `assets/fonts/` and registered in `pubspec.yaml`
**And** `lib/core/theme/app_colors.dart` defines all design token colors (surface-primary #0D1117, accent-primary #58A6FF, accent-citation #D2A8FF, etc.) for both dark and light modes
**And** `lib/core/theme/app_typography.dart` defines the complete type scale using Inter and JetBrains Mono
**And** `lib/core/theme/app_spacing.dart` defines the spacing scale (xs=4px through 3xl=48px)
**And** `lib/core/theme/app_theme.dart` creates `ThemeData` with custom `ColorScheme` and `ThemeExtension` for dark mode (primary) and light mode (secondary)
**And** `flutter run` launches the app with the custom dark theme applied

### Story 1.3: Configure Routing, State Management, and App Shell

As a developer,
I want to set up go_router navigation with bottom tab bar, Riverpod provider scope, and the app scaffold,
So that the app has a working navigation structure for all future feature screens.

**Acceptance Criteria:**

**Given** the Flutter project with design system is set up
**When** I configure routing and state management
**Then** `lib/router.dart` defines routes: `/auth/login`, `/auth/signup`, `/library`, `/chat/:documentId`, `/settings`
**And** `lib/app.dart` wraps the app in `ProviderScope` and applies the custom `ThemeData`
**And** `lib/shared/widgets/app_scaffold.dart` provides a bottom tab bar with Library (📚), Chat (💬), and Settings (⚙️) tabs
**And** Tab navigation switches between placeholder screens for Library, Chat, and Settings
**And** The bottom tab bar uses design tokens for styling (accent colors, 44×44pt touch targets)
**And** Unauthenticated routes redirect to `/auth/login`

### Story 1.4: Set Up Database Models and Alembic Migrations

As a developer,
I want to define the SQLAlchemy data models and configure Alembic migrations,
So that the database schema is version-controlled and ready for feature development.

**Acceptance Criteria:**

**Given** the FastAPI backend project is initialized
**When** I create the database models and migration setup
**Then** `app/database.py` configures SQLAlchemy async engine and session factory (supporting SQLite for dev, PostgreSQL for prod)
**And** `app/models/user.py` defines a User model with: id (UUID), email (unique), hashed_password, created_at, updated_at
**And** `app/models/document.py` defines a Document model with: id (UUID), user_id (FK), title, file_path, file_size, page_count, status (enum: processing, extracting, chunking, embedding, ready, error), created_at, updated_at
**And** `app/models/conversation.py` defines a Conversation model with: id (UUID), document_id (FK), user_id (FK), created_at, updated_at
**And** `app/models/message.py` defines a Message model with: id (UUID), conversation_id (FK), role (enum: user, assistant), content, citations (JSON), created_at
**And** `alembic.ini` and `alembic/env.py` are configured for async SQLAlchemy
**And** An initial migration is generated and applies successfully creating all tables
**And** All table names follow `snake_case`, plural convention (users, documents, conversations, messages)

### Story 1.5: Configure CI/CD Pipeline with GitHub Actions

As a developer,
I want to set up GitHub Actions workflows for both backend and frontend,
So that code quality is automatically validated on every push and pull request.

**Acceptance Criteria:**

**Given** both backend and frontend projects are initialized
**When** I create CI/CD configuration files
**Then** `.github/workflows/backend-ci.yml` runs on push/PR: installs Python dependencies, runs `ruff` linting, runs `pytest`
**And** `.github/workflows/mobile-ci.yml` runs on push/PR: installs Flutter, runs `flutter analyze`, runs `flutter test`
**And** Both workflows use appropriate caching (pip cache, pub cache) for faster execution
**And** Both workflows pass successfully on the initial codebase

---

## Epic 2: User Authentication & Account Management

Users can create an account, log in with email and password, log out, and reset their password — providing secure, per-user document isolation.

### Story 2.1: User Registration API Endpoint

As a new user,
I want to create an account using my email and password,
So that I have a personal, secure space for my documents and conversations.

**Acceptance Criteria:**

**Given** I am a new user without an account
**When** I send a POST request to `/api/v1/auth/signup` with a valid email and password (≥12 characters)
**Then** a new user record is created with the password hashed using bcrypt
**And** a JWT access token (24-hour expiry) and refresh token (7-day expiry) are returned
**And** the response follows the standard success format with user id and email

**Given** I provide an email that is already registered
**When** I send a POST request to `/api/v1/auth/signup`
**Then** a 409 Conflict error is returned with `detail.code: "EMAIL_ALREADY_EXISTS"`

**Given** I provide a password shorter than 12 characters
**When** I send a POST request to `/api/v1/auth/signup`
**Then** a 422 Unprocessable Entity error is returned with `detail.code: "VALIDATION_ERROR"` and `detail.field: "password"`

### Story 2.2: User Login API Endpoint

As a registered user,
I want to log in with my email and password,
So that I can access my documents and conversations securely.

**Acceptance Criteria:**

**Given** I am a registered user with valid credentials
**When** I send a POST request to `/api/v1/auth/login` with correct email and password
**Then** a JWT access token (24-hour expiry) and refresh token (7-day expiry) are returned
**And** the response includes user id and email

**Given** I provide incorrect credentials
**When** I send a POST request to `/api/v1/auth/login`
**Then** a 401 Unauthorized error is returned with `detail.code: "INVALID_CREDENTIALS"`

### Story 2.3: JWT Authentication Middleware and Logout

As a logged-in user,
I want my requests to be authenticated via JWT and be able to log out,
So that my session is secure and I can terminate it when needed.

**Acceptance Criteria:**

**Given** I have a valid JWT access token
**When** I include it in the `Authorization: Bearer <token>` header on any authenticated endpoint
**Then** the request is processed with my user context extracted from the token

**Given** I have an expired or invalid JWT token
**When** I make a request to any authenticated endpoint
**Then** a 401 Unauthorized error is returned with `detail.code: "TOKEN_EXPIRED"` or `"INVALID_TOKEN"`

**Given** I am logged in
**When** I send a POST request to `/api/v1/auth/logout`
**Then** my current session is invalidated and a 200 success response is returned

### Story 2.4: Password Reset via Email

As a registered user who forgot my password,
I want to request a password reset link via email,
So that I can regain access to my account.

**Acceptance Criteria:**

**Given** I am a registered user who has forgotten my password
**When** I send a POST request to `/api/v1/auth/reset-password` with my email
**Then** a password reset token is generated and a reset link is sent to my email
**And** a 200 response is returned (regardless of whether email exists, to prevent enumeration)

**Given** I have a valid password reset token
**When** I send a POST request to `/api/v1/auth/reset-password/confirm` with the token and a new password (≥12 characters)
**Then** my password is updated with bcrypt hashing and all existing sessions are invalidated

**Given** I have an expired or invalid reset token
**When** I attempt to confirm the password reset
**Then** a 400 Bad Request error is returned with `detail.code: "INVALID_RESET_TOKEN"`

### Story 2.5: Flutter Authentication Screens and Token Management

As a mobile user,
I want to see polished login and signup screens and have my session persist securely,
So that I can authenticate and stay logged in across app restarts.

**Acceptance Criteria:**

**Given** I open the app without a saved token
**When** the app loads
**Then** I am redirected to the Login screen with email and password fields, a sign-up link, and a forgot password link
**And** the screens use the design token system (dark mode, Inter font, accent colors, proper spacing)

**Given** I fill in valid credentials on the Login screen
**When** I tap the Login button
**Then** the button shows a loading state, the API is called, the JWT token is securely stored using `flutter_secure_storage`, and I am navigated to the Document Library

**Given** I fill in valid details on the Signup screen
**When** I tap the Sign Up button
**Then** a new account is created, the token is stored, and I am navigated to the Welcome/Library screen

**Given** I have a saved valid token from a previous session
**When** I open the app
**Then** I am automatically logged in and taken to the Document Library without seeing the login screen

**And** form fields show real-time inline validation (email format, password length ≥12)
**And** error messages appear below the relevant field, not as alerts
**And** all touch targets meet the 44×44pt minimum requirement

---

## Epic 3: Document Upload & AI Processing Pipeline

Users can upload PDF documents from their mobile device, see upload progress, and have the system automatically process documents through the full RAG pipeline with real-time status feedback.

### Story 3.1: PDF Upload API and Cloud Storage

As a user,
I want to upload a PDF file from my phone to the cloud,
So that the system can store and process it for Q&A.

**Acceptance Criteria:**

**Given** I am an authenticated user
**When** I send a multipart POST request to `/api/v1/documents/upload` with a PDF file (≤50 MB)
**Then** the file is uploaded to S3/Cloudinary with the user's account association
**And** a new Document record is created with status `processing`, title extracted from filename, file_size, and file_path
**And** the response returns the document id, title, status, and created_at

**Given** I upload a file that is not a genuine PDF (wrong magic bytes or extension)
**When** the server validates the file
**Then** a 422 error is returned with `detail.code: "INVALID_FILE_TYPE"` and `detail.message: "Only PDF files are supported"`

**Given** I upload a file larger than 50 MB
**When** the server validates the file
**Then** a 413 error is returned with `detail.code: "FILE_TOO_LARGE"`

### Story 3.2: Document Processing Pipeline — Text Extraction and Chunking

As a system,
I want to extract text from uploaded PDFs with page-level metadata and split it into overlapping chunks,
So that the content is prepared for embedding generation and semantic search.

**Acceptance Criteria:**

**Given** a PDF has been uploaded and stored in cloud storage
**When** the background processing task starts
**Then** the document status is updated to `extracting`
**And** `services/processing/extractor.py` extracts all text content with page number metadata preserved for each text segment
**And** the document status is updated to `chunking`
**And** `services/processing/chunker.py` splits the extracted text into overlapping chunks (default: 500 tokens, 50 token overlap) with source page numbers preserved
**And** each chunk retains metadata: `page_number`, `chunk_index`, `document_id`

**Given** the PDF has poor OCR quality or is empty
**When** text extraction fails or yields minimal text
**Then** the document status is updated to `error` with an error message describing the issue

### Story 3.3: Embedding Generation and Vector Storage

As a system,
I want to generate vector embeddings for document chunks and store them in ChromaDB,
So that semantic similarity search can be performed during Q&A.

**Acceptance Criteria:**

**Given** text chunks with page metadata have been created from a document
**When** the embedding stage runs
**Then** the document status is updated to `embedding`
**And** `services/processing/embedder.py` generates vector embeddings for each chunk using Sentence Transformers (local model)
**And** `services/vector_service.py` creates a ChromaDB collection named `user_{user_id}_doc_{document_id}`
**And** all chunk embeddings are stored in the collection with metadata: page_number, chunk_text, chunk_index
**And** upon successful completion, the document status is updated to `ready`

**Given** embedding generation or ChromaDB storage fails
**When** an error occurs during the embedding stage
**Then** the document status is updated to `error` with a descriptive error message
**And** partial embeddings are cleaned up

### Story 3.4: Flutter Document Upload UI with Progress

As a mobile user,
I want to upload a PDF from my phone with a visible progress indicator,
So that I know the upload is working and can see when it completes.

**Acceptance Criteria:**

**Given** I am on the Document Library screen
**When** I tap the Upload/FAB button (+)
**Then** the native file picker opens filtered for PDF files

**Given** I select a PDF file from the file picker
**When** the upload begins
**Then** a Document Card appears in the library with a linear progress bar showing upload percentage
**And** the upload uses multipart form data with progress tracking via Dio's `onSendProgress`

**Given** the upload completes successfully
**When** the server responds with the document record
**Then** the Document Card transitions to show "Processing..." status with an animated glow border
**And** the card displays the document title, file size, and page count

**Given** the upload fails (network error, file too large)
**When** an error occurs
**Then** an error SnackBar appears (persistent, red) with a "Retry" action
**And** the failed upload can be retried

### Story 3.5: Document Processing Status Tracking and Animation

As a mobile user,
I want to see real-time processing status for my uploaded documents,
So that I know the system is working and when my document is ready for Q&A.

**Acceptance Criteria:**

**Given** a document has been uploaded and is being processed
**When** I view the Document Library
**Then** the document card shows a Processing Animation Widget with descriptive stages:
  - 📖 "Extracting text..." (with page counter if available)
  - 🧩 "Creating knowledge chunks..."
  - 🧠 "Building intelligence index..."
  - ✅ "Ready to answer your questions!"

**Given** the document processing completes
**When** the status changes to `ready`
**Then** the Processing Animation transitions to a green success dot with a subtle celebration animation
**And** the card becomes tappable to open the Chat screen

**Given** the document processing fails
**When** the status changes to `error`
**Then** the card shows a red error dot with the error message and a "Retry" option

**And** status polling uses periodic API calls (every 3 seconds) to check document status

---

## Epic 4: Document Library & Management

Users can view, browse, search, and manage their uploaded documents in a polished library interface, and delete documents with full cascading data cleanup.

### Story 4.1: Document Library API Endpoints

As a user,
I want to retrieve my document list, view document details, and search by title,
So that I can manage my uploaded documents.

**Acceptance Criteria:**

**Given** I am an authenticated user with uploaded documents
**When** I send a GET request to `/api/v1/documents`
**Then** a paginated list of my documents is returned (default page_size=20) with id, title, status, page_count, file_size, created_at for each document
**And** only documents belonging to the authenticated user are returned (server-side enforcement)

**Given** I provide a `search` query parameter
**When** I send a GET request to `/api/v1/documents?search=contract`
**Then** only documents whose title contains the search term are returned (case-insensitive)

**Given** I send a GET request to `/api/v1/documents/{document_id}`
**When** the document belongs to me
**Then** full document details are returned including metadata

**Given** I try to access another user's document
**When** I send a GET request with their document_id
**Then** a 404 Not Found error is returned (not 403, to prevent ID enumeration)

### Story 4.2: Document Deletion with Cascading Data Cleanup

As a user,
I want to delete a document and have all associated data removed,
So that I maintain control over my data and storage.

**Acceptance Criteria:**

**Given** I am the owner of a document
**When** I send a DELETE request to `/api/v1/documents/{document_id}`
**Then** the PDF file is deleted from cloud storage (S3/Cloudinary)
**And** the ChromaDB collection (`user_{user_id}_doc_{document_id}`) is deleted with all embeddings
**And** all conversation and message records associated with the document are deleted
**And** the document record is deleted from the database
**And** a 204 No Content response is returned

**Given** I try to delete a document that doesn't exist or isn't mine
**When** I send a DELETE request
**Then** a 404 Not Found error is returned

### Story 4.3: Flutter Document Library Screen

As a mobile user,
I want to view my document library as a polished list of document cards,
So that I can see all my documents, their status, and quickly access any document for Q&A.

**Acceptance Criteria:**

**Given** I am logged in
**When** I navigate to the Library tab
**Then** I see a list of Document Cards (glassmorphic style) showing: PDF icon, document title, metadata row (page count, file size, upload date), and status indicator (green dot = ready, animated glow = processing, red dot = error)
**And** the list uses `ListView.builder` for efficient lazy-loading
**And** pull-to-refresh reloads the document list

**Given** I have no uploaded documents
**When** I view the Library screen
**Then** I see an Empty State illustration with "Upload your first PDF" message and a prominent Upload CTA button

**Given** I tap on a "ready" document card
**When** the card is tapped
**Then** a Hero animation transitions the card to the Chat screen for that document

**Given** I long-press on a document card
**When** the context menu appears
**Then** I see options: "Delete" (with confirmation dialog) and "Info" (shows full metadata)

### Story 4.4: Document Library Search and Filter

As a mobile user,
I want to search and filter my document library,
So that I can quickly find specific documents when I have many uploaded.

**Acceptance Criteria:**

**Given** I am on the Document Library screen
**When** I tap the search icon
**Then** a search text field appears at the top of the screen

**Given** I type a search query
**When** I enter text in the search field
**Then** the document list filters in real-time to show only documents whose titles match the query (case-insensitive)
**And** if no documents match, the "No documents match your search" empty state is displayed with a "Clear search" action

**Given** I want to sort my documents
**When** I access the sort options
**Then** I can sort by: Date (newest first, default), Name (alphabetical), Status (processing first)

---

## Epic 5: Conversational Q&A with Cited Answers

Users can ask questions about their documents and receive streaming, cited answers with conversation memory for natural follow-up questions.

### Story 5.1: RAG Pipeline — Semantic Retrieval and Answer Generation API

As a user,
I want to ask a question about my document and receive an accurate, cited answer,
So that I can extract information without reading the entire document.

**Acceptance Criteria:**

**Given** I have a "ready" document and am authenticated
**When** I send a POST request to `/api/v1/documents/{document_id}/ask` with a question text
**Then** `services/rag_service.py` generates an embedding for the question using the same Sentence Transformer model
**And** `services/vector_service.py` performs similarity search on the document's ChromaDB collection and retrieves the top-k (default: 5) most relevant chunks with page metadata
**And** `services/llm_service.py` sends the retrieved chunks + question + system prompt to Groq LLaMA 3.3 70B
**And** the system prompt instructs the LLM to include page citations in the format "According to page X..."
**And** the response includes the answer text and a structured citations array with page numbers and source text

**Given** the document has no relevant content for the question
**When** the retrieval finds no chunks above the similarity threshold
**Then** the system returns a message: "I couldn't find relevant information for this question in the document."

### Story 5.2: Streaming Answer Endpoint with SSE

As a user,
I want to see the answer appear progressively as it's being generated,
So that I get faster perceived response times and an engaging experience.

**Acceptance Criteria:**

**Given** I send a question to `/api/v1/documents/{document_id}/ask` with `Accept: text/event-stream` header
**When** the LLM generates the answer
**Then** the response is an SSE stream with events:
  - `event: token` / `data: {"content": "partial text"}` — for each generated token
  - `event: citation` / `data: {"page": 4, "text": "relevant chunk text"}` — when a citation is referenced
  - `event: done` / `data: {"message_id": "uuid"}` — when generation is complete

**Given** the Groq API is unavailable or rate-limited
**When** the LLM call fails
**Then** an `event: error` / `data: {"code": "LLM_UNAVAILABLE", "message": "..."}` is sent and the stream ends

**And** a conversation record and message records (user question + assistant answer) are created/updated upon stream completion

### Story 5.3: Conversation Memory and Context Management

As a user,
I want my follow-up questions to understand the context of my previous questions,
So that I can have natural, multi-turn conversations with my documents.

**Acceptance Criteria:**

**Given** I have an active conversation with a document
**When** I ask a follow-up question
**Then** the previous conversation history (up to the context window limit) is included in the LLM prompt alongside the new question and retrieved chunks
**And** the answer correctly references prior conversation context

**Given** the conversation history exceeds the LLM context window
**When** a new question is asked
**Then** the system truncates older messages while preserving the system prompt and the most recent N messages

**Given** I want to start fresh with the same document
**When** I send a POST request to `/api/v1/documents/{document_id}/conversations/new`
**Then** a new conversation is created, previous context is cleared, and the new conversation ID is returned

**Given** I want to view my conversation history
**When** I send a GET request to `/api/v1/documents/{document_id}/conversations/{conversation_id}/messages`
**Then** all messages (user questions and assistant answers with citations) are returned in chronological order

### Story 5.4: Flutter Chat Screen with Streaming Answers

As a mobile user,
I want a polished chat interface where I can ask questions and see answers appear in real-time with citation chips,
So that the Q&A experience feels conversational, trustworthy, and engaging.

**Acceptance Criteria:**

**Given** I open a "ready" document from the Library
**When** the Chat screen loads
**Then** I see a chat interface with: the document title in the top bar, previous conversation messages (if any), and a Chat Input Bar anchored at the bottom

**Given** I type a question and tap Send
**When** the question is submitted
**Then** a User Question Bubble appears in the chat, an AI Typing Indicator (3 pulsing dots with glow) is shown, and the answer begins streaming in an AI Response Bubble character-by-character
**And** Citation Chips (📄 Page X, purple/lilac accent) appear inline as the answer renders
**And** the chat auto-scrolls to show the latest content

**Given** I tap on a Citation Chip
**When** the chip is tapped
**Then** it expands to show the relevant source text excerpt from that page
**And** tapping again collapses it back

**Given** the answer completes streaming
**When** the `done` event is received
**Then** the AI Typing Indicator disappears, the full answer with all citations is displayed, and a timestamp is shown

**And** the Chat Input Bar auto-expands to max 4 lines, with the Send button disabled when empty
**And** the keyboard-aware layout prevents content from being obscured by the keyboard
**And** the interface uses spring-based animations for bubble entry (Curves.easeOutBack)

### Story 5.5: Conversation Management and Document Switching

As a mobile user,
I want to switch between documents' conversations and start new conversations,
So that I can work with multiple documents without losing context.

**Acceptance Criteria:**

**Given** I am in a chat with Document A
**When** I tap the document selector in the top bar
**Then** a bottom sheet shows all my "ready" documents, and I can tap to switch to Document B
**And** Document B's chat loads its own conversation history (context isolation — no bleed from Document A)

**Given** I want a fresh start with the current document
**When** I tap "New Conversation"
**Then** a confirmation is shown, and upon confirming, the chat clears and a new conversation session is created
**And** the previous conversation is preserved and accessible from the conversation history

**Given** I return to a document I previously chatted with
**When** I open the chat for that document
**Then** my previous conversation messages are loaded and displayed in the chat

---

## Epic 6: Mobile Experience Polish, Error Handling & Accessibility

The app delivers a polished, accessible mobile experience with responsive layouts, offline handling, comprehensive error feedback, and WCAG 2.1 AA accessibility.

### Story 6.1: Responsive Mobile Chat and Library Layout

As a mobile user,
I want the app to look and feel great on any phone or tablet screen size,
So that I have a premium experience regardless of my device.

**Acceptance Criteria:**

**Given** I am using a small phone (320px width)
**When** I use the app
**Then** all layouts adapt with compact spacing, readable font sizes, and no content clipping or overflow

**Given** I am using a standard phone (375px–427px)
**When** I use the app
**Then** the default layout applies with standard spacing and component sizing

**Given** I am using a tablet in portrait (768px+)
**When** I use the app
**Then** the document library shows a two-column grid and the chat view optionally shows a split layout

**And** all screens use `MediaQuery` and `LayoutBuilder` for responsive behavior
**And** no fixed pixel widths are used — layouts use `Flexible`, `Expanded`, and percentage-based sizing
**And** the chat interface scroll performance is consistently 60fps

### Story 6.2: Offline Caching and Upload Queuing

As a mobile user,
I want to view my document library and chat history even when offline, and have uploads queued for later,
So that I can use the app during commutes with intermittent connectivity.

**Acceptance Criteria:**

**Given** I have previously loaded my document library and chat history
**When** I lose network connectivity
**Then** the document library (titles, metadata, status) is displayed from local cache (SQLite or Hive)
**And** previous chat conversations are viewable from local cache

**Given** I am offline and try to ask a question
**When** I tap Send
**Then** a clear message is shown: "Q&A requires an internet connection. Your question will be sent when connectivity restores." or similar feedback

**Given** I select a PDF to upload while offline
**When** I choose the file
**Then** the upload is queued locally with a visual indicator ("Queued — will upload when online")
**And** when connectivity restores, the queued upload automatically begins and the UI updates

### Story 6.3: Loading States and Processing Feedback

As a mobile user,
I want to see clear, informative loading states during all operations,
So that I always know the app is working and never feel stuck.

**Acceptance Criteria:**

**Given** the document library is loading
**When** the API call is in progress
**Then** skeleton shimmer cards (3 placeholder rectangles) are displayed

**Given** I am waiting for an AI answer
**When** the question has been submitted
**Then** the AI Typing Indicator (3 pulsing dots with #79C0FF glow) is shown in the chat

**Given** a document is being processed
**When** I view the library
**Then** the Processing Animation Widget shows multi-stage progress with descriptive icons and text

**And** all loading animations respect the system "Reduce Motion" preference (static alternatives provided)
**And** loading shimmer widgets use the `loading_shimmer.dart` shared component for consistency

### Story 6.4: Comprehensive Error Handling and System Feedback

As a mobile user,
I want to see clear, actionable error messages for all failure scenarios,
So that I understand what went wrong and how to fix it.

**Acceptance Criteria:**

**Given** a document processing fails (unsupported format, corrupted file, excessive size)
**When** the error is detected
**Then** a red SnackBar with error icon appears (persistent until dismissed) with a specific message (e.g., "This file isn't a valid PDF. Please upload a PDF file.") and a "Retry" action where applicable

**Given** the AI cannot answer a question from the document content
**When** the system determines no relevant chunks exist
**Then** the AI Response Bubble shows: "I couldn't find relevant information for this question in the document. Try rephrasing your question or asking about a different topic."

**Given** the Groq API rate limit is reached
**When** a 429 response is received
**Then** an amber warning SnackBar shows: "You've reached the query limit. Please wait [X] seconds." with a countdown or estimated wait time
**And** the chat input is temporarily disabled until the rate limit resets

**Given** a network error occurs during any API call
**When** the request fails
**Then** an appropriate error message is shown with a "Retry" action

**And** all error responses from the backend use the consistent format: `{"detail": {"code": "ERROR_CODE", "message": "Human-readable message"}}`

### Story 6.5: Accessibility Compliance and Screen Reader Support

As a user with accessibility needs,
I want the app to fully support screen readers, text scaling, and keyboard navigation,
So that I can use DocuMind AI regardless of my abilities.

**Acceptance Criteria:**

**Given** I am using VoiceOver (iOS) or TalkBack (Android)
**When** I navigate through the app
**Then** all interactive elements have semantic labels (e.g., Send button: "Send question", Citation Chip: "Page reference, page 12. Tap to view source.")
**And** AI streaming responses are announced as live regions (accumulated and announced every sentence)
**And** document status changes are announced (e.g., "Document Contract Review is now ready")

**Given** I have increased my system font size to 200%
**When** I use the app
**Then** all text scales appropriately, layouts adapt without clipping or overlap, and the app remains fully functional

**Given** I have enabled "Reduce Motion" in system settings
**When** I use the app
**Then** all spring-based animations, pulsing indicators, and parallax effects are replaced with static or minimal-motion alternatives

**Given** I am navigating via keyboard or switch control
**When** I tab through interactive elements
**Then** visible focus indicators (accent-colored rings) are shown on the focused element
**And** all interactive elements are reachable and operable

**And** all text/background color combinations meet WCAG 2.1 AA contrast ratio (4.5:1 for normal text, 3:1 for large text)
**And** all touch targets are at minimum 44×44pt
**And** icon-only buttons have tooltips on long-press
