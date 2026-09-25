"""BVP outcomes ledger — slice 1 of docs/architecture/bvp-feedback-loop.md.

T-3486, under T-3484 (GO 2026-09-26). The feedback loop's storage and its cost
axis. Needs no new instrumentation: `.context/dispatches.jsonl` already carries
`task_id` alongside real token accounting, so per-task cost for dispatched work
is a join, not a measurement project.

**Deliberately standalone.** This module imports nothing from `lib/bvp.sh` and
touches neither it nor `policy/value-drivers.yaml`. Two reasons, and the second
outlives the first:

1. A live worker held uncommitted edits in both when this was written
   (`bvp-equality`, T-3485, the quadrant classifier's value axis). Editing a
   file a live worker owns cost us a worker's commit earlier the same day
   (OBS-510).
2. **The ledger that measures the scorer should not live inside the scorer.** A
   calibration surface coupled to the thing it calibrates cannot be reasoned
   about independently, and cannot be read when the scorer is mid-change.

**The rule that makes the cost axis honest.** Work done in a parent session has
no per-task token attribution — its cost smears across a session that touched
dozens of tasks. Writing `0` there would be a lie that averages into every
calibration, making unmeasured work look cheap and therefore attractive. So an
unattributable task records ``attributable: False`` with the token fields
ABSENT, never zero. Same discipline as T-3068's `blast_radius` (*unknown, not
zero*) and Amendment 1's `UNKNOWN` ack state (*a valid terminal state, never
silently promoted or demoted*).

Pure stdlib.
"""

from __future__ import annotations

import json
import os
from pathlib import Path

#: The four fields TermLink/Claude write under `terminal_event.usage`. Summed
#: across every dispatch row for a task: a task dispatched twice cost both.
_USAGE_KEYS = (
    ("tokens_in", "input_tokens"),
    ("tokens_out", "output_tokens"),
    ("cache_read", "cache_read_input_tokens"),
    ("cache_create", "cache_creation_input_tokens"),
)

PHASES = ("predicted", "realised", "revisit")

LEDGER_REL = os.path.join(".context", "bvp-outcomes.jsonl")
DISPATCHES_REL = os.path.join(".context", "dispatches.jsonl")


class OutcomeError(ValueError):
    pass


def _root(root: str | os.PathLike | None = None) -> Path:
    if root:
        return Path(root)
    return Path(os.environ.get("PROJECT_ROOT") or os.environ.get("FRAMEWORK_ROOT") or ".")


# ── cost: the join ──────────────────────────────────────────────────────────

def cost_for_task(task_id: str, root=None) -> dict | None:
    """Summed token cost for `task_id` from dispatch records, or None.

    None means NOT MEASURED — the caller must render that as
    ``attributable: False`` and must not substitute zero. Returning 0 here
    would be indistinguishable from a real dispatch that happened to use no
    tokens, which is the collapse this whole module exists to avoid.
    """
    path = _root(root) / DISPATCHES_REL
    if not path.is_file():
        return None
    totals = {key: 0 for key, _ in _USAGE_KEYS}
    rows = 0
    try:
        with path.open(encoding="utf-8", errors="ignore") as fh:
            for line in fh:
                line = line.strip()
                if not line or task_id not in line:
                    continue  # cheap prefilter; the parse below is authoritative
                try:
                    rec = json.loads(line)
                except ValueError:
                    continue
                if rec.get("task_id") != task_id:
                    continue
                usage = ((rec.get("terminal_event") or {}).get("usage") or {})
                if not usage:
                    continue  # a dispatch row with no usage block measures nothing
                rows += 1
                for key, src in _USAGE_KEYS:
                    value = usage.get(src)
                    if isinstance(value, (int, float)):
                        totals[key] += int(value)
    except OSError:
        return None
    if rows == 0:
        return None
    # Built as a fresh dict rather than mutated into `totals`: the token sums are
    # ints, the provenance fields are not, and keeping them in one loosely-typed
    # accumulator is how a source string ends up averaged as a number.
    result: dict[str, object] = dict(totals)
    result["dispatch_rows"] = rows
    result["attributable"] = True
    result["source"] = "dispatches.jsonl:terminal_event.usage"
    return result


def unattributable(reason: str = "no dispatch row with a usage block") -> dict:
    """The honest shape for work whose cost cannot be attributed.

    Token fields are ABSENT rather than zero — a consumer that averages this
    row's cost must be forced to skip it, not silently pull the mean down.
    """
    return {"attributable": False, "reason": reason}


# ── the ledger ──────────────────────────────────────────────────────────────

def append(row: dict, root=None) -> Path:
    """Append one row. Append-only by construction: nothing here rewrites.

    History stays immutable so a recorded score is always traceable to the
    rubric that produced it, and so calibration cannot quietly revise its own
    past predictions upward (producer-not-judge).
    """
    if row.get("phase") not in PHASES:
        raise OutcomeError(f"phase must be one of {PHASES}, got {row.get('phase')!r}")
    if not row.get("task_id"):
        raise OutcomeError("task_id is required")
    path = _root(root) / LEDGER_REL
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a", encoding="utf-8") as fh:
        fh.write(json.dumps(row, sort_keys=True) + "\n")
    return path


def read_rows(root=None) -> list[dict]:
    path = _root(root) / LEDGER_REL
    if not path.is_file():
        return []
    out = []
    with path.open(encoding="utf-8", errors="ignore") as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            try:
                out.append(json.loads(line))
            except ValueError:
                continue
    return out


def record_realised(task_id: str, *, ts: str, rubric_sha: str | None = None,
                    predicted: dict | None = None, quality: dict | None = None,
                    root=None) -> dict:
    """Build and append a `realised` row, resolving cost from the join."""
    cost = cost_for_task(task_id, root=root) or unattributable()
    row = {
        "task_id": task_id,
        "ts": ts,
        "phase": "realised",
        "cost": cost,
        "quality": quality or {},
        "value": {"usage_30d": None, "peer_adoption": None, "revisit_verdict": None},
    }
    if rubric_sha:
        row["rubric_sha"] = rubric_sha
    if predicted:
        row["predicted"] = predicted
    append(row, root=root)
    return row


# ── backfill ────────────────────────────────────────────────────────────────

def attributable_fraction(rows: list[dict]) -> dict:
    """How much of a row set carries real cost.

    Reported with every calibration on purpose. The dispatched subset is NOT a
    random sample of the work — CLAUDE.md's own table measures inception
    dispatches at 0% verification pass and refactors at 65% — so a number
    computed over it alone is biased toward whatever we happen to dispatch. A
    calibration that hides this fraction is reporting a biased estimate as a
    plain one.
    """
    total = len(rows)
    attributable = sum(1 for r in rows if (r.get("cost") or {}).get("attributable") is True)
    return {
        "rows": total,
        "attributable": attributable,
        "unattributable": total - attributable,
        "fraction": (attributable / total) if total else None,
    }
