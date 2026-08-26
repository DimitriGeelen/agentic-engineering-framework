"""T-3175: inceptions that are DECIDED but still open — the queue nobody showed.

THE GAP THIS CLOSES.
`/approvals` splits inceptions into two buckets and a decided-but-unclosed one
falls between them:

  - §Decisions      — `_extract_decision(body) == "pending"`. A recorded decision
                      drops OUT of this section the moment it is recorded.
  - §Verifications  — build tasks with unchecked Human ACs. An inception whose
                      Human AC is already ticked is not here either.

So the operator records a GO, the task stays in `active/` because
`update-task.sh:87` (Human Sovereignty Gate, R-033) refuses agent closure on
`owner: human` — and the one action left is visible on no surface at all.

Measured 2026-08-26 across all five `/approvals` sections and `fw review-queue`:
T-3159, T-3149 and T-3097 appeared on neither. T-3097 had been in that state
since 2026-08-20. The queue did not look wrong; it looked *complete*, which is
why nobody went looking. Same false-green family as the rest of arc-012.

WHY DEFER IS EXCLUDED.
A DEFER is a deliberate park with its own revisit machinery (`revisit_at`,
T-1451, and the G-053 daily scan), and `_count_deferred_inceptions` already
surfaces the count as a hint. Listing DEFERs here as "awaiting closure" would
misdescribe them — they are awaiting a *date*, not an action. GO and NO-GO both
conclude an inception, so both leave exactly one step outstanding.
"""

from __future__ import annotations

import re
from pathlib import Path

# A decision that CONCLUDES an inception. DEFER deliberately absent — see module
# docstring; it is a park, not a pending closure.
CONCLUDING = ("GO", "NO-GO")

_DECISION_RE = re.compile(r"^\*\*Decision\*\*:\s*(GO|NO-GO|DEFER)\b", re.MULTILINE)


def extract_decision(body: str) -> str | None:
    """The recorded decision, or None. First match wins.

    T-3142 found exactly one task in 3126 carrying two conflicting verdicts (a
    stale DEFER stub left below a real GO), so first-match is a real choice, not
    an incidental one: it matches the reader's eye and the gate in
    `update-task.sh:check_inception_decision`, which also greps rather than
    parsing. Agreeing with the gate matters more than being clever here — a
    queue that disagreed with the gate would send the operator to a task the
    gate then refuses.
    """
    m = _DECISION_RE.search(body or "")
    return m.group(1) if m else None


def is_decided_unclosed(frontmatter: dict, body: str) -> bool:
    """True when this task needs exactly one thing: the operator closing it.

    Deliberately NOT keyed on `owner: human` alone. Ownership is what makes the
    gate refuse, but the operator-visible fact is "decided and still open" — an
    agent-owned inception in this state is equally stuck and equally invisible,
    and hiding it would reproduce the defect one bucket over.
    """
    if (frontmatter or {}).get("workflow_type") != "inception":
        return False
    # Still in active/. A closed inception has moved to completed/.
    if (frontmatter or {}).get("_location") != "active":
        return False
    # work-completed-in-active is partial-complete: it is already carried by the
    # Human-ACs section, so listing it here would double-count one action.
    if str((frontmatter or {}).get("status", "")).strip() == "work-completed":
        return False
    return extract_decision(body) in CONCLUDING


def scan(task_metadata: list[dict], read_body) -> list[dict]:
    """Select decided-unclosed inceptions.

    `read_body` is injected rather than imported so the Watchtower side can pass
    its mtime-keyed cache (T-2102) and tests can pass a plain reader. Keeping the
    predicate free of I/O is what lets one implementation serve both surfaces —
    the two-surfaces-one-predicate requirement is the reason this module exists
    rather than a second copy inside the blueprint.
    """
    out = []
    for fm in task_metadata or []:
        path = fm.get("_path")
        if not path:
            continue
        body = read_body(path) or ""
        if not is_decided_unclosed(fm, body):
            continue
        out.append({
            "task_id": fm.get("id") or Path(str(path)).name.split("-")[0],
            "name": fm.get("name") or "",
            "status": fm.get("status") or "",
            "owner": fm.get("owner") or "",
            "decision": extract_decision(body),
            "path": str(path),
        })
    out.sort(key=lambda r: r["task_id"])
    return out
