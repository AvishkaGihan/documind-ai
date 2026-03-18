import asyncio
from uuid import UUID

from sqlalchemy import select

from app.models.document import Document, DocumentStatus
from app.services.storage_service import StorageService


def _pdf_bytes(payload: bytes = b"1 0 obj\n<< /Type /Catalog >>\nendobj\n%%EOF\n") -> bytes:
    return b"%PDF-1.7\n" + payload


def _auth_headers(client, email: str) -> dict[str, str]:
    signup_payload = {"email": email, "password": "strongpass123"}
    signup_response = client.post("/api/v1/auth/signup", json=signup_payload)
    assert signup_response.status_code == 201

    access_token = signup_response.json()["tokens"]["access_token"]
    return {"Authorization": f"Bearer {access_token}"}


def test_upload_requires_authentication(client) -> None:
    response = client.post(
        "/api/v1/documents/upload",
        files={"file": ("example.pdf", _pdf_bytes(), "application/pdf")},
    )

    assert response.status_code == 401
    assert response.json() == {
        "detail": {
            "code": "INVALID_TOKEN",
            "message": "Invalid or missing access token.",
            "field": None,
        }
    }


def test_upload_valid_pdf_returns_created_and_persists_document(
    client,
    test_session_factory,
    monkeypatch,
) -> None:
    async def _fake_upload_pdf(self, *, user_id, document_id, fileobj, content_type):
        assert str(user_id)
        assert str(document_id)
        assert content_type == "application/pdf"
        return f"users/{user_id}/documents/{document_id}.pdf"

    monkeypatch.setattr(StorageService, "upload_pdf", _fake_upload_pdf)

    headers = _auth_headers(client, "upload-success@example.com")
    filename = "my-reference-guide.pdf"
    response = client.post(
        "/api/v1/documents/upload",
        headers=headers,
        files={"file": (filename, _pdf_bytes(), "application/pdf")},
    )

    assert response.status_code == 201
    body = response.json()
    assert set(body.keys()) == {"id", "title", "status", "created_at"}
    assert body["title"] == "my-reference-guide"
    assert body["status"] == "processing"
    assert body["id"]
    assert body["created_at"]

    async def _assert_document_saved() -> None:
        async with test_session_factory() as session:
            result = await session.execute(select(Document).where(Document.id == UUID(body["id"])))
            document = result.scalar_one()
            assert document.title == "my-reference-guide"
            assert document.status == DocumentStatus.PROCESSING
            assert document.page_count == 0
            assert document.file_size > 0
            assert document.file_path.endswith(".pdf")

    asyncio.run(_assert_document_saved())


def test_upload_rejects_non_pdf_magic_bytes(client, monkeypatch) -> None:
    async def _fake_upload_pdf(self, *, user_id, document_id, fileobj, content_type):
        return f"users/{user_id}/documents/{document_id}.pdf"

    monkeypatch.setattr(StorageService, "upload_pdf", _fake_upload_pdf)

    headers = _auth_headers(client, "upload-invalid-type@example.com")
    response = client.post(
        "/api/v1/documents/upload",
        headers=headers,
        files={"file": ("not-really.pdf", b"not a pdf", "application/pdf")},
    )

    assert response.status_code == 422
    assert response.json() == {
        "detail": {
            "code": "INVALID_FILE_TYPE",
            "message": "Only PDF files are supported",
            "field": None,
        }
    }


def test_upload_rejects_oversized_file(client, monkeypatch) -> None:
    from app.services.document_service import DocumentService

    async def _fake_upload_pdf(self, *, user_id, document_id, fileobj, content_type):
        return f"users/{user_id}/documents/{document_id}.pdf"

    monkeypatch.setattr(StorageService, "upload_pdf", _fake_upload_pdf)
    monkeypatch.setattr(DocumentService, "MAX_UPLOAD_SIZE_BYTES", 16)

    headers = _auth_headers(client, "upload-too-large@example.com")
    oversized_pdf = _pdf_bytes(payload=b"x" * 64)
    response = client.post(
        "/api/v1/documents/upload",
        headers=headers,
        files={"file": ("too-large.pdf", oversized_pdf, "application/pdf")},
    )

    assert response.status_code == 413
    body = response.json()
    assert body["detail"]["code"] == "FILE_TOO_LARGE"
