from __future__ import annotations

import json
from pathlib import Path
from typing import Any, Dict


def ensure_dir(path: Path) -> Path:
    path.mkdir(parents=True, exist_ok=True)
    return path


def save_json(path: Path, payload: Dict[str, Any]) -> None:
    ensure_dir(path.parent)
    path.write_text(json.dumps(payload, indent=2), encoding="utf-8")


def benchmark_stub(model_name: str, variant: str) -> Dict[str, Any]:
    return {
        "modelName": model_name,
        "variant": variant,
        "latencyMs": None,
        "notes": "Populate with on-device benchmark measurements during device validation.",
    }
