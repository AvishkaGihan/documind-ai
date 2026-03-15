# DocuMind AI Backend

FastAPI backend service for DocuMind AI.

## Development

Install dependencies:

```bash
pip install -r requirements.txt
```

Run development server:

```bash
uvicorn app.main:app --reload --port 8000
```

## Database Migrations (Alembic)

Generate initial migration from SQLAlchemy models:

```bash
python -m alembic revision --autogenerate -m "initial schema"
```

Expected output includes detected new tables and a generated file under `alembic/versions/`, for example:

```text
Detected added table 'users'
Detected added table 'documents'
Detected added table 'conversations'
Detected added table 'messages'
Generating .../alembic/versions/<revision>_initial_schema.py ... done
```

Apply migrations to local SQLite database:

```bash
python -m alembic upgrade head
```

Expected output includes:

```text
Running upgrade  -> <revision>, initial schema
```
