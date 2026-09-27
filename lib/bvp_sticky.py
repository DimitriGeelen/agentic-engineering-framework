#!/usr/bin/env python3
"""bvp_sticky.py — an operator's adjustment survives the next scoring run (T-3523).

Operator ruling 2026-09-27 (D-661), leg 3 of 3, verbatim: *"we still add an override
flag that [the operator] can adjust, and when we get new scoring that it doesn't
overwrite the adjusted values."* Asked how they wanted to mark it: *"one simple flag
like checkbox would be easiest I guess. Or automatically when I overwrite you see it.
Correct?"* — and on behaviour: *"means skip and report indeed."* And on scope: *"it
also covers ArcScope drivers, absolutely."*

Answer: both, automatically, nothing to tick.

── WHY THIS EXISTS AT ALL ──────────────────────────────────────────────────────

Legs 1 and 2 of the same ruling waive human approval for BVP scoring and for arc
drivers, and both were ALREADY live when the ruling landed (lib/bvp.sh:1027 via
T-3487; lib/arc.sh:1429 via T-3429/D-586). So an agent can score the value of its own
work and let that score select its own next work — a deliberate waiver of
producer-not-judge on the scoring axis, which the operator has authority to make and
did make.

This module is the counterweight that keeps that waiver reversible. Without it the
operator can correct a score, and the next estimator run silently puts it back; being
in the loop would require being in the path. With it, a correction sticks.

── THE TWO ROUTES ──────────────────────────────────────────────────────────────

1. PROVENANCE. `confirmed_via` already records which door a score came through
   (`agent` | `human` | `watchtower`, T-3487). `human` and `watchtower` are the
   operator's doors. This is the "checkbox", except the operator never ticks it —
   it is set by how they acted.

2. DIGEST. Every agent write stamps a digest of the values it wrote. If the values no
   longer match the stamp, something changed them outside the verb — a hand-edit.
   Same shape as T-1985's reviewer auto-tick sovereignty rail, where a human
   un-ticking an AC blocks re-ticking until the AC text itself changes.

Either route marks a value STICKY. A sticky value is skipped and reported, never
overwritten and never silently diverged from.

── THE ASYMMETRY THAT MATTERS ──────────────────────────────────────────────────

A MISSING stamp does NOT mean sticky. Every score in the corpus predates this field;
if absence meant protected, the first run would refuse the whole corpus and the
feature would present as broken. Absence means unprotected — overwritable, exactly as
before.

This is the one place in this codebase where absence points toward the permissive
answer rather than the cautious one, and it is deliberate: the cautious reading here
produces paralysis, not protection. Contrast T-3068's `blast_radius`, where absence
scored as the CHEAPEST value and therefore had to become None. The rule is not
"unknown is always None" — it is "unknown must never be silently favourable", and
here the favourable-to-the-agent reading is `sticky=False`, which is also the honest
one, because nothing was ever protected.
"""

from __future__ import annotations

import hashlib
import json

#: Doors that belong to the operator. `agent` is ours.
_OPERATOR_VIA = {"human", "watchtower", "operator"}


def values_digest(values) -> str:
    """Stable digest of a score map or driver-weight list.

    Sorted and JSON-normalised so key order and YAML round-tripping cannot produce a
    spurious mismatch — a false "operator touched this" would block legitimate
    re-scoring forever, which is the failure mode that would get this whole mechanism
    switched off.
    """
    if values is None:
        return ""
    if isinstance(values, dict):
        norm = {str(k): values[k] for k in sorted(values, key=str)}
    elif isinstance(values, list):
        norm = [
            {str(k): v[k] for k in sorted(v, key=str)} if isinstance(v, dict) else v
            for v in values
        ]
    else:
        norm = values
    blob = json.dumps(norm, sort_keys=True, separators=(",", ":"), default=str)
    return hashlib.sha256(blob.encode("utf-8")).hexdigest()[:16]


def sticky_state(values, confirmed_via=None, stamped_digest=None) -> dict:
    """Decide whether `values` are the operator's, and say which route decided it.

    Returns {"sticky": bool, "route": str, "reason": str}. `route` is one of
    "provenance", "digest", "none" — so a caller's report can name WHY it skipped,
    which is what makes the skip actionable rather than mysterious.
    """
    if values is None or (hasattr(values, "__len__") and len(values) == 0):
        return {"sticky": False, "route": "none", "reason": "no values to protect"}

    via = (str(confirmed_via).strip().lower() if confirmed_via else "")
    if via in _OPERATOR_VIA:
        return {"sticky": True, "route": "provenance",
                "reason": f"confirmed_via: {via} — set through the operator's own door"}

    if not stamped_digest:
        # Pre-existing value from before this mechanism. Unprotected, on purpose.
        return {"sticky": False, "route": "none",
                "reason": "no digest stamp (predates T-3523) — unprotected, not sticky"}

    current = values_digest(values)
    if current != stamped_digest:
        return {"sticky": True, "route": "digest",
                "reason": (f"values no longer match the digest written with them "
                           f"({stamped_digest} -> {current}) — edited outside the verb")}

    return {"sticky": False, "route": "none",
            "reason": "digest matches the last agent write — agent may update"}


def stamp(values) -> dict:
    """The provenance stamp an agent write records alongside its values."""
    return {"digest": values_digest(values), "by": "agent"}


def format_skip(subject: str, field: str, state: dict) -> str:
    """The skip line. Operator ruling: skip AND REPORT."""
    return (f"SKIPPED {subject} {field}: operator-adjusted, not overwritten "
            f"[{state['route']}] {state['reason']}")


def format_summary(skipped: int, written: int) -> str:
    """A run summary that reports the skips even when there are none.

    Printing nothing when skipped==0 would make "protected nothing" and "protected
    silently" look identical — the denominator rule from L-575.
    """
    return (f"bvp sticky: {written} value(s) written, {skipped} skipped as "
            f"operator-adjusted")
