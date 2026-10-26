#!/usr/bin/env python3
"""Arc-focus staleness check — one predicate for the handover and fw doctor.

T-4774 (operator ruling 2026-10-26). `.context/working/arc-focus.yaml`
(T-1661) is written once by `fw arc focus <arc>` and nothing ever looked at it
again: ours stayed pinned to ewcr-arc0-contract-evidence from 2026-09-17 while
every task since was outside that arc, and the handover kept announcing it as
the "Current Arc". Two signals:

  AGE    focused_at is older than ARC_FOCUS_STALE_DAYS (or missing).
  DRIFT  of the tasks committed in the last ARC_FOCUS_STALE_DAYS days, fewer
         than MIN_FRACTION belong to the focused arc. Handover and WM-
         commits are not work and are not counted.

Silent (OK) when no arc is focused. Advisory only: callers WARN, never block.

CLI:  python3 lib/arc_focus_health.py --project-root DIR [--days N]
Prints one `VERDICT|message|hint` line per finding (AGE, DRIFT) or a single
OK line. Exit 0 always.
"""

from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from arc_membership import scan_tasks_by_arc_membership  # noqa: E402

DEFAULT_DAYS = 14
# DRIFT fires when fewer than this share of recent tasks are in the focused arc.
MIN_FRACTION = 0.10

_TASK_SUBJECT_RE = re.compile(r"^(T-\d+)\b")
# Session/checkpoint handover commits (and their enrichments) are bookkeeping.
_HANDOVER_SUBJECT_RE = re.compile(r"\bhandover S-\d", re.IGNORECASE)


def _hint(arc: str) -> str:
    return (f"Re-confirm with 'fw arc focus {arc}' (refreshes focused_at) "
            f"or clear it with 'fw arc focus --clear'.")


def read_focus(project_root: Path) -> tuple[str, str]:
    """(current_arc, focused_at) from arc-focus.yaml; "" for absent/null."""
    path = project_root / ".context" / "working" / "arc-focus.yaml"
    try:
        text = path.read_text(encoding="utf-8")
    except OSError:
        return "", ""
    vals = {}
    for key in ("current_arc", "focused_at"):
        m = re.search(rf"^{key}:\s*(.*?)\s*$", text, re.MULTILINE)
        v = (m.group(1) if m else "").strip().strip("'\"")
        vals[key] = "" if v in ("", "null", "~") else v
    return vals["current_arc"], vals["focused_at"]


def _arc_numeric_id(project_root: Path, slug: str) -> str:
    try:
        text = (project_root / ".context" / "arcs" / f"{slug}.yaml").read_text(encoding="utf-8")
    except OSError:
        return ""
    m = re.search(r"^id:\s*['\"]?([^'\"\s]+)", text, re.MULTILINE)
    return m.group(1) if m else ""


def recent_task_ids(project_root: Path, days: int) -> set[str]:
    """Task ids named at the start of commit subjects in the last `days` days."""
    try:
        out = subprocess.run(
            ["git", "-C", str(project_root), "log", f"--since={days} days ago", "--format=%s"],
            capture_output=True, text=True, timeout=30,
        ).stdout
    except (OSError, subprocess.SubprocessError):
        return set()
    ids = set()
    for subj in out.splitlines():
        if _HANDOVER_SUBJECT_RE.search(subj):
            continue
        m = _TASK_SUBJECT_RE.match(subj)
        if m:
            ids.add(m.group(1))
    return ids


def arc_task_ids(project_root: Path, slug: str) -> set[str]:
    by_arc_id, by_tag = scan_tasks_by_arc_membership(project_root)
    names = {slug}
    numeric = _arc_numeric_id(project_root, slug)
    if numeric:
        names.add(numeric)
    ids: set[str] = set()
    for n in names:
        ids.update(by_arc_id.get(n, []))
        ids.update(by_tag.get(f"arc:{n}", []))
    return ids


def _parse_ts(raw: str) -> datetime | None:
    try:
        ts = datetime.fromisoformat(raw.replace("Z", "+00:00"))
    except ValueError:
        return None
    return ts if ts.tzinfo else ts.replace(tzinfo=timezone.utc)


def check(project_root: Path | str, days: int = DEFAULT_DAYS,
          now: datetime | None = None) -> list[tuple[str, str, str]]:
    root = Path(project_root)
    arc, focused_at = read_focus(root)
    if not arc:
        return [("OK", "Arc focus: none set", "")]
    now = now or datetime.now(timezone.utc)
    findings: list[tuple[str, str, str]] = []

    ts = _parse_ts(focused_at) if focused_at else None
    if ts is None:
        findings.append(("AGE", f"Arc focus '{arc}' has no readable focused_at "
                                f"({focused_at or 'missing'})", _hint(arc)))
    else:
        age = (now - ts).days
        if age > days:
            findings.append(("AGE", f"Arc focus '{arc}' set {ts.date().isoformat()}, "
                                    f"{age} days ago (limit {days})", _hint(arc)))

    recent = recent_task_ids(root, days)
    if recent:
        inside = len(recent & arc_task_ids(root, arc))
        if inside / len(recent) < MIN_FRACTION:
            findings.append(("DRIFT", f"Arc focus '{arc}': {inside} of {len(recent)} task(s) "
                                      f"committed in the last {days} days are in it, "
                                      f"{len(recent) - inside} outside "
                                      f"(below {int(MIN_FRACTION * 100)}%)", _hint(arc)))

    if not findings:
        age_txt = f", set {ts.date().isoformat()}" if ts else ""
        return [("OK", f"Arc focus '{arc}' current{age_txt}", "")]
    return findings


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--project-root", default=os.environ.get("PROJECT_ROOT", "."))
    ap.add_argument("--days", type=int, default=None)
    args = ap.parse_args(argv)
    days = args.days
    if days is None:
        try:
            days = int(os.environ.get("FW_ARC_FOCUS_STALE_DAYS", DEFAULT_DAYS))
        except ValueError:
            days = DEFAULT_DAYS
    for verdict, msg, hint in check(args.project_root, days):
        print(f"{verdict}|{msg}|{hint}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
