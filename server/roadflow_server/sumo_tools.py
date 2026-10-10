"""Locating the SUMO binaries (eclipse-sumo wheel, $SUMO_HOME or $PATH)."""

from __future__ import annotations

import functools
import os
import shutil
import subprocess
from pathlib import Path


class SumoNotFound(RuntimeError):
    pass


@functools.cache
def binary(name: str) -> str:
    exe = name + ".exe" if os.name == "nt" else name
    candidates: list[Path] = []
    home = os.environ.get("SUMO_HOME")
    if home:
        candidates.append(Path(home) / "bin" / exe)
    try:
        import sumo  # eclipse-sumo wheel

        candidates.append(Path(sumo.SUMO_HOME) / "bin" / exe)
    except ImportError:
        pass
    for c in candidates:
        if c.is_file() and os.access(c, os.X_OK):
            return str(c)
    found = shutil.which(name)
    if found:
        return found
    raise SumoNotFound(f"SUMO binary '{name}' not found; install eclipse-sumo or set SUMO_HOME")


@functools.cache
def version() -> str:
    out = subprocess.run([binary("sumo"), "--version"], capture_output=True, text=True, timeout=30).stdout
    first = out.splitlines()[0] if out else "unknown"
    return first.replace("Eclipse SUMO sumo", "").strip() or first
