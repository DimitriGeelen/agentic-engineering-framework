"""Paused-dispatch helpers for the operator review queue.

Origin: T-1808 (dispatch-safety slice 4). Reads `.context/dispatches.jsonl`
for rows where `outcome == "paused"` and exposes them in a shape the CLI
(`fw review-queue`) and the Watchtower `/approvals` page can render directly.

A paused dispatch is one where the Worker emitted a `pause_requested` terminal
event (T-1805) and the substrate classified the outcome as `paused`. The Worker
exited cleanly; the dispatch is now waiting for the operator to answer the
question captured in `terminal_event.question`.

Slice-5 forward-compat: a paused dispatch with a subsequent dispatch carrying
`retry_of_dispatch_id == this.dispatch_id` is considered resolved (the operator
answered and the Resolver re-dispatched). Until slice 5 lands, the retry field
is never set, so every paused dispatch surfaces as awaiting-resolution.
"""

from __future__ import annotations

import json
import os
import re
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple


_PROJECT_ROOT_DEFAULT = Path(os.environ.get("PROJECT_ROOT", ".")).resolve()


def _dispatches_log_path(project_root: Optional[Path] = None) -> Path:
    root = project_root or _PROJECT_ROOT_DEFAULT
    return root / ".context" / "dispatches.jsonl"


def _parse_ts(ts: str) -> Optional[datetime]:
    if not ts:
        return None
    try:
        return datetime.fromisoformat(ts.replace("Z", "+00:00"))
    except (ValueError, TypeError):
        return None


def _row_age_seconds(row: Dict[str, Any], now: Optional[datetime] = None) -> int:
    now = now or datetime.now(timezone.utc)
    dt = _parse_ts(row.get("ts", ""))
    if not dt:
        return 0
    return max(0, int((now - dt).total_seconds()))


def _extract_question_fields(terminal_event: Optional[Dict[str, Any]]) -> Tuple[str, str, str, str]:
    """Return (question, severity, likelihood, state_ref) from a pause terminal event.

    Missing fields are returned as empty strings — callers render them as
    placeholder rather than raise.
    """
    if not isinstance(terminal_event, dict):
        return ("", "", "", "")
    question = str(terminal_event.get("question") or "").strip()
    assessment = terminal_event.get("assessment") or {}
    if isinstance(assessment, dict):
        severity = str(assessment.get("severity") or "").strip()
        likelihood = str(assessment.get("likelihood") or "").strip()
    else:
        severity = likelihood = ""
    state_ref = str(terminal_event.get("state_ref") or "").strip()
    return (question, severity, likelihood, state_ref)


def list_paused_dispatches(project_root: Optional[Path] = None) -> List[Dict[str, Any]]:
    """Scan dispatches.jsonl and return every awaiting-resolution paused row.

    A paused dispatch is "awaiting" iff no later row has `retry_of_dispatch_id`
    pointing to its dispatch_id. (Until slice 5 lands, no row sets that field,
    so the second condition is trivially true.)

    Returns rows newest-first by timestamp. Each row is a dict with:
        dispatch_id, task_id, ts, age_seconds, question,
        severity, likelihood, state_ref, worker_kind, model
    """
    path = _dispatches_log_path(project_root)
    if not path.exists():
        return []

    paused: List[Dict[str, Any]] = []
    retried_ids: set[str] = set()

    with path.open() as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                row = json.loads(line)
            except json.JSONDecodeError:
                continue
            if not isinstance(row, dict):
                continue
            retry_of = row.get("retry_of_dispatch_id")
            if retry_of:
                retried_ids.add(retry_of)
            if row.get("outcome") == "paused":
                paused.append(row)

    now = datetime.now(timezone.utc)
    out: List[Dict[str, Any]] = []
    for row in paused:
        did = row.get("dispatch_id") or ""
        if did and did in retried_ids:
            # slice-5 forward compat — operator answered; row no longer awaiting.
            continue
        question, severity, likelihood, state_ref = _extract_question_fields(
            row.get("terminal_event")
        )
        out.append({
            "dispatch_id": did,
            "task_id": row.get("task_id") or "",
            "ts": row.get("ts") or "",
            "age_seconds": _row_age_seconds(row, now),
            "question": question,
            "severity": severity,
            "likelihood": likelihood,
            "state_ref": state_ref,
            "worker_kind": row.get("worker_kind") or "",
            "model": row.get("model") or "",
        })

    out.sort(key=lambda r: r["ts"], reverse=True)
    return out


def list_paused_dispatches_for_task(
    task_id: str, project_root: Optional[Path] = None
) -> List[Dict[str, Any]]:
    """Same as list_paused_dispatches but filtered to a single task_id."""
    if not task_id:
        return []
    return [r for r in list_paused_dispatches(project_root) if r.get("task_id") == task_id]


def format_age(seconds: int) -> str:
    """Compact human-readable age — `<10m`, `42m`, `3h`, `2d`."""
    if seconds < 600:
        return "<10m"
    if seconds < 3600:
        return f"{seconds // 60}m"
    if seconds < 86400:
        return f"{seconds // 3600}h"
    return f"{seconds // 86400}d"


def truncate(text: str, width: int) -> str:
    """Truncate `text` to `width` characters with an ellipsis suffix."""
    if not text:
        return ""
    if len(text) <= width:
        return text
    return text[: max(0, width - 3)] + "..."
