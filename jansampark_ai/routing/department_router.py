from __future__ import annotations

import json
import time
from pathlib import Path
from typing import Any, Dict

from jansampark_ai.utils.constants import DEFAULT_ROUTING_CONFIG_PATH
from jansampark_ai.utils.firestore import get_routing_config

_CACHE: Dict[str, Any] = {"expires_at": 0.0, "payload": None}
_TTL_SECONDS = 300


def _load_default_mapping() -> Dict[str, Any]:
    return json.loads(Path(DEFAULT_ROUTING_CONFIG_PATH).read_text(encoding="utf-8"))


def _read_mapping(firestore_client: Any) -> Dict[str, Any]:
    now = time.time()
    if _CACHE["payload"] is not None and now < _CACHE["expires_at"]:
        return _CACHE["payload"]
    payload = get_routing_config(firestore_client) or _load_default_mapping()
    _CACHE["payload"] = payload
    _CACHE["expires_at"] = now + _TTL_SECONDS
    return payload


def route_issue(label: str, firestore_client: Any) -> str:
    mapping = _read_mapping(firestore_client)
    return mapping.get("labelMap", {}).get(label, mapping["reviewQueueDepartmentId"])
