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
import re
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


FEEDBACK_REL = os.path.join(".context", "working", "feedback-stream.yaml")

#: T-3497: event kinds in the feedback stream that mean "somebody said the
#: machine was wrong". `override_applied` is a reviewer finding declared a false
#: positive; `auto_tick` records the reviewer ticking an AC on its own authority,
#: which is a claim worth counting beside the corrections to it.
CORRECTION_KINDS = ("override_applied",)
AUTOTICK_KINDS = ("auto_tick",)

#: Title/tag vocabulary that makes a task bug-class, mirroring the T-1550 RCA
#: gate's own trigger set so "defect" means the same thing in both places.
_BUG_RE = re.compile(
    r"\b(bug|fix|error|regression|broken|crash|hotfix|defect|fail(?:ure|ing)?)\b", re.I)


def quality_for_task(task_id: str, root=None) -> dict:
    """Correction and follow-on-defect counts for `task_id`.

    Counts events by their `kind:` line, not by substring. That distinction is
    not pedantry — it is what corrected this function's own premise. The design
    doc claimed 1,970 correction entries from a grep for
    `auto_tick|override|untick` across the whole file; counted by kind the corpus
    holds **125 `override_applied` and 12 `auto_tick`**, because the grep was
    matching payload prose. A signal counted the wrong way is not a smaller
    signal, it is a different one.

    `available: False` when the stream cannot be read. A missing stream is not a
    task with zero corrections, and collapsing the two would let an unreadable
    source read as a clean record — the same rule S1 applies to cost.
    """
    root_path = _root(root)
    # Counters kept as plain ints in their own names, not in a dict[str, object]
    # accumulator — the same typing trap S1's cost join hit, where ints and
    # provenance strings shared one loosely-typed bag.
    corrections = 0
    autoticks = 0
    available = True
    reason = None

    stream = root_path / FEEDBACK_REL
    if not stream.is_file():
        available, reason = False, "feedback stream absent"
    else:
        try:
            kind = None
            with stream.open(encoding="utf-8", errors="ignore") as fh:
                for line in fh:
                    if line.startswith("kind:"):
                        kind = line.split(":", 1)[1].strip()
                    elif line.startswith("task_id:") and kind:
                        if line.split(":", 1)[1].strip().strip("'\"") == task_id:
                            if kind in CORRECTION_KINDS:
                                corrections += 1
                            elif kind in AUTOTICK_KINDS:
                                autoticks += 1
        except OSError:
            available, reason = False, "feedback stream unreadable"

    out: dict[str, object] = {
        "operator_corrections": corrections,
        "auto_ticks": autoticks,
        "follow_on_defects": _follow_on_defects(task_id, root_path),
        "available": available,
    }
    if reason:
        out["reason"] = reason
    return out


def _follow_on_defects(task_id: str, root_path: Path) -> int:
    """Bug-class tasks filed AT OR AFTER `task_id` that name it in related_tasks.

    The at-or-after rule matters: a task filed before this one cannot be a defect
    this one caused, however much it mentions it. Same discipline as S1's cost
    join, which refuses dispatch rows that predate the task.
    """
    import glob as _glob

    subject_created = None
    for pattern in ("active", "completed"):
        for path in _glob.glob(str(root_path / ".tasks" / pattern / f"{task_id}-*.md")):
            try:
                text = open(path, encoding="utf-8", errors="ignore").read()
            except OSError:
                continue
            found = re.search(r"^created:\s*'?(\S{10})", text, re.M)
            if found:
                subject_created = found.group(1)
    if not subject_created:
        return 0

    count = 0
    for pattern in ("active", "completed"):
        for path in _glob.glob(str(root_path / ".tasks" / pattern / "T-*.md")):
            try:
                text = open(path, encoding="utf-8", errors="ignore").read()
            except OSError:
                continue
            rel = re.search(r"^related_tasks:.*$", text, re.M)
            if not rel or task_id not in rel.group(0):
                continue
            created = re.search(r"^created:\s*'?(\S{10})", text, re.M)
            if not created or created.group(1) < subject_created:
                continue
            name = re.search(r"^name:\s*(.*)$", text, re.M)
            tags = re.search(r"^tags:\s*(.*)$", text, re.M)
            haystack = (name.group(1) if name else "") + " " + (tags.group(1) if tags else "")
            if _BUG_RE.search(haystack):
                count += 1
    return count


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
        # T-3497: derived rather than left empty. An explicit `quality` argument
        # still wins, so a caller with better information is not overridden.
        "quality": quality if quality is not None else quality_for_task(task_id, root=root),
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
