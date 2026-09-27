#!/usr/bin/env python3
"""judge_verdict.py — the shared contract both judge agents obey (T-3525).

T-3524 GO, decision D-662. Operator ruling 2026-09-27:

    "Yes, a judge can refuse. If it's not green, then it's amber or red. The
     [producer] needs to adjust, but the reviewer also needs to give guidance on
     what to do."

    "We don't need to rescore anything that's already done, that's closed. We can
     rescore things that are still outstanding, of course. That are still open, that
     are still on the horizon."

This module exists as its own task, ahead of the judges that use it, for one reason:
arc membership in this repo reached FIVE implementations of one predicate that
disagreed three ways, and a full day went into consolidating them. Two judge agents
each carrying their own idea of what amber means is that defect pre-ordered.

── THE GUIDANCE IS THE DELIVERABLE, NOT THE COLOUR ─────────────────────────────

`verdict()` RAISES when a non-green verdict carries no guidance. Not a warning, not a
lint — it cannot be constructed. The reason is measured: `[REVIEWER]` criteria, which
produce a verdict with nothing to act on, reached 7 uses against 412 for `[REVIEW]`
(T-1878). A colour with no instruction gets routed around, and the routing looks like
compliance. If guidance is optional it becomes absent.

── AMBER MUST DIFFER IN BEHAVIOUR, NOT ONLY IN NAME ────────────────────────────

A third state that nothing can act on differently is decoration. So the contract says
what each means to a caller:

    green  — proceed; nothing owed
    amber  — proceed, AND record the guidance against the thing judged
    red    — do not proceed

`may_proceed()` is the single place that distinction lives, so no caller re-derives it
and no caller can accidentally read amber as a pass with `if verdict:`.

── UNKNOWN IS NOT GREEN ────────────────────────────────────────────────────────

A judge that cannot reach a conclusion emits UNKNOWN, which is not green and does not
permit proceeding. This session hit the opposite default four separate times — an
absent blast_radius scoring cheapest (T-3068), a result line read as completion
(OBS-557), a missing digest read as protection (T-3523), and a tooling failure read as
a quality verdict (OBS-559). Every one of them made "I could not tell" indistinguishable
from "I checked and it was fine".

UNKNOWN also requires guidance, because "I could not judge this" is only actionable if
it says what would make judgement possible.
"""

from __future__ import annotations

from datetime import datetime, timezone

GREEN = "green"
AMBER = "amber"
RED = "red"
UNKNOWN = "unknown"

#: Every legal state. Deliberately not a bool anywhere in this module.
STATES = (GREEN, AMBER, RED, UNKNOWN)

#: States that require the judge to say what to do about them.
_REQUIRES_GUIDANCE = (AMBER, RED, UNKNOWN)

#: What each state means to a caller. Prose, but load-bearing prose — a judge agent's
#: AGENT.md quotes it, and `explain()` returns it so two agents cannot paraphrase it
#: into two different meanings.
MEANING = {
    GREEN: "proceed; nothing owed",
    AMBER: "proceed, and record the guidance against the thing judged",
    RED: "do not proceed",
    UNKNOWN: "do not proceed; the judge could not reach a conclusion",
}

#: Closed work is never reviewable. The operator's ruling, and it also protects the
#: record: a closed task's score is what was decided at the time.
_CLOSED_STATUSES = {"work-completed"}


class VerdictError(ValueError):
    """Raised when a verdict would be constructible but meaningless."""


def _utc_now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def verdict(state: str, guidance: str = "", *, judged: str = "",
            judge: str = "", evidence=None) -> dict:
    """Build a verdict record, or refuse to.

    Refuses when:
      * `state` is not one of STATES — a typo'd state must not become a fourth
        silent meaning;
      * `state` is non-green and `guidance` is empty or whitespace. This is the
        contract's whole point.

    `evidence` is an optional list of strings a reader can chase. It is NOT a
    substitute for guidance: evidence says what the judge saw, guidance says what to
    do about it, and a caller can act on only one of those.
    """
    st = (state or "").strip().lower()
    if st not in STATES:
        raise VerdictError(
            f"unknown verdict state {state!r}; legal states are {', '.join(STATES)}. "
            "A fourth state must be added to this contract deliberately, not by typo.")
    g = (guidance or "").strip()
    if st in _REQUIRES_GUIDANCE and not g:
        raise VerdictError(
            f"a {st} verdict requires guidance on what to do. "
            "Operator ruling D-662: the reviewer must say what to do, and the guidance "
            "is the deliverable rather than the colour. A verdict with nothing to act "
            "on gets routed around — measured: [REVIEWER] reached 7 uses against 412 "
            "for [REVIEW] (T-1878).")
    return {
        "state": st,
        "meaning": MEANING[st],
        "guidance": g,
        "judged": judged,
        "judge": judge,
        "evidence": list(evidence or []),
        "ts": _utc_now(),
        "contract": "judge_verdict/1",
    }


def may_proceed(v) -> bool:
    """The ONE place the amber/red distinction lives.

    Callers must not re-derive this. `if verdict:` on the record would be truthy for
    every state including red, which is precisely the coercion the three-state ruling
    exists to prevent — so the boolean is produced here, from the state, once.
    """
    st = v.get("state") if isinstance(v, dict) else str(v).strip().lower()
    return st in (GREEN, AMBER)


def requires_guidance(state: str) -> bool:
    return (state or "").strip().lower() in _REQUIRES_GUIDANCE


def explain(state: str) -> str:
    st = (state or "").strip().lower()
    if st not in MEANING:
        raise VerdictError(f"unknown verdict state {state!r}")
    return MEANING[st]


def reviewable(frontmatter, *, require_horizon: bool = False) -> tuple[bool, str]:
    """Is this task in the population a judge may review?

    Operator ruling: open work only. Returns (bool, reason) so a caller can report
    WHY it skipped something, rather than skipping silently — the same denominator
    discipline as L-575.

    `require_horizon` narrows further to tasks that carry a horizon, which is the
    operator's "still on the horizon" phrasing. Off by default because a task with no
    horizon field is still open, and treating absence as exclusion would silently
    shrink the population — the error this session made four times in the other
    direction.
    """
    if not isinstance(frontmatter, dict):
        return False, "no frontmatter to judge"
    status = str(frontmatter.get("status") or "").strip().lower()
    if not status:
        return False, "no status field — cannot establish that this is open work"
    if status in _CLOSED_STATUSES:
        return False, (f"status {status!r} is closed; closed work is never rescored "
                       "(D-662) — its score is the record of what was decided then")
    if require_horizon and not str(frontmatter.get("horizon") or "").strip():
        return False, "no horizon set and require_horizon was requested"
    return True, f"status {status!r} is open"


def format_verdict(v) -> str:
    """Human-readable rendering. Guidance is never omitted when present."""
    st = v.get("state", "?")
    head = f"{st.upper()}"
    if v.get("judged"):
        head += f"  {v['judged']}"
    lines = [f"{head}   ({v.get('meaning', '')})"]
    if v.get("guidance"):
        lines.append(f"  guidance: {v['guidance']}")
    for e in (v.get("evidence") or []):
        lines.append(f"  evidence: {e}")
    return "\n".join(lines)
