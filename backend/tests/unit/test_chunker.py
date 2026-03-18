import uuid

from app.services.processing.chunker import Chunker
from app.services.processing.extractor import PageText


def test_chunker_applies_default_size_and_overlap_and_preserves_metadata() -> None:
    document_id = uuid.uuid4()
    tokens = [f"tok{i}" for i in range(1200)]
    pages = [PageText(page_number=3, text=" ".join(tokens))]

    chunks = Chunker().chunk_pages(document_id=document_id, pages=pages)

    assert len(chunks) == 3
    assert [len(chunk.text.split()) for chunk in chunks] == [500, 500, 300]

    # Consecutive chunks must overlap by exactly 50 tokens.
    first_tokens = chunks[0].text.split()
    second_tokens = chunks[1].text.split()
    third_tokens = chunks[2].text.split()

    assert first_tokens[-50:] == second_tokens[:50]
    assert second_tokens[-50:] == third_tokens[:50]

    for index, chunk in enumerate(chunks):
        assert chunk.page_number == 3
        assert chunk.chunk_index == index
        assert chunk.document_id == document_id
