"""T-3313 (arc-020 S7): durable JSONL audit trail for auto-provision events.

Spec: docs/reports/T-3287-identity-taxonomy-circuit-model.md, D5 bound 4 —
"Full traceability: every auto-provision logged, unconditionally."

This module is the durable implementation of the audit-sink seam that
lib/aef_resolve.py:provision() exposes (S3 left the default sink collecting
rows on the in-memory result only). Plug it in as:

    from lib.aef_provision_log import jsonl_sink
    provision(target, probe, provisioners, audit_sink=jsonl_sink())

Each provision DECISION — allow, deny (S5 admission), halted (S6
missing-path), refused (hub-standup ceiling) — lands as one JSON object per
line, append-only, in ``.context/provisions.jsonl`` under the project root.
The outcome value is recorded VERBATIM as the resolver emitted it; the
vocabulary today is allow / deny / halted / refused, with provisioned /
failed reserved for sinks fed by richer callers.

Row schema (every row carries all six keys):
    ts       ISO8601 UTC timestamp (from the resolver row, else now)
    address  serialized AEF address the decision was about
    level    the ladder rung (host/hub/project/session/agent)
    outcome  the decision, verbatim
    actor    who was provisioning (default "aef-resolve", or FW_PROVISION_ACTOR)
    detail   the resolver's reason text, "" when none

Readable surface: ``fw provisions [--tail N]`` (bin/fw) routes to this
module's CLI, which is read-only and tolerates malformed lines (a corrupt
line is skipped, never fatal — the trail must stay readable after a torn
write). Pure stdlib.
"""

from __future__ import annotations

import json
import os
import sys
import time
from pathlib import Path
from typing import Callable, Iterable

DEFAULT_RELPATH = Path(".context") / "provisions.jsonl"
DEFAULT_ACTOR = "aef-resolve"

_ROW_FIELDS = ("ts", "address", "level", "outcome", "actor", "detail")


def _now() -> str:
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())


def default_log_path(project_root: str | Path | None = None) -> Path:
    """Resolve the trail's on-disk home: <project root>/.context/provisions.jsonl.

    Root resolution order: explicit arg > $PROJECT_ROOT > cwd. The env var is
    what bin/fw exports, so the CLI and the sink agree without plumbing.
    """
    root = project_root or os.environ.get("PROJECT_ROOT") or os.getcwd()
    return Path(root) / DEFAULT_RELPATH


def normalize_row(row: dict, *, actor: str | None = None) -> dict:
    """Map a resolver emit-row ({ts, level, address, decision, reason?}) onto
    the durable six-field schema. Already-normalized rows pass through."""
    return {
        "ts": row.get("ts") or _now(),
        "address": row.get("address", ""),
        "level": row.get("level") or row.get("rung", ""),
        "outcome": row.get("decision") or row.get("outcome", ""),
        "actor": actor or os.environ.get("FW_PROVISION_ACTOR") or DEFAULT_ACTOR,
        "detail": row.get("reason") or row.get("detail") or "",
    }


def append_row(
    row: dict,
    *,
    path: str | Path | None = None,
    actor: str | None = None,
) -> dict:
    """Append one provision decision to the JSONL trail (append-only).

    Creates the parent directory if absent. Returns the normalized row as
    written. Never rewrites or truncates — the trail only grows.
    """
    target = Path(path) if path is not None else default_log_path()
    normalized = normalize_row(row, actor=actor)
    target.parent.mkdir(parents=True, exist_ok=True)
    with open(target, "a", encoding="utf-8") as fh:
        fh.write(json.dumps(normalized, sort_keys=True) + "\n")
    return normalized


def jsonl_sink(
    path: str | Path | None = None,
    *,
    actor: str | None = None,
) -> Callable[[dict], None]:
    """Build an audit_sink callable for lib.aef_resolve.provision().

    Every row the resolver emits — including deny (S5) and halted (S6) —
    is appended durably; D5 bound 4 is unconditional, so the sink never
    filters by outcome.
    """

    def sink(row: dict) -> None:
        append_row(row, path=path, actor=actor)

    return sink


def read_rows(
    path: str | Path | None = None,
    *,
    tail: int | None = None,
) -> list[dict]:
    """Read the trail, skipping malformed lines (torn writes must not make
    the whole trail unreadable). Missing file reads as empty. ``tail`` keeps
    only the last N rows."""
    target = Path(path) if path is not None else default_log_path()
    if not target.is_file():
        return []
    rows: list[dict] = []
    with open(target, encoding="utf-8") as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            try:
                parsed = json.loads(line)
            except ValueError:
                continue  # malformed line — skip, keep reading
            if isinstance(parsed, dict):
                rows.append(parsed)
    if tail is not None and tail >= 0:
        rows = rows[-tail:] if tail else []
    return rows


def format_rows(rows: Iterable[dict]) -> str:
    """Human-readable one-line-per-decision rendering for `fw provisions`."""
    lines = []
    for row in rows:
        detail = row.get("detail") or ""
        suffix = f"  — {detail}" if detail else ""
        lines.append(
            f"{row.get('ts', '?'):<20} {row.get('outcome', '?'):<12} "
            f"{row.get('level', '?'):<8} {row.get('actor', '?'):<14} "
            f"{row.get('address', '?')}{suffix}"
        )
    return "\n".join(lines)


def main(argv: list[str] | None = None) -> int:
    """CLI behind `fw provisions [--tail N] [--path FILE]`. Read-only."""
    args = list(sys.argv[1:] if argv is None else argv)
    tail: int | None = 20
    path: str | None = None
    while args:
        arg = args.pop(0)
        if arg == "--tail" and args:
            try:
                tail = int(args.pop(0))
            except ValueError:
                print("fw provisions: --tail wants an integer", file=sys.stderr)
                return 2
        elif arg == "--all":
            tail = None
        elif arg == "--path" and args:
            path = args.pop(0)
        else:
            print("Usage: fw provisions [--tail N] [--all] [--path FILE]", file=sys.stderr)
            return 2
    log_path = Path(path) if path is not None else default_log_path()
    rows = read_rows(log_path, tail=tail)
    if not rows:
        print(f"No provision audit rows yet ({log_path})")
        return 0
    print(f"Provision audit trail — {log_path} (showing {len(rows)} row(s))")
    print(format_rows(rows))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
