import asyncio
from uuid import uuid4

import anyio

from app.services.processing.chunker import Chunk
from app.services.processing.embedder import DEFAULT_EMBEDDING_MODEL, Embedder


class FakeModel:
    def __init__(self) -> None:
        self.calls: list[list[str]] = []

    def encode(self, texts: list[str], *, convert_to_numpy: bool) -> list[list[float]]:
        assert convert_to_numpy is True
        self.calls.append(texts)
        return [[float(index), float(index) + 0.5] for index, _ in enumerate(texts)]


def test_embedder_uses_thread_offload_and_injected_model(monkeypatch) -> None:
    chunks = [
        Chunk(text="chunk one", page_number=1, chunk_index=0, document_id=uuid4()),
        Chunk(text="chunk two", page_number=1, chunk_index=1, document_id=uuid4()),
    ]

    fake_model = FakeModel()
    embedder = Embedder(model=fake_model)

    run_sync_calls = {"count": 0}
    original_run_sync = anyio.to_thread.run_sync

    async def _tracking_run_sync(func, *args, **kwargs):
        run_sync_calls["count"] += 1
        return await original_run_sync(func, *args, **kwargs)

    monkeypatch.setattr(anyio.to_thread, "run_sync", _tracking_run_sync)

    async def _run() -> None:
        vectors = await embedder.embed_chunks(chunks=chunks)
        assert vectors == [[0.0, 0.5], [1.0, 1.5]]
        assert run_sync_calls["count"] == 1
        assert fake_model.calls == [["chunk one", "chunk two"]]

    asyncio.run(_run())


def test_embedder_default_model_constant_is_defined() -> None:
    assert isinstance(DEFAULT_EMBEDDING_MODEL, str)
    assert DEFAULT_EMBEDDING_MODEL
