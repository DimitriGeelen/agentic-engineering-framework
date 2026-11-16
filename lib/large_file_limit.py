"""T-5173: the large-file commit limit, read the way the T-1845 git guard reads it.

The guard (`agents/git/lib/large-file-scan.sh`, `_lf_threshold_block`) refuses a commit that
stages a file over `FW_LARGE_FILE_BLOCK_BYTES` (default 10,485,760 bytes). Anything that writes
files a commit will later carry (review screenshots, judge evidence) asks here first, so an
oversized file is reported where it is made instead of failing a commit later.
"""
from __future__ import annotations

import os
from pathlib import Path

DEFAULT_BLOCK_BYTES = 10_485_760


def block_bytes() -> int:
    """The commit limit in bytes: FW_LARGE_FILE_BLOCK_BYTES when it is a positive integer."""
    raw = os.environ.get("FW_LARGE_FILE_BLOCK_BYTES", "").strip()
    try:
        v = int(raw)
        return v if v > 0 else DEFAULT_BLOCK_BYTES
    except ValueError:
        return DEFAULT_BLOCK_BYTES


def human(n: int) -> str:
    return f"{n / 1_048_576:.1f} MB"


def oversized(paths, limit: int | None = None) -> list[tuple[str, int]]:
    """[(path, size)] for each existing file over the limit."""
    limit = block_bytes() if limit is None else limit
    out = []
    for p in paths:
        try:
            size = Path(p).stat().st_size
        except OSError:
            continue
        if size > limit:
            out.append((str(p), size))
    return out
