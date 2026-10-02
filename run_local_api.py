from __future__ import annotations

import importlib.util
import os
import subprocess
import sys
from pathlib import Path


def _has_module(module_name: str) -> bool:
    return importlib.util.find_spec(module_name) is not None


def _candidate_interpreters() -> list[Path]:
    workspace = Path(__file__).resolve().parent
    return [
        workspace / "venv" / "Scripts" / "python.exe",
        workspace / ".venv" / "Scripts" / "python.exe",
        workspace / ".venv312" / "Scripts" / "python.exe",
    ]


def _restart_in_working_venv() -> None:
    current_python = Path(sys.executable).resolve()
    for candidate in _candidate_interpreters():
        if not candidate.exists() or candidate.resolve() == current_python:
            continue
        probe = subprocess.run(
            [str(candidate), "-c", "import fastapi, uvicorn"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=False,
        )
        if probe.returncode == 0:
            os.execv(str(candidate), [str(candidate), str(Path(__file__).resolve())])


if not (_has_module("fastapi") and _has_module("uvicorn")):
    _restart_in_working_venv()

if not (_has_module("fastapi") and _has_module("uvicorn")):
    raise SystemExit(
        "Could not find a Python environment with FastAPI and Uvicorn installed. "
        "Tried the current interpreter plus local venvs: venv, .venv, .venv312."
    )

import uvicorn


if __name__ == "__main__":
    uvicorn.run("jansampark_ai.local_api:app", host="127.0.0.1", port=8000, reload=False)
