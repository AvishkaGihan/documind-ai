import asyncio
from datetime import UTC, datetime, timedelta
from uuid import UUID, uuid4

from app.models.document import Document, DocumentStatus


def _auth_headers(client, email: str) -> tuple[dict[str, str], UUID]:
    signup_payload = {"email": email, "password": "strongpass123"}
    signup_response = client.post("/api/v1/auth/signup", json=signup_payload)
    assert signup_response.status_code == 201

    access_token = signup_response.json()["tokens"]["access_token"]
    user_id = UUID(signup_response.json()["user"]["id"])
    return {"Authorization": f"Bearer {access_token}"}, user_id


def _create_document(
    *,
    test_session_factory,
    user_id: UUID,
    title: str,
    created_at: datetime,
) -> UUID:
    document_id = uuid4()

    async def _create() -> None:
        async with test_session_factory() as session:
            session.add(
                Document(
                    id=document_id,
                    user_id=user_id,
                    title=title,
                    file_path=f"users/{user_id}/documents/{document_id}.pdf",
                    file_size=2048,
                    page_count=6,
                    status=DocumentStatus.READY,
                    error_message=None,
                    created_at=created_at,
                    updated_at=created_at,
                )
            )
            await session.commit()

    asyncio.run(_create())
    return document_id


def test_list_documents_returns_paginated_response_for_owner_only(
    client,
    test_session_factory,
) -> None:
    owner_headers, owner_id = _auth_headers(client, "library-owner@example.com")
    _, other_user_id = _auth_headers(client, "library-other@example.com")

    base_time = datetime.now(UTC)
    _create_document(
        test_session_factory=test_session_factory,
        user_id=owner_id,
        title="Owner Contract",
        created_at=base_time,
    )
    _create_document(
        test_session_factory=test_session_factory,
        user_id=owner_id,
        title="Owner Report",
        created_at=base_time + timedelta(seconds=10),
    )
    _create_document(
        test_session_factory=test_session_factory,
        user_id=other_user_id,
        title="Other Secret",
        created_at=base_time + timedelta(seconds=20),
    )

    response = client.get("/api/v1/documents", headers=owner_headers)

    assert response.status_code == 200
    body = response.json()
    assert set(body.keys()) == {"items", "total", "page", "page_size"}
    assert body["total"] == 2
    assert body["page"] == 1
    assert body["page_size"] == 20

    items = body["items"]
    assert len(items) == 2
    assert items[0]["title"] == "Owner Report"
    assert items[1]["title"] == "Owner Contract"
    for item in items:
        assert set(item.keys()) == {
            "id",
            "title",
            "file_size",
            "page_count",
            "status",
            "error_message",
            "created_at",
        }


def test_list_documents_search_is_case_insensitive(client, test_session_factory) -> None:
    headers, user_id = _auth_headers(client, "search-owner@example.com")

    base_time = datetime.now(UTC)
    _create_document(
        test_session_factory=test_session_factory,
        user_id=user_id,
        title="Master Contract v2",
        created_at=base_time,
    )
    _create_document(
        test_session_factory=test_session_factory,
        user_id=user_id,
        title="Quarterly Report",
        created_at=base_time + timedelta(seconds=5),
    )

    response = client.get(
        "/api/v1/documents",
        headers=headers,
        params={"search": "CONTRACT"},
    )

    assert response.status_code == 200
    body = response.json()
    assert body["total"] == 1
    assert len(body["items"]) == 1
    assert body["items"][0]["title"] == "Master Contract v2"


def test_list_documents_supports_page_and_page_size(client, test_session_factory) -> None:
    headers, user_id = _auth_headers(client, "pagination-owner@example.com")
    base_time = datetime.now(UTC)

    for index in range(3):
        _create_document(
            test_session_factory=test_session_factory,
            user_id=user_id,
            title=f"Doc {index}",
            created_at=base_time + timedelta(seconds=index),
        )

    response = client.get(
        "/api/v1/documents",
        headers=headers,
        params={"page": 2, "page_size": 1},
    )

    assert response.status_code == 200
    body = response.json()
    assert body["total"] == 3
    assert body["page"] == 2
    assert body["page_size"] == 1
    assert len(body["items"]) == 1
    assert body["items"][0]["title"] == "Doc 1"
