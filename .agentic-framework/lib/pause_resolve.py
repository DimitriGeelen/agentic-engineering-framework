"""Pause re-dispatch chain — capture operator's answer + fire a retry via Resolver.

Origin: T-1809 (dispatch-safety slice 5). Closes the loop opened by slices 1-4:

  slice 1  — substrate recognizes pause_requested terminal events
  slice 2  — Resolver injects the risk-policy preamble teaching Workers to pause
  slice 3  — workflow linter catches typos in pause_threshold / allow_pause /
             pause_preamble before they reach dispatch time
  slice 4  — paused dispatches surface in the operator's review queue
  slice 5  — operator answers; this module captures the answer and fires a
             retry with retry_of_dispatch_id linking back + the answer in context

The retry dispatch carries a `retry_of_dispatch_id` field that slice 4's helper
already uses to deflate the awaiting-resolution list, so the queue clears
automatically the moment the retry is written.
"""

from __future__ import annotations

import json
import os
import sys
from pathlib import Path
from typing import Any, Dict, Optional, Tuple

# resolver lives next to this file in lib/.
sys.path.insert(0, str(Path(__file__).resolve().parent))
from resolver import resolve as _resolver_resolve  # noqa: E402
from resolver import load_task_frontmatter  # noqa: E402


_PROJECT_ROOT_DEFAULT = Path(os.environ.get("PROJECT_ROOT", ".")).resolve()


def _dispatches_log_path(project_root: Optional[Path] = None) -> Path:
    root = project_root or _PROJECT_ROOT_DEFAULT
    return root / ".context" / "dispatches.jsonl"


class PauseResolveError(ValueError):
    """Raised when an operator-resolution request cannot be honored.

    Concrete subclasses are not used; the message distinguishes the cause:
      - "dispatch X not found"
      - "dispatch X is not paused (outcome=Y)"
      - "dispatch X is already resolved by Z"
    """


def _scan_dispatches(project_root: Optional[Path] = None) -> Tuple[Optional[Dict[str, Any]], Dict[str, str], Path]:
    """One-pass scan: returns (none, {}, log_path) when log absent.

    Otherwise returns (None, retry_map, log_path) where retry_map is
    `{retry_of_dispatch_id: dispatch_id_of_retry}`. Caller looks up the
    paused dispatch by ID in a second pass for clarity.
    """
    log = _dispatches_log_path(project_root)
    if not log.exists():
        return None, {}, log
    retry_map: Dict[str, str] = {}
    with log.open() as f:
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
            ro = row.get("retry_of_dispatch_id")
            if ro:
                retry_map[ro] = row.get("dispatch_id") or "?"
    return None, retry_map, log


def _find_dispatch(dispatch_id: str, project_root: Optional[Path] = None) -> Optional[Dict[str, Any]]:
    """Find a dispatch row by dispatch_id (full match) or by 8-char prefix."""
    log = _dispatches_log_path(project_root)
    if not log.exists():
        return None
    match_exact = None
    match_prefix = None
    matches_prefix = 0
    with log.open() as f:
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
            did = row.get("dispatch_id") or ""
            if did == dispatch_id:
                match_exact = row
            elif len(dispatch_id) >= 6 and did.startswith(dispatch_id):
                matches_prefix += 1
                match_prefix = row
    if match_exact:
        return match_exact
    if matches_prefix == 1:
        return match_prefix
    if matches_prefix > 1:
        raise PauseResolveError(
            f"dispatch prefix {dispatch_id!r} is ambiguous ({matches_prefix} matches)"
        )
    return None


def resolve_pause(
    dispatch_id: str,
    answer: str,
    *,
    project_root: Optional[Path] = None,
    dry_run: bool = False,
) -> Tuple[Dict[str, Any], Dict[str, Any]]:
    """Capture operator's answer and re-dispatch via Resolver.

    Reads the paused dispatch row, validates that it is genuinely paused and
    not already resolved, then calls Resolver with the original task_id +
    task_type, threading `retry_of_dispatch_id` and `pause_resolution` so the
    rendered prompt prepends the RE-DISPATCH block and the new dispatches.jsonl
    row carries the link.

    Returns (envelope, row) — the same shape Resolver returns. With dry_run=True
    nothing is written to dispatches.jsonl but the envelope is faithful.
    """
    if not dispatch_id:
        raise PauseResolveError("dispatch_id is required")
    if not answer or not answer.strip():
        raise PauseResolveError("answer must be non-empty")

    paused_row = _find_dispatch(dispatch_id, project_root)
    if paused_row is None:
        raise PauseResolveError(f"dispatch {dispatch_id!r} not found in dispatches.jsonl")

    if paused_row.get("outcome") != "paused":
        raise PauseResolveError(
            f"dispatch {paused_row.get('dispatch_id')!r} is not paused "
            f"(outcome={paused_row.get('outcome')!r}); nothing to re-dispatch"
        )

    _, retry_map, _ = _scan_dispatches(project_root)
    full_id = paused_row.get("dispatch_id") or ""
    if full_id in retry_map:
        raise PauseResolveError(
            f"dispatch {full_id!r} is already resolved by {retry_map[full_id]!r}"
        )

    task_id = paused_row.get("task_id") or ""
    task_type = paused_row.get("task_type") or paused_row.get("workflow_id") or "default"
    if not task_id:
        raise PauseResolveError(f"dispatch {full_id!r} has no task_id; cannot re-dispatch")

    terminal_event = paused_row.get("terminal_event") or {}
    question = ""
    if isinstance(terminal_event, dict):
        question = str(terminal_event.get("question") or "").strip()

    task_context = load_task_frontmatter(task_id)
    task_context.setdefault("TASK_ID", task_id)
    task_context.setdefault("TASK_TYPE", task_type)
    task_context.setdefault("TASK_NAME", "")
    task_context.setdefault("TASK_DESCRIPTION", "")
    task_context.setdefault("ACCEPTANCE_CRITERIA", "(none)")

    return _resolver_resolve(
        task_id,
        task_type,
        task_context,
        dry_run=dry_run,
        retry_of_dispatch_id=full_id,
        pause_resolution={"question": question, "answer": answer.strip()},
    )
