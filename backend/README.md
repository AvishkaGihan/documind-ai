# 🐍 DocuMind AI - Backend Service

High-performance **FastAPI** backend for DocuMind AI, managing document processing, vector search orchestration, and secure AI stream inference.

---

## ✨ Features

- ⚡ **Async-First**: Fully asynchronous service handlers containing business logic.
- 🔒 **Data Isolation Layer**: Physical separation of vector store graphs via ChromaDB collections.
- 🏷️ **Strict Type Safety**: Standardized Pydantic v2 schemas for all requests and responses.
- 🛡️ **Guarded Single Interfaces**: Rigid access control for external services (S3, Groq, Chroma).

---

## 🛠️ Tech Stack

- **Framework**: FastAPI (Python 3.12+)
- **ORM**: SQLAlchemy 2.0 (with `asyncpg`)
- **Pipeline**: LangChain, Sentence Transformers (Local)
- **Inference**: Groq API (LLaMA 3.3 70B)
- **Database**: SQLite (Local Dev) / PostgreSQL (Production)
- **Vector DB**: ChromaDB

---

## 🚀 Getting Started

### Prerequisites

- Python 3.12+ installed.
- `.venv` or equivalent environment manager.

### Setup & Run

1.  **Navigate to directory**:
    ```bash
    cd backend
    ```

2.  **Create and Activate Virtual Environment**:
    ```bash
    python -m venv .venv
    source .venv/bin/activate  # On Windows: .venv\Scripts\activate
    ```

3.  **Install Dependencies**:
    ```bash
    pip install -r requirements.txt
    ```

4.  **Environment Configuration**:
    Copy the example environment into place and configure secret keys:
    ```bash
    cp .env.example .env
    ```
    *Make sure to add your `GROQ_API_KEY` to the `.env`.*

5.  **Run Applied Migrations** (Alembic):
    ```bash
    python -m alembic upgrade head
    ```

6.  **Start Development Server**:
    ```bash
    uvicorn app.main:app --reload --port 8000
    ```

---

## 📂 Project Structure

```text
app/
├── routers/           # HTTP Routing handlers
├── services/          # Core Business logic (LLM, Storage, processing)
├── repositories/      # Database CRUD layer (SQLAlchemy 2.0 style)
├── models/            # SQLAlchemy Database Models
└── schemas/           # Pydantic validation schemas
```

## 🧪 Testing

Run standard tests using `pytest`:
```bash
pytest
```
Code will also be verified with `ruff` via CI/CD on pushing commits.
