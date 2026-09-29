"""Arc close-readiness: L1 + L2 + L3. T-3552 (T-3548 Slice A).

Operator ruling (2026-09-28), verbatim:

    "the threshold for Arc should not be 80%, it should be no high value, low
     cost, no high cost items left anymore" … "no unestimated tasks, point. And
     then no high value, no Q1, Q1 and Q2, quadrant 1 and quadrant 2 tasks left.
     And then we also talked about validating if the R goals are achieved."

    L1  no unestimated open member — every one carries a value AND a cost
    L2  no open member is high value — neither hv-lc (Q1) nor hv-hc (Q2) remains
    L3  the arc's goals are validated in the anchor's Recommendation + Rationale

WHAT THE 80% RATIO MEASURED
---------------------------
`completed / total` over constituents. That answers "how much of the list is
ticked", which is a property of the list, not of the work. An arc at 85% whose
remaining 15% is its entire high-value core surfaces as close-ready; an arc at 70%
whose remainder is all low-value polish does not. Both backwards, and neither
visible, because a ratio cannot say what kind of thing is left.

L1+L2 ask about the remainder instead: closure is a claim about what is LEFT, and
value is what decides whether leftovers matter.

THIS IS A SURFACING PREDICATE, NOT A GATE
-----------------------------------------
Nothing here permits a closure. `lib/arc.sh:arc_close()` has no ratio check and
gains none; `fw arc close` stays agent-refused under $CLAUDECODE (T-1671) and
operator-owned. What changes is which arcs the operator is shown, and what they
are told about why.

THE POPULATION IS NOT `fw bvp`'s, AND THAT IS DELIBERATE
--------------------------------------------------------
The quadrant FUNCTION is imported from `lib/bvp.sh` (via `bvp_py`), never
re-derived — one classifier, one implementation. But the POPULATION the medians
are computed over is different, and pretending otherwise would be the real defect:

    fw bvp        ranks "what should I work on next", and therefore EXCLUDES
                  work-completed (T-2223).
    this module   asks "what is LEFT in this arc", and therefore INCLUDES
                  work-completed tasks that are still in .tasks/active/ —
                  partial-complete, awaiting Human-criterion verification.

That is not a detail. 134 of 152 open arc members are partial-complete; on
`fw bvp`'s population they would have no quadrant at all, and L2 would pass every
arc by never looking at the tasks that make it up. Two populations, one honest
reason each, both named. A caller comparing this module's verdict against a
`fw bvp --quadrant hv-lc` listing will see differences, and they are these.

L3 IS SUPPLIED, NOT READ
------------------------
The anchor Recommendation lives behind a web blueprint helper
(`_anchor_recommendation`). Importing a blueprint into lib/ would invert the
dependency and drag Flask into `fw review-queue`, so the caller passes what it
already has. The leg is still evaluated here, so every surface applies the same
rule to it.
"""

from __future__ import annotations

import glob
import statistics
import sys
from pathlib import Path

_LIB = Path(__file__).resolve().parent
if str(_LIB) not in sys.path:
    sys.path.insert(0, str(_LIB))

import bvp_py  # noqa: E402

HIGH_VALUE_QUADRANTS = ("hv-lc", "hv-hc")  # Q1 and Q2, the operator's terms


class Leg:
    """One leg's verdict. `offenders` is what makes a failure actionable.

    A leg that reports only pass/fail sends the operator to count tasks by hand,
    which is how a predicate gets ignored in favour of the ratio it replaced.
    """

    __slots__ = ("name", "passed", "summary", "offenders")

    def __init__(self, name: str, passed: bool, summary: str, offenders=None):
        self.name = name
        self.passed = passed
        self.summary = summary
        self.offenders = list(offenders or [])

    def as_dict(self) -> dict:
        return {
            "name": self.name,
            "passed": self.passed,
            "summary": self.summary,
            "offenders": self.offenders,
        }

    def __repr__(self):  # pragma: no cover - debugging aid
        return f"<Leg {self.name} {'PASS' if self.passed else 'FAIL'}: {self.summary}>"


def _latest_proposed(fm: dict, key: str):
    """Newest entry from a `*_proposed:` list, or None."""
    proposed = fm.get(key)
    if not isinstance(proposed, list) or not proposed:
        return None
    last = proposed[-1]
    return last if isinstance(last, dict) else None


def task_value(fm: dict, weights: dict, bvp):
    """(norm, source) or (None, reason) — confirmed scores outrank proposed."""
    scores = fm.get("bvp_scores") or {}
    source = "confirmed"
    if not scores:
        latest = _latest_proposed(fm, "bvp_scores_proposed")
        scores = (latest or {}).get("bvp_scores") or (latest or {}).get("scores") or {}
        source = "proposed"
    if not scores:
        return None, "no-value-score"
    _raw, norm, used = bvp.compute_bvp(scores, weights)
    if not used:
        return None, "no-overlapping-drivers"
    return norm, source


def task_cost(fm: dict, bvp):
    """(composite, source) or (None, reason) — confirmed outranks proposed."""
    ce = fm.get("cost_estimate")
    source = "confirmed"
    if not ce:
        latest = _latest_proposed(fm, "cost_estimate_proposed")
        ce = (latest or {}).get("cost_estimate")
        source = "proposed"
    composite, _br, _tier, _eff, kind = bvp.compute_cost(ce or {})
    if composite is None:
        return None, "no-cost" if kind == "absent" else kind
    return composite, source


def corpus_medians(project_root: Path | str, *, framework_root=None,
                   parse_frontmatter=None) -> dict:
    """Value and cost medians over OPEN tasks — everything in .tasks/active/.

    See the module docstring: this population deliberately differs from
    `fw bvp`'s. Returns the medians plus `value_degenerate`, T-3485's guard for
    a median that has collapsed onto the corpus floor and therefore cannot
    separate anything.
    """
    bvp = bvp_py.load(framework_root)
    policy = bvp.load_policy()
    weights = bvp.driver_weights(policy)

    vals, costs = [], []
    for p in glob.glob(str(Path(project_root) / ".tasks" / "active" / "T-*.md")):
        fm = _read_fm(p, parse_frontmatter)
        if not fm:
            continue
        v, _ = task_value(fm, weights, bvp)
        if v is not None:
            vals.append(v)
        c, _ = task_cost(fm, bvp)
        if c is not None:
            costs.append(c)

    return {
        "weights": weights,
        "value_median": statistics.median(vals) if vals else None,
        "cost_median": statistics.median(costs) if costs else None,
        "value_degenerate": bvp.value_axis_degenerate(vals) if vals else False,
        "n_value": len(vals),
        "n_cost": len(costs),
    }


def _read_fm(path, parse_frontmatter=None) -> dict:
    """Frontmatter for one task. Callers with a cache pass their own parser."""
    try:
        text = Path(path).read_text(encoding="utf-8", errors="replace")
    except OSError:
        return {}
    if parse_frontmatter is not None:
        fm, _body = parse_frontmatter(text)
        return fm or {}
    import yaml
    if not text.startswith("---"):
        return {}
    end = text.find("\n---", 3)
    if end == -1:
        return {}
    try:
        return yaml.safe_load(text[3:end]) or {}
    except yaml.YAMLError:
        return {}


def evaluate(open_members: list[tuple[str, dict]], medians: dict,
             recommendation: dict | None = None, *, framework_root=None) -> dict:
    """Evaluate L1, L2, L3 for one arc.

    `open_members` — (task_id, frontmatter) for members still in .tasks/active/.
    CLOSED members are not passed and never block a leg: closure is a claim about
    what is left, not a re-litigation of what was done.

    `recommendation` — {'present': bool, 'verdict': str, 'has_rationale': bool},
    supplied by the caller (see module docstring).
    """
    bvp = bvp_py.load(framework_root)
    weights = medians.get("weights") or {}
    vmed = medians.get("value_median")
    cmed = medians.get("cost_median")
    degenerate = bool(medians.get("value_degenerate"))

    # ── L1 ──────────────────────────────────────────────────────────────────
    unestimated = []
    scored: list[tuple[str, float, float]] = []
    for tid, fm in open_members:
        v, vreason = task_value(fm, weights, bvp)
        c, creason = task_cost(fm, bvp)
        missing = []
        if v is None:
            missing.append(vreason)
        if c is None:
            missing.append(creason)
        if missing:
            unestimated.append(f"{tid} ({', '.join(missing)})")
        else:
            scored.append((tid, v, c))

    if not open_members:
        l1 = Leg("L1", True, "no open members — nothing left to estimate")
    elif unestimated:
        l1 = Leg("L1", False,
                 f"{len(unestimated)} of {len(open_members)} open member(s) unestimated",
                 unestimated)
    else:
        l1 = Leg("L1", True,
                 f"all {len(open_members)} open member(s) carry a value and a cost")

    # ── L2 ──────────────────────────────────────────────────────────────────
    # Evaluated only over members that HAVE both axes. An unestimated task is not
    # evidence of absence of high-value work — that is exactly what L1 refuses
    # for, and letting L2 pass on an unmeasured remainder would let an arc close
    # on the strength of not having looked.
    if vmed is None or cmed is None:
        l2 = Leg("L2", False,
                 "no corpus median available — the quadrant split cannot be computed, "
                 "so 'no high-value work remains' is unproven, not true")
    elif not scored:
        l2 = Leg("L2", True, "no estimated open members remain") if not open_members else \
             Leg("L2", False,
                 "no open member could be classified — L1 names why; L2 cannot pass "
                 "on an unmeasured remainder")
    else:
        high = []
        for tid, v, c in scored:
            q = bvp.quadrant(v, c, vmed, cmed, degenerate)
            if q in HIGH_VALUE_QUADRANTS:
                high.append(f"{tid} ({q})")
        if high:
            l2 = Leg("L2", False,
                     f"{len(high)} high-value open member(s) remain (Q1/Q2)", high)
        else:
            l2 = Leg("L2", True,
                     f"no high-value work left — {len(scored)} open member(s) all below "
                     "the value median or low-value")

    # ── L3 ──────────────────────────────────────────────────────────────────
    rec = recommendation or {}
    if not rec.get("present"):
        l3 = Leg("L3", False,
                 "the anchor carries no `## Recommendation` — there is no advisory "
                 "stating whether the arc's goals were achieved")
    elif not str(rec.get("verdict") or "").strip():
        l3 = Leg("L3", False, "the anchor Recommendation carries no verdict")
    elif not rec.get("has_rationale", True):
        l3 = Leg("L3", False,
                 "the anchor Recommendation has a verdict but no rationale — the "
                 "goals-achieved claim is asserted, not argued")
    else:
        l3 = Leg("L3", True, f"anchor advisory present: {rec.get('verdict')}")

    return {
        "l1": l1.as_dict(),
        "l2": l2.as_dict(),
        "l3": l3.as_dict(),
        "ready": l1.passed and l2.passed and l3.passed,
        "open_members": len(open_members),
    }
