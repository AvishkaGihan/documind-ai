from __future__ import annotations

import json
from typing import Any


def format_sse_event(event_name: str, payload: dict[str, Any]) -> str:
    data_json = json.dumps(payload, separators=(",", ":"), ensure_ascii=True)
    return f"event: {event_name}\ndata: {data_json}\n\n"