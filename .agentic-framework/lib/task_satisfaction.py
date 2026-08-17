#!/usr/bin/env python3
"""Find active tasks whose acceptance criteria are all satisfied but which were
never closed (T-3061).

Measured origin (T-3060): 17 of ~43 in-flight tasks were in this state — every
Agent AC ticked, no Human AC outstanding, still sitting in .tasks/active/ as
started-work. T-3042 was the instance that surfaced it; the sweep showed it was
a ~40% rate, not a slip.

The cost compounds in two directions and neither is visible from the task file:

  * a task that never reaches work-completed never generates its episodic or
    learnings, so finished work never reaches recall — the corpus under-reports
    itself, silently and permanently;
  * it inflates the concurrent started-work count that `fw work-on` warns about,
    which turns that warning into background noise, which is why nobody chased
    the number down.

WHAT THIS DOES NOT DO
---------------------
It never closes anything, and the caller must not either. A ticked checkbox is a
*claim* by whoever wrote it, not evidence. CLAUDE.md's Human Task Completion
Rule forbids batch-closing on that basis, and the whole value of this rail is
that it makes candidates visible without making them cheap to rubber-stamp. It
reports; a human decides.

The `gated` / `ungated` split exists for the same reason. A task with real
commands in `## Verification` has something mechanical that would run at close
time and could still refuse. A task with an empty Verification block has
nothing — its ticked boxes are the only evidence there is. Six of T-3060's
seventeen were in that second class. Presenting both as equally ready would
invite exactly the unevidenced close this is meant to prevent.
"""

from __future__ import annotations

import os
import re
import sys
from pathlib import Path
from typing import Dict, List, Optional

# Statuses that mean "someone is or was working on this". A `captured` task with
# ticked ACs is not the bug — nobody claimed to be finishing it.
LIVE_STATUSES = {"started-work", "issues"}

_COMMENT_RE = re.compile(r"<!--.*?-->", re.S)
_CHECKBOX_RE = re.compile(r"^\s*[-*]\s*\[( |x|X)\]\s*(.*)$")
_HEADING_RE = re.compile(r"^##\s+(.*)$")
_SUBHEADING_RE = re.compile(r"^###\s+(.*)$")


def strip_comments(text: str) -> str:
    """Remove HTML comment blocks.

    This is the load-bearing step, not a tidy-up. The task template ships worked
    example ACs *inside* comment blocks — an unticked generic criterion pair plus
    `[REVIEW]` and `[REVIEWER]` samples. Count those and every freshly-created
    task reads as having unsatisfied Human ACs, so nothing ever qualifies and the
    rail reports zero across the whole corpus. A zero that looks like health is
    the worst failure available here: it is indistinguishable from a clean
    corpus, and nothing would ever prompt anyone to check.

    Unterminated `<!--` is treated as commenting out the remainder of the file,
    matching how a Markdown renderer behaves.
    """
    text = _COMMENT_RE.sub("", text)
    idx = text.find("<!--")
    return text[:idx] if idx != -1 else text


def _frontmatter_value(text: str, key: str) -> str:
    m = re.search(rf"^{re.escape(key)}:\s*(.*)$", text, re.M)
    if not m:
        return ""
    return m.group(1).strip().strip('"').strip("'")


def _section(text: str, heading: str) -> str:
    """Return the body under `## <heading>`, up to the next `## ` heading."""
    lines = text.split("\n")
    out: List[str] = []
    inside = False
    for line in lines:
        h = _HEADING_RE.match(line)
        if h:
            if inside:
                break
            inside = h.group(1).strip().lower().startswith(heading.lower())
            continue
        if inside:
            out.append(line)
    return "\n".join(out)


def _split_ac_buckets(ac_body: str) -> Dict[str, List[str]]:
    """Split the AC body into agent/human buckets by `### Agent` / `### Human`.

    A task with no subsection headers has all its ACs treated as Agent ACs —
    that is the pre-T-193 shape and P-010 gates on it the same way.
    """
    buckets: Dict[str, List[str]] = {"agent": [], "human": []}
    current = None
    for line in ac_body.split("\n"):
        sub = _SUBHEADING_RE.match(line)
        if sub:
            name = sub.group(1).strip().lower()
            current = "human" if name.startswith("human") else "agent"
            continue
        cb = _CHECKBOX_RE.match(line)
        if cb:
            target = current if current else "agent"
            buckets[target].append(cb.group(1).lower())
    return buckets


def has_real_verification(text: str) -> bool:
    """True when `## Verification` holds at least one executable line.

    Comments and blank lines do not count — the shipped template is ~60 lines of
    guidance with no commands, so "the section exists" is not the question.
    """
    body = _section(text, "Verification")
    for line in body.split("\n"):
        s = line.strip()
        if s and not s.startswith("#"):
            return True
    return False


def analyse(path: Path) -> Optional[Dict[str, object]]:
    """Return a record when this task is satisfied-but-unclosed, else None."""
    try:
        raw = path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return None
    return analyse_text(raw, path)


def analyse_text(raw: str, path: Optional[Path] = None) -> Optional[Dict[str, object]]:
    """Same judgement as `analyse`, on content already in hand.

    Split out for `agents/audit/active-task-scan.py`, which exists specifically to
    read each task file exactly once (T-955 collapsed five bash loops into that one
    pass). Handing it a path-taking API would have made it either re-read every
    file or keep its own copy of this rule — it briefly did the latter, and a
    second definition of "satisfied" is a divergence waiting to happen even while
    the two agree, because only one of them has tests.
    """
    status = _frontmatter_value(raw, "status")
    if status not in LIVE_STATUSES:
        return None

    body = strip_comments(raw)
    buckets = _split_ac_buckets(_section(body, "Acceptance Criteria"))

    agent, human = buckets["agent"], buckets["human"]
    if not agent:
        return None                      # nothing was ever claimed
    if any(m == " " for m in agent):
        return None                      # work outstanding
    if any(m == " " for m in human):
        return None                      # awaiting the operator, correctly

    return {
        # `path` is optional now, so the id falls back to frontmatter only.
        "id": _frontmatter_value(raw, "id") or (path.stem.split("-")[0] if path else ""),
        "status": status,
        "workflow_type": _frontmatter_value(raw, "workflow_type"),
        "name": (_frontmatter_value(raw, "name") or "")[:60],
        "agent_acs": len(agent),
        "human_acs": len(human),
        "gated": has_real_verification(raw),
        "path": str(path) if path else "",
    }


def scan(tasks_dir: Path) -> List[Dict[str, object]]:
    if not tasks_dir.is_dir():
        return []
    found = [r for r in (analyse(p) for p in sorted(tasks_dir.glob("T-*.md"))) if r]
    return sorted(found, key=lambda r: str(r["id"]))


def main(argv: List[str]) -> int:
    project_root = Path(argv[1]) if len(argv) > 1 else Path(
        os.environ.get("PROJECT_ROOT", ".")
    )
    rows = scan(project_root / ".tasks" / "active")

    gated = [r for r in rows if r["gated"]]
    ungated = [r for r in rows if not r["gated"]]

    # Machine-readable, one record per line, for the audit shell to consume.
    print(f"TOTAL {len(rows)}")
    print(f"GATED {len(gated)} {','.join(str(r['id']) for r in gated)}")
    print(f"UNGATED {len(ungated)} {','.join(str(r['id']) for r in ungated)}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
