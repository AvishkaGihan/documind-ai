from __future__ import annotations

import io
from dataclasses import dataclass

import anyio
from pypdf import PdfReader

MIN_EXTRACTED_CHAR_COUNT = 200


class ExtractionError(Exception):
    """Raised when PDF text extraction fails or yields insufficient text."""


@dataclass(frozen=True, slots=True)
class PageText:
    page_number: int
    text: str


class Extractor:
    async def extract_text_by_page(self, *, pdf_bytes: bytes) -> list[PageText]:
        try:
            pages = await anyio.to_thread.run_sync(self._extract_sync, pdf_bytes)
        except Exception as exc:  # pragma: no cover - defensive conversion boundary
            raise ExtractionError("Failed to extract text from PDF") from exc

        total_text_len = sum(len(page.text.strip()) for page in pages)
        if total_text_len < MIN_EXTRACTED_CHAR_COUNT:
            raise ExtractionError(
                "No extractable text found. This PDF may be scanned or image-only."
            )

        return pages

    def _extract_sync(self, pdf_bytes: bytes) -> list[PageText]:
        reader = PdfReader(io.BytesIO(pdf_bytes))
        page_texts: list[PageText] = []

        for page_index, page in enumerate(reader.pages, start=1):
            extracted = page.extract_text() or ""
            page_texts.append(PageText(page_number=page_index, text=extracted))

        return page_texts
