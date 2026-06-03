"""Gap-register closure helpers.

Origin: T-2185 (Watchtower /gaps Close action + CLI verb). Surfaces a
mechanical-gauge-driven closure path for `status: watching` gaps in
`.context/project/concerns.yaml`. The first consumer is G-064 (orchestrator
substrate readiness), whose `closure_check_command:` points at
`tools/g064-readiness.py --json`.

Closure contract (recurring class, not one-off): any gap whose
`status_notes:` or `closure_check_command:` field specifies a gauge that
returns `verdict: READY` (or `ready: true`) qualifies for one-click closure.
The handler refuses 412 PRECONDITION_FAILED when the gauge is NOT_READY
unless `override` is supplied with a rationale (Tier-2 logged).

Design choices (locked at T-2185 build):

1. **Text-based surgical edit, not load-dump.** `concerns.yaml` carries heavy
   block-scalar prose and inline comments that PyYAML cannot round-trip
   without ruamel. We locate the gap block by `^- id: <gap_id>$` and the
   next `^- id:` boundary (or EOF) and mutate only the status/closed_date/
   closure_notes lines within that block. Comments + formatting preserved.

2. **Atomic write via tempfile + os.replace.** Same idiom as
   `update-task.sh` and `agents/context/lib/*` — write to `<path>.tmp`
   then rename, guaranteeing readers never see a half-written file.

3. **Audit log to `.context/audits/gap-closures.jsonl`.** One JSONL line
   per closure event (timestamp, gap_id, gauge verdict, override flag,
   rationale, actor). Append-only, never truncated.

4. **Stale-gauge-READY signal for `fw doctor`.** Returns days-since-READY
   for any gap with a gauge currently READY whose `last_reviewed:` or
   `trigger_event:` shows it has been READY ≥7 days unaddressed
   (operator-procrastination class — mirror of OBS-048).

References:
- T-1750 (gauge mechanism + status_notes closure contract)
- T-2184 (OBS-048 handoff doc; first observer of the dead-end UX)
- T-2197 (OBS-043 handoff doc; G-065's manual sed-style closure prescription)
- L-329 (propagation-of-authorised-decisions — operator's gauge IS the auth)
"""

from __future__ import annotations

import json
import os
import re
import shlex
import subprocess
import tempfile
from datetime import date, datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple


_PROJECT_ROOT_DEFAULT = Path(os.environ.get("PROJECT_ROOT", ".")).resolve()


# ── Path helpers ────────────────────────────────────────────────────────────

def _concerns_path(project_root: Optional[Path] = None) -> Path:
    root = project_root or _PROJECT_ROOT_DEFAULT
    return root / ".context" / "project" / "concerns.yaml"


def _audit_path(project_root: Optional[Path] = None) -> Path:
    root = project_root or _PROJECT_ROOT_DEFAULT
    return root / ".context" / "audits" / "gap-closures.jsonl"


# ── Gauge execution ─────────────────────────────────────────────────────────

def run_closure_gauge(
    command: str,
    project_root: Optional[Path] = None,
    timeout: int = 30,
) -> Tuple[str, str]:
    """Execute `command` (the gap's closure_check_command:) and parse the verdict.

    Returns (verdict, raw_stdout). `verdict` is normalised to one of:
      - "READY"      — gauge says ready (verdict=READY or ready=true)
      - "NOT_READY"  — gauge says not ready (verdict=NOT_READY or ready=false)
      - "UNKNOWN"    — gauge unavailable, malformed output, or non-zero exit
    """
    if not command:
        return ("UNKNOWN", "")

    root = project_root or _PROJECT_ROOT_DEFAULT
    try:
        argv = shlex.split(command)
    except ValueError:
        return ("UNKNOWN", "")

    try:
        proc = subprocess.run(
            argv,
            capture_output=True,
            text=True,
            timeout=timeout,
            cwd=str(root),
        )
    except (subprocess.TimeoutExpired, FileNotFoundError, OSError):
        return ("UNKNOWN", "")

    raw = (proc.stdout or "") + (proc.stderr or "")
    if proc.returncode != 0:
        return ("UNKNOWN", raw)

    try:
        data = json.loads(proc.stdout)
    except (ValueError, json.JSONDecodeError):
        return ("UNKNOWN", raw)

    if isinstance(data, dict):
        verdict = data.get("verdict")
        if isinstance(verdict, str) and verdict.upper() in ("READY", "NOT_READY"):
            return (verdict.upper(), raw)
        ready = data.get("ready")
        if ready is True:
            return ("READY", raw)
        if ready is False:
            return ("NOT_READY", raw)

    return ("UNKNOWN", raw)


# ── Concerns YAML parsing (read-only) ───────────────────────────────────────

def load_concerns_yaml(project_root: Optional[Path] = None) -> Dict[str, Any]:
    """Parse `.context/project/concerns.yaml` and return the data dict.

    Read-only — use `_rewrite_gap_block` (text-surgical) for writes.
    """
    import yaml  # lazy
    path = _concerns_path(project_root)
    if not path.exists():
        return {"concerns": []}
    with path.open() as f:
        data = yaml.safe_load(f) or {}
    # T-397 schema: concerns is canonical, gaps is legacy fallback.
    if "concerns" not in data and "gaps" in data:
        data["concerns"] = data["gaps"]
    return data


def find_gap(data: Dict[str, Any], gap_id: str) -> Optional[Dict[str, Any]]:
    """Locate a gap entry by id (case-sensitive). Returns the dict or None."""
    for entry in data.get("concerns", []) or []:
        if isinstance(entry, dict) and entry.get("id") == gap_id:
            return entry
    return None


# ── Surgical YAML block rewrite ─────────────────────────────────────────────

_GAP_HEADER_RE = re.compile(r"^- id: (\S+)\s*$", re.MULTILINE)
_STATUS_WATCHING_RE = re.compile(
    r"^(?P<indent>  )status: watching\s*$", re.MULTILINE
)


def _find_gap_block_span(text: str, gap_id: str) -> Optional[Tuple[int, int]]:
    """Return (start, end) byte offsets for the gap_id's block in concerns text.

    Block start = position of `- id: <gap_id>` line (inclusive).
    Block end   = position of the NEXT `- id:` line, or len(text) if last.
    Returns None if gap_id not found at the top-level list.
    """
    matches = list(_GAP_HEADER_RE.finditer(text))
    for i, m in enumerate(matches):
        if m.group(1) == gap_id:
            start = m.start()
            end = matches[i + 1].start() if i + 1 < len(matches) else len(text)
            return (start, end)
    return None


def _rewrite_gap_block(
    text: str,
    gap_id: str,
    closed_date: str,
    closure_notes: str,
) -> Optional[str]:
    """Return concerns.yaml text with gap_id's status flipped + closed_date +
    closure_notes inserted. Returns None if gap_id not found or already closed.
    """
    span = _find_gap_block_span(text, gap_id)
    if span is None:
        return None
    start, end = span
    block = text[start:end]

    status_match = _STATUS_WATCHING_RE.search(block)
    if not status_match:
        # Already closed, or status is something else.
        return None

    # Replace `  status: watching` with `  status: closed`.
    new_status_line = f"{status_match.group('indent')}status: closed"
    # Insert closed_date + closure_notes immediately after the status line.
    notes_indented = "\n".join(
        f"    {line}" if line else "" for line in closure_notes.splitlines()
    ) or "    (no notes)"

    insertion = (
        f"{new_status_line}\n"
        f"  closed_date: {closed_date}\n"
        f"  closure_notes: |\n"
        f"{notes_indented}\n"
    )

    new_block = block[: status_match.start()] + insertion + block[status_match.end() + 1 :]
    return text[:start] + new_block + text[end:]


def _atomic_write(path: Path, content: str) -> None:
    """Write content to path atomically via tempfile + os.replace."""
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(
        "w",
        delete=False,
        dir=str(path.parent),
        prefix=path.name + ".",
        suffix=".tmp",
    ) as tf:
        tf.write(content)
        tmp_path = Path(tf.name)
    os.replace(tmp_path, path)


# ── Audit log ───────────────────────────────────────────────────────────────

def _append_audit(
    gap_id: str,
    verdict: str,
    override: bool,
    rationale: Optional[str],
    actor: Optional[str],
    project_root: Optional[Path] = None,
) -> None:
    """Append one JSONL line to gap-closures audit log."""
    path = _audit_path(project_root)
    path.parent.mkdir(parents=True, exist_ok=True)
    entry = {
        "ts": datetime.now(timezone.utc).isoformat(),
        "gap_id": gap_id,
        "verdict": verdict,
        "override": bool(override),
        "rationale": rationale or "",
        "actor": actor or "unknown",
    }
    with path.open("a") as f:
        f.write(json.dumps(entry) + "\n")


# ── Public API ──────────────────────────────────────────────────────────────

class GapCloseError(Exception):
    """Closure refused — `code` is an HTTP-style status (404/409/412)."""

    def __init__(self, code: int, message: str):
        super().__init__(message)
        self.code = code
        self.message = message


def close_gap(
    gap_id: str,
    *,
    rationale: Optional[str] = None,
    override: bool = False,
    actor: Optional[str] = None,
    today: Optional[date] = None,
    project_root: Optional[Path] = None,
) -> Dict[str, Any]:
    """Flip a `status: watching` gap to `status: closed` after gauge check.

    Args:
      gap_id: e.g. "G-064".
      rationale: required when `override=True` (Tier-2 logged); optional
                 when gauge is READY (defaults to "gauge READY").
      override: bypass NOT_READY/UNKNOWN gauge verdicts. Requires rationale.
      actor: who initiated the close ("operator" / "agent" / "cli" / "web").
      today: date used for `closed_date:` (test seam).
      project_root: framework root (test seam).

    Returns:
      {"ok": True, "gap_id": ..., "new_status": "closed", "verdict": ...,
       "closed_date": ..., "closure_notes": ..., "audit_path": ...}

    Raises:
      GapCloseError(404, ...) — gap_id not found.
      GapCloseError(409, ...) — gap is not currently `status: watching`.
      GapCloseError(412, ...) — gauge is NOT_READY/UNKNOWN and override=False.
      GapCloseError(400, ...) — override=True but no rationale supplied.
    """
    today = today or date.today()
    closed_date = today.isoformat()

    data = load_concerns_yaml(project_root)
    gap = find_gap(data, gap_id)
    if gap is None:
        raise GapCloseError(404, f"Gap {gap_id} not found in concerns.yaml")
    if gap.get("status") != "watching":
        raise GapCloseError(
            409,
            f"Gap {gap_id} is not status:watching (current: {gap.get('status')!r})",
        )

    command = gap.get("closure_check_command") or ""
    verdict, raw = run_closure_gauge(command, project_root=project_root) if command else ("UNKNOWN", "")

    if verdict != "READY" and not override:
        raise GapCloseError(
            412,
            f"Gauge for {gap_id} verdict={verdict!r}; rerun with override=True + rationale to force",
        )
    if override and not rationale:
        raise GapCloseError(400, "override=True requires a rationale (Tier-2 logged)")

    closure_notes = (
        rationale
        if rationale
        else f"Closed via gauge {command!r} (verdict={verdict}) at {closed_date}."
    )

    path = _concerns_path(project_root)
    text = path.read_text()
    new_text = _rewrite_gap_block(text, gap_id, closed_date, closure_notes)
    if new_text is None:
        # Race or already-flipped between load and write.
        raise GapCloseError(409, f"Gap {gap_id} block not in expected shape (already flipped?)")

    _atomic_write(path, new_text)
    _append_audit(
        gap_id=gap_id,
        verdict=verdict,
        override=override,
        rationale=rationale,
        actor=actor,
        project_root=project_root,
    )

    return {
        "ok": True,
        "gap_id": gap_id,
        "new_status": "closed",
        "verdict": verdict,
        "closed_date": closed_date,
        "closure_notes": closure_notes,
        "audit_path": str(_audit_path(project_root)),
    }


def gauge_state(
    gap_id: str,
    project_root: Optional[Path] = None,
) -> Dict[str, Any]:
    """Return current gauge state for a gap. Used by /gaps render + fw doctor.

    Returns:
      {"gap_id": ..., "has_gauge": bool, "command": str|None,
       "verdict": "READY"|"NOT_READY"|"UNKNOWN"|None, "raw": str}
    """
    data = load_concerns_yaml(project_root)
    gap = find_gap(data, gap_id)
    if gap is None:
        return {"gap_id": gap_id, "has_gauge": False, "command": None, "verdict": None, "raw": ""}
    command = gap.get("closure_check_command") or ""
    if not command:
        return {"gap_id": gap_id, "has_gauge": False, "command": None, "verdict": None, "raw": ""}
    verdict, raw = run_closure_gauge(command, project_root=project_root)
    return {
        "gap_id": gap_id,
        "has_gauge": True,
        "command": command,
        "verdict": verdict,
        "raw": raw[:500],  # bounded for embedding into HTML/JSON
    }


def stale_ready_gaps(
    project_root: Optional[Path] = None,
    threshold_days: int = 7,
    today: Optional[date] = None,
) -> List[Dict[str, Any]]:
    """List `status: watching` gaps whose gauge is READY and whose
    `last_reviewed:` (or `created:` if absent) is ≥ threshold_days old.

    Used by `fw doctor` to surface operator-procrastination class
    (mirror of OBS-048).
    """
    today = today or date.today()
    data = load_concerns_yaml(project_root)
    out: List[Dict[str, Any]] = []
    for gap in data.get("concerns", []) or []:
        if not isinstance(gap, dict):
            continue
        if gap.get("status") != "watching":
            continue
        command = gap.get("closure_check_command") or ""
        if not command:
            continue
        verdict, _ = run_closure_gauge(command, project_root=project_root)
        if verdict != "READY":
            continue
        # Compute age. Prefer last_reviewed, fall back to created.
        ref_str = gap.get("last_reviewed") or gap.get("created") or ""
        try:
            ref_date = date.fromisoformat(str(ref_str)[:10])
            age_days = (today - ref_date).days
        except (ValueError, TypeError):
            age_days = threshold_days  # unknown → treat as exactly threshold
        if age_days >= threshold_days:
            out.append({
                "gap_id": gap.get("id"),
                "title": gap.get("title", ""),
                "age_days": age_days,
                "verdict": verdict,
            })
    return out
