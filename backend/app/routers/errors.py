from typing import Any


def build_error_detail(code: str, message: str, field: str | None = None) -> dict[str, Any]:
    return {
        "code": code,
        "message": message,
        "field": field,
    }
