"""T-3488 — the quadrant value-axis defect in the resolver's SELECTION path.

Sibling to `test_bvp_quadrant_value_axis.py` (T-3485), which repaired
`lib/bvp.sh`. That fix governs what `fw bvp rank` *prints*.
`lib/resolver.py:_annotate_bvp_rank()` is an independent, docstring-acknowledged
duplicate ("mirroring bvp.sh cmd_rank") of the same defect, and it is the
function that orders `fw resolver dispatch`'s autonomous picks — so this copy
steers behaviour, not display.

Every assertion here is made on the **selection order** (`_pick_rank_key`), not
on a rendered quadrant string. A task can be relabelled and still be picked
first; only the sort proves the defect is gone.

Three properties under test:

1. **Reproduction, then exclusion.** The pre-fix rule is re-implemented in this
   file (`_prefix_quadrant`) and run against the same fixture, so the defect is
   demonstrated rather than asserted from a report.
2. **Admission.** A genuinely high-value task must still be selected. Withholding
   that also suppressed real signal would be a worse defect than the one fixed.
3. **The ceiling control — the leg that stops this guard being "generalised" into
   a regression.** See `test_a_ceiling_collapse_is_deliberately_NOT_withheld`.

No live corpus state and no live policy weights are read (T-3326): weights are
pinned and every corpus here is constructed.
"""

import sys
from pathlib import Path

import pytest

FRAMEWORK_ROOT = Path(__file__).resolve().parents[2]
# lib/ on the path, not the repo root: resolver.py imports its siblings flat
# (`import keylock`), matching tests/unit/test_resolver.py.
sys.path.insert(0, str(FRAMEWORK_ROOT / "lib"))
import resolver as R  # noqa: E402

#: The four constitutional directive weights, pinned rather than loaded from
#: policy/value-drivers.yaml — a fixture that moves when policy is retuned tests
#: the policy, not the classifier.
WEIGHTS = {"D1": 9, "D2": 7, "D3": 5, "D4": 3}


def meta(tid, *, scores, br, tier=2, effort=8, status="captured", horizon="now"):
    """A resolver meta carrying REAL frontmatter, so the production scoring path
    (`_bvp_value_cost` → `_bvp_norm` / `_bvp_cost`) is exercised, not bypassed."""
    return {
        "id": tid,
        "status": status,
        "horizon": horizon,
        "fm": {
            "bvp_scores": dict(scores),
            "cost_estimate": {"blast_radius": br, "tier": tier, "effort": effort},
        },
    }


def flat(n):
    return {"D1": n, "D2": n, "D3": n, "D4": n}


@pytest.fixture(autouse=True)
def pinned_weights(monkeypatch):
    monkeypatch.setattr(R, "_bvp_driver_weights", lambda: dict(WEIGHTS))


def annotate(metas):
    R._annotate_bvp_rank(metas)
    return metas


def selection_order(metas):
    """The ids in the order `fw resolver dispatch` would consider them."""
    return [m["id"] for m in sorted(metas, key=R._pick_rank_key)]


def _prefix_quadrant(norm, cost, bvp_median, cost_median):
    """The PRE-FIX rule, verbatim: `>=` on the value axis with no degeneracy
    guard. Kept here so the defect is reproduced against the same fixture rather
    than taken on trust from a prior worker's report."""
    return ("hv" if norm >= bvp_median else "lv") + "-" + ("lc" if cost <= cost_median else "hc")


def _prefix_order(metas):
    """Selection order under pre-fix semantics, computed independently of
    lib/resolver.py's current code."""
    import statistics

    scored = []
    for m in metas:
        norm, cost = R._bvp_value_cost(m["fm"], dict(WEIGHTS))
        scored.append((m, norm, cost))
    norms = [n for _, n, _ in scored]
    costs = [c for _, _, c in scored if c is not None]
    bvp_median = statistics.median(norms)
    cost_median = statistics.median(costs)
    shadow = []
    for m, norm, cost in scored:
        quad = _prefix_quadrant(norm, cost, bvp_median, cost_median)
        shadow.append({**m, "_quadrant": quad,
                       "_quadrant_rank": R._QUADRANT_RANK[quad],
                       "bvp_norm": norm, "bvp_cost": cost})
    return [m["id"] for m in sorted(shadow, key=R._pick_rank_key)], shadow


# ── the degenerate (floor-collapse) fixture ─────────────────────────────────
#
# 13 tasks scoring all-zero at LOW cost, plus one genuinely top-value task at
# HIGH cost. Cost is what makes the defect bite: pre-fix the zeros land `hv-lc`
# (rank 0) and the real work lands `hv-hc` (rank 1), so zero-value work is
# selected ahead of it.

def degenerate_corpus():
    zeros = [meta(f"T-{100 + i}", scores=flat(0), br=1) for i in range(13)]
    real = meta("T-200", scores=flat(5), br=9)
    return zeros + [real]


# ── 1. reproduction ─────────────────────────────────────────────────────────

def test_PRE_FIX_semantics_select_a_zero_value_task_first():
    """The defect, demonstrated. Not a claim about history — the old rule is
    re-run here against the fixture the fix is tested on."""
    order, shadow = _prefix_order(degenerate_corpus())
    assert order[0] != "T-200", "fixture does not reproduce the defect"
    assert order[0].startswith("T-1"), order[:3]
    zero_quads = {m["_quadrant"] for m in shadow if m["id"] != "T-200"}
    assert zero_quads == {"hv-lc"}, (
        f"pre-fix, every zero-value task should read hv-lc; got {zero_quads}")


# ── 2. exclusion + admission, on one fixture ────────────────────────────────

def test_a_floor_tied_task_is_no_longer_selected_first():
    """Negative control (exclusion)."""
    order = selection_order(annotate(degenerate_corpus()))
    assert order[0] == "T-200", (
        f"a floor-tied zero-value task is still picked first: {order[:3]}")


def test_a_genuinely_high_value_task_is_still_selected():
    """Negative control (admission). Withholding that also suppressed real
    signal would be a worse defect than the one being fixed."""
    metas = annotate(degenerate_corpus())
    real = next(m for m in metas if m["id"] == "T-200")
    assert real["_quadrant"] == "hv-hc"
    assert real["_quadrant_rank"] == R._QUADRANT_RANK["hv-hc"]


def test_withheld_tasks_report_v_thin_and_rank_as_no_bvp():
    """AC: the withheld task's behaviour under dispatch is deliberate.

    It ranks with the no-BVP bucket — fall back to FIFO — while `_quadrant`
    still says `v-thin`, so 'no signal' and 'signal that cannot discriminate'
    stay distinguishable in `fw resolver explain`.
    """
    metas = annotate(degenerate_corpus())
    withheld = [m for m in metas if m["_quadrant"] == R.QUAD_VALUE_WITHHELD]
    assert len(withheld) == 13
    assert all(m["_quadrant_rank"] == R._NO_BVP_RANK for m in withheld)
    assert R.QUAD_VALUE_WITHHELD not in R._QUADRANT_RANK, (
        "the withheld verdict must not become a fifth ranked quadrant")


def test_withheld_still_carries_its_value_and_cost_for_observability():
    """Withholding a VERDICT must not erase the MEASUREMENT. `fw resolver
    explain` has to be able to show why the verdict was withheld."""
    metas = annotate(degenerate_corpus())
    w = next(m for m in metas if m["_quadrant"] == R.QUAD_VALUE_WITHHELD)
    assert w["bvp_norm"] == 0.0
    assert w["bvp_cost"] is not None
    assert R._bvp_summary(w)["quadrant"] == R.QUAD_VALUE_WITHHELD


# ── 3. THE CEILING CONTROL ──────────────────────────────────────────────────

def test_a_ceiling_collapse_is_deliberately_NOT_withheld():
    """The leg that stops a future 'generalisation' from becoming a regression.

    Measured on this repo 2026-09-26: 24 of 29 costed tasks (83%) tie at
    NORM 0.40, which is simultaneously the median AND the maximum. That looks
    like the same defect and is not:

      - tied at the FLOOR → the mass is the worst work, `>=` calls it `hv`;
        the verdict contradicts the data. Harmful — guarded.
      - tied at the CEILING → the mass is the best work, `>=` calls it `hv`;
        the verdict agrees with the data. Coarse, not wrong.

    Widening the guard to "a large mass ties at the median" would push the top
    24 behind the corpus's five lowest scorers. A ceiling collapse is a
    degenerate SCORER (lib/bvp_degenerate.py, T-3489/T-3495), not a classifier
    defect, and belongs in that detector.
    """
    top = [meta(f"T-{300 + i}", scores=flat(5), br=1) for i in range(24)]
    low = [meta(f"T-{400 + i}", scores=flat(j), br=1)
           for i, j in enumerate((1, 1, 2, 2, 3))]
    metas = annotate(top + low)

    norms = [m["bvp_norm"] for m in metas]
    import statistics
    assert statistics.median(norms) == max(norms), "fixture is not ceiling-collapsed"
    assert statistics.median(norms) != min(norms), "fixture must NOT be floor-collapsed"

    assert not any(m["_quadrant"] == R.QUAD_VALUE_WITHHELD for m in metas), (
        "the guard fired on a ceiling collapse — it has been over-generalised, "
        "and top-value work is now ranked behind the lowest scorers")
    assert all(m["_quadrant"].startswith("hv") for m in top)


def test_the_degeneracy_predicate_keys_on_the_floor_not_on_tie_size():
    """Pins the predicate directly, so the intent survives a refactor."""
    assert R._value_axis_degenerate([0.0] * 13 + [0.5] * 12) is True
    assert R._value_axis_degenerate([0.4] * 24 + [0.1, 0.2]) is False
    assert R._value_axis_degenerate([0.1, 0.2, 0.2, 0.4]) is False
    assert R._value_axis_degenerate([]) is False


# ── 4. regression control on a healthy corpus ───────────────────────────────

def test_a_healthy_spread_corpus_is_byte_identical_to_pre_fix():
    """The control that gives the others meaning.

    A guard that changed a well-spread corpus would be a behaviour change
    dressed as a bug fix. Compared against the independently-computed pre-fix
    rule, not against a remembered expectation.
    """
    healthy = [meta(f"T-{500 + i}", scores=flat(n), br=br)
               for i, (n, br) in enumerate(((1, 1), (2, 3), (3, 5), (4, 7), (5, 9)))]

    prefix_ids, shadow = _prefix_order([dict(m) for m in healthy])
    live = annotate(healthy)

    assert selection_order(live) == prefix_ids
    assert ([m["_quadrant"] for m in sorted(live, key=lambda x: x["id"])]
            == [m["_quadrant"] for m in sorted(shadow, key=lambda x: x["id"])])
    assert not any(m["_quadrant"] == R.QUAD_VALUE_WITHHELD for m in live)


def test_the_guard_is_inert_when_ranking_is_disabled(monkeypatch):
    """FW_RESOLVER_BVP_RANK=0 must still short-circuit to pure FIFO."""
    monkeypatch.setenv("FW_RESOLVER_BVP_RANK", "0")
    metas = annotate(degenerate_corpus())
    assert all(m["_quadrant"] == "-" for m in metas)
    assert all(m["_quadrant_rank"] == R._NO_BVP_RANK for m in metas)


# ── 5. the fence: T-3485's surface is untouched ─────────────────────────────

def test_the_two_surfaces_report_the_same_withheld_literal():
    """Two copies of one rule is the standing fault; matching the reported
    string is the floor, not the fix (T-3488 `## Decisions`)."""
    bvp_sh = (FRAMEWORK_ROOT / "lib" / "bvp.sh").read_text(encoding="utf-8")
    assert f"QUAD_VALUE_WITHHELD = '{R.QUAD_VALUE_WITHHELD}'" in bvp_sh
