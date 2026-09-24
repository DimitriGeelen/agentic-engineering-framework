#!/usr/bin/env python3
"""owner:human tasks with no real Human criteria have no route to closure (T-3449).

THE CLASS. A task that is `owner: human`, carries **no real `### Human`
criterion** (only the template's commented-out example, if anything), and has
**every `### Agent` criterion ticked** cannot close through any existing verb:

  * `fw task delegate` (D-626, T-3445) converts *deterministic Human
    criteria*. These have none to convert — it measures "0 open Human
    criterion/criteria … converted 0, left human 0, owner: human (unchanged)"
    and stops there.
  * An agent cannot close a human-owned task directly (CLAUDE.md
    §Human Task Completion Rule, §Autonomous Mode Boundaries) — that would be
    completing work the human owns, not delegation.
  * `fw review-queue` and `/approvals` only surface tasks with an OPEN Human
    criterion (`web.shared.count_unchecked_human_acs`); a task with zero real
    Human criteria has nothing open by that predicate, so it is invisible
    everywhere except CTL-029's general "completable but not closed" count,
    indistinguishable there from the ordinary agent-owned abandoned case.

THE PARSE THAT MATTERS. The task template ships a `### Human` heading whose
entire body is an HTML comment carrying a worked `[REVIEW]` example. A naive
scan of `- [ ]` / `- [x]` lines under `### Human` counts that example as a
real criterion — the exact false positive that made two ad-hoc measurements
of this class disagree during discovery. This module counts zero for that
task because the Human scan is comment-stripped before counting.

A SECOND, SHARPER PARSE BUG, FOUND WHILE VERIFYING THIS ONE. The obvious
building block — `lib.delegation.parse_criteria`, which scopes to the body of
`## Acceptance Criteria` (first-wins, bounded at the next `## ` heading,
T-3148) — undercounts Human criteria the T-3029/T-2420 way: a `### Human`
heading placed after an intervening `## ` heading (e.g. a stray
`## Status: COMPLETED …`) falls outside that bound and is invisible to it.
Measured live on T-2200: a genuine, unticked `[REVIEW]` Human criterion sits
behind exactly such an intervening heading, and `lib.delegation.human_criteria`
reports zero — which would have put T-2200 in this class and recommended a
one-command close over a real unanswered criterion. `update-task.sh`'s own
close gate already refuses this shape for the opposite reason (T-3029:
"`### Human` heading found but positioned outside `## Acceptance Criteria`"),
so treating it as zero here would not just be wrong, it would recommend an
action the close gate does not even allow un-bypassed.

The Human side of this predicate therefore does NOT use
`lib.delegation.parse_criteria`. It uses `web.shared.count_human_acs_total`
(T-3449, sibling of the T-3139-fixed `count_unchecked_human_acs`), which
scans for `### Human` wherever it sits in the WHOLE document, not just inside
`## Acceptance Criteria` — the scope T-3139 already established as correct
for exactly this reason, with a portable inline fallback when `web/` is not
on the import path (consumer projects without Watchtower vendored — same
fallback shape `bin/fw`'s review-queue command already carries for the same
function).

The Agent side has no equivalent hazard — `### Agent` is always the first
subhead directly under `## Acceptance Criteria` in every task this corpus
has, and `update-task.sh`'s own P-010 gate extracts it the same
AC-section-bounded way — so `lib.delegation.parse_criteria` /
`agent_criteria` (T-3445) is reused as-is, matching the close gate's own
ground truth for "all Agent ACs ticked" rather than re-deriving it.
"""

from __future__ import annotations

import json
import re as _re
import sys
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional

_HERE = Path(__file__).resolve().parent
if str(_HERE.parent) not in sys.path:
    sys.path.insert(0, str(_HERE.parent))

from lib.delegation import Criterion, frontmatter, parse_criteria  # noqa: E402

try:
    from web.shared import count_human_acs_total  # noqa: E402
except ImportError:
    # Portable fallback — same algorithm as web.shared.count_human_acs_total
    # (T-3449) / count_unchecked_human_acs (T-3139/T-1581), for contexts where
    # web/ isn't on the import path (e.g. a consumer project without
    # Watchtower vendored). Mirrors the identical fallback bin/fw's
    # review-queue command already carries for count_unchecked_human_acs.
    def count_human_acs_total(body: str) -> int:  # type: ignore[misc]
        if not body:
            return 0
        text = _re.sub(r"<!--.*?-->", "", body, flags=_re.DOTALL)
        total = 0
        for m in _re.finditer(
            r"^### Human\b[^\n]*$(.*?)(?=^#{1,3} |\Z)", text, _re.MULTILINE | _re.DOTALL,
        ):
            total += len(_re.findall(r"^\s*-\s*\[[ xX]\]", m.group(1), _re.MULTILINE))
        return total


def agent_criteria(text: str) -> list[Criterion]:
    """Criteria under a `### Agent` subhead (AC-section-bounded — see module
    docstring for why this scope is safe for Agent but not for Human)."""
    return [c for c in parse_criteria(text) if c.subhead.lower().startswith("agent")]


def is_unclosable_misfiled(meta: dict, text: str) -> bool:
    """True iff all three hold:

      1. `owner: human`
      2. zero real `### Human` AC lines anywhere in the document
         (HTML-comment-only doesn't count; see module docstring for why this
         is a whole-document scan and not bounded to `## Acceptance Criteria`)
      3. at least one `### Agent` criterion, and every one is ticked

    A task with no `### Agent` split at all (flat, unheaded AC list) is never
    a member — the class is specifically the Agent/Human split left with
    nothing on the Human side, not "any owner:human task with checked boxes".
    """
    owner = str(meta.get("owner") or "").strip().lower()
    if owner != "human":
        return False
    if count_human_acs_total(text) > 0:
        return False
    agents = agent_criteria(text)
    if not agents:
        return False
    return all(c.ticked for c in agents)


def age_days(meta: dict, now: Optional[datetime] = None) -> int:
    """Age in days from frontmatter `created`, falling back to `last_update`.

    Missing/unparseable dates return 0 rather than raising — an evidence line
    with age 0 is a visible oddity an operator can question; a crash mid-scan
    would hide every other row behind it.
    """
    now = now or datetime.now(timezone.utc)
    for field in ("created", "last_update"):
        v = meta.get(field)
        if not v:
            continue
        try:
            dt = datetime.fromisoformat(str(v).replace("Z", "+00:00"))
            return int((now - dt).total_seconds() // 86400)
        except (ValueError, TypeError):
            continue
    return 0


@dataclass
class Member:
    task_id: str
    path: Path
    age_days: int
    agent_ac_count: int


def scan_active(project_root: Path) -> list[Member]:
    """Every active task matching `is_unclosable_misfiled`, oldest first.

    Active tasks only — a completed task closed by definition, so it cannot
    be a member of "has no route to closure".
    """
    tasks_dir = Path(project_root) / ".tasks" / "active"
    out: list[Member] = []
    if not tasks_dir.is_dir():
        return out
    now = datetime.now(timezone.utc)
    for f in sorted(tasks_dir.glob("T-*.md")):
        try:
            text = f.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue
        meta = frontmatter(text)
        if not is_unclosable_misfiled(meta, text):
            continue
        out.append(Member(
            task_id=str(meta.get("id") or f.stem),
            path=f,
            age_days=age_days(meta, now),
            agent_ac_count=len(agent_criteria(text)),
        ))
    out.sort(key=lambda m: -m.age_days)
    return out


# ── CLI: `python3 -m lib.unclosable_misfiled scan [--json] [--facts]` ────────
#
# --facts emits one TSV line for the audit/doctor rails, same shape as
# lib/fabric_doctor_facts.py and lib/delegation_cli.py's `surface --facts` —
# both rails read the same scan rather than each re-deriving the count.


def main(argv=None) -> int:
    import argparse
    import os

    p = argparse.ArgumentParser(prog="fw unclosable-misfiled", description=__doc__)
    sub = p.add_subparsers(dest="cmd", required=True)
    s = sub.add_parser("scan", help="scan active/ for the unclosable-misfiled class")
    s.add_argument("--json", action="store_true")
    s.add_argument("--facts", action="store_true",
                    help="one TSV line: count<TAB>comma-joined ids (first 10)")
    args = p.parse_args(argv)

    root = Path(os.environ.get("PROJECT_ROOT") or os.getcwd())
    members = scan_active(root)

    if args.cmd == "scan":
        if args.facts:
            ids = ",".join(m.task_id for m in members[:10])
            print(f"{len(members)}\t{ids}")
            return 0
        if args.json:
            print(json.dumps([
                {"id": m.task_id, "path": str(m.path), "age_days": m.age_days,
                 "agent_ac_count": m.agent_ac_count}
                for m in members
            ], indent=2))
            return 0
        for m in members:
            print(f"{m.task_id}\t{m.age_days}d\t{m.agent_ac_count} agent AC(s)\t{m.path}")
    return 0


if __name__ == "__main__":  # pragma: no cover
    sys.exit(main())
