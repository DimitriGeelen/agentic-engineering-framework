"""What the index actually contains, recorded at build time.

T-3011, slice 2 of T-3005.

`built_at` in the existing code is the moment the sqlite handle was *opened*, which
is why a five-month-old index reported itself fresh (T-3004 root cause). A manifest
records what was indexed, from which commit, with which model, at which chunk cap —
so "the index is stale" and "the index was built by a different model than the one
answering queries" become checkable claims instead of inferences.

Slice 4's doctor/audit rail is the consumer. This module only writes and reads.

Read never raises. A missing or corrupt manifest returns None, because the caller is
a health check and a health check that crashes reports nothing at all.
"""

from __future__ import annotations

import json
import subprocess
import time
from pathlib import Path

MANIFEST_VERSION = 1


def manifest_path_for(db_path: Path) -> Path:
    """Sits beside the database, so the two travel together."""
    return Path(str(db_path) + ".manifest.json")


def _git_head(project_root: Path) -> str:
    try:
        out = subprocess.run(
            ["git", "-C", str(project_root), "rev-parse", "HEAD"],
            capture_output=True, text=True, timeout=10,
        )
        return out.stdout.strip() if out.returncode == 0 else ""
    except Exception:  # noqa: BLE001 — provenance is best-effort, never fatal
        return ""


def build_manifest(*, num_docs: int, num_chunks: int, model: str,
                   embedding_dim: int, max_chunk_chars: int,
                   embed_context_tokens: int, canary_token: str,
                   started_at: float, project_root: Path) -> dict:
    return {
        "manifest_version": MANIFEST_VERSION,
        "num_docs": num_docs,
        "num_chunks": num_chunks,
        "model": model,
        "embedding_dim": embedding_dim,
        # The chunk cap and the ceiling it derives from (T-3010). Recorded so a
        # future reader can tell whether an index was built under the old
        # uncapped chunker without re-deriving it from the data.
        "max_chunk_chars": max_chunk_chars,
        "embed_context_tokens": embed_context_tokens,
        "canary_token": canary_token,
        "started_at": started_at,
        "finished_at": time.time(),
        "git_head": _git_head(project_root),
    }


def write_manifest(db_path: Path, manifest: dict) -> Path:
    p = manifest_path_for(db_path)
    p.parent.mkdir(parents=True, exist_ok=True)
    tmp = p.with_suffix(p.suffix + ".tmp")
    tmp.write_text(json.dumps(manifest, indent=2, sort_keys=True))
    tmp.replace(p)          # atomic: a reader never sees a half-written manifest
    return p


def read_manifest(db_path: Path) -> dict | None:
    """Return the manifest, or None if absent/unreadable/not a dict.

    Absence is a legitimate answer — every index built before this slice has no
    manifest — and it must be distinguishable from a crash by the caller.
    """
    p = manifest_path_for(db_path)
    try:
        if not p.exists():
            return None
        data = json.loads(p.read_text())
    except Exception:  # noqa: BLE001 — corrupt manifest reads as absent
        return None
    return data if isinstance(data, dict) else None


def age_seconds(manifest: dict | None, now: float | None = None) -> float | None:
    if not manifest or not isinstance(manifest.get("finished_at"), (int, float)):
        return None
    return (time.time() if now is None else now) - manifest["finished_at"]
