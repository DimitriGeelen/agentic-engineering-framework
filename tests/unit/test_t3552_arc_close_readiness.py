"""T-3552 (T-3548 Slice A): arc close-readiness is quadrant exhaustion, not a ratio.

The 80% threshold measured `completed / total` — a property of the LIST, not of
the work. Measured on this corpus at the swap: the ratio surfaced 8 arcs as
close-ready, and 6 of them still had high-value open members. `orchestrator-rethink`
read close-ready at 85% with 18 open members, 8 of them Q1/Q2.

L1 (nothing unestimated) + L2 (no Q1/Q2 left) ask about the remainder instead.

THE CONTROLS ARE LOAD-BEARING, IN BOTH DIRECTIONS:

  * `test_control_low_value_fully_estimated_arc_passes` — without it, a build that
    fails every arc satisfies every other assertion here. A predicate that always
    says no is exactly as uninformative as one that always says yes, and this repo
    shipped the first kind for an hour this morning (L1 refused all 16 arcs until
    T-3551 made cost derivable).
  * `test_one_unestimated_member_fails_l1_even_when_l2_would_pass` — a pass must
    not be reachable by ignoring a leg.
"""

import sys
from pathlib import Path

FW_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(FW_ROOT / "lib"))
sys.path.insert(0, str(FW_ROOT))

import arc_close_readiness as acr  # noqa: E402

GOOD_REC = {"present": True, "verdict": "GO", "has_rationale": True}

# A corpus split placing the medians in the middle of the fixtures below, so
# high/low is unambiguous and no assertion depends on a tie.
MEDIANS = {
    "weights": {"D1": 5, "D2": 4, "D3": 3, "D4": 2},
    "value_median": 0.40,
    "cost_median": 4.0,
    "value_degenerate": False,
    "n_value": 100,
    "n_cost": 100,
}


def _fm(value=None, cost=None, *, proposed=False):
    """Frontmatter carrying a value score and/or a cost, confirmed or proposed.

    `value` is a per-driver score 0-5 applied to all four drivers, which with the
    weights above yields norm == value/5 — so a value of 1 is norm 0.20 (below the
    0.40 median) and 4 is norm 0.80 (above).
    """
    fm: dict = {}
    if value is not None:
        scores = {"D1": value, "D2": value, "D3": value, "D4": value}
        if proposed:
            fm["bvp_scores_proposed"] = [{"ts": "2026-01-01T00:00:00Z", "bvp_scores": scores}]
        else:
            fm["bvp_scores"] = scores
    if cost is not None:
        ce = {"blast_radius": cost, "tier": cost, "effort": cost}
        if proposed:
            fm["cost_estimate_proposed"] = [{"ts": "2026-01-01T00:00:00Z", "cost_estimate": ce}]
        else:
            fm["cost_estimate"] = ce
    return fm


# ───────────────────────────────── L1 ────────────────────────────────────────


def test_l1_passes_when_every_open_member_has_value_and_cost():
    members = [("T-1", _fm(1, 2)), ("T-2", _fm(1, 2))]
    r = acr.evaluate(members, MEDIANS, GOOD_REC)
    assert r["l1"]["passed"], r["l1"]["summary"]


def test_l1_fails_and_names_a_member_missing_cost():
    members = [("T-1", _fm(1, 2)), ("T-2", _fm(1, None))]
    r = acr.evaluate(members, MEDIANS, GOOD_REC)
    assert not r["l1"]["passed"]
    assert any("T-2" in o for o in r["l1"]["offenders"]), r["l1"]["offenders"]
    # naming WHICH axis is missing is what makes the failure actionable
    assert any("no-cost" in o for o in r["l1"]["offenders"])


def test_l1_fails_and_names_a_member_missing_value():
    members = [("T-9", _fm(None, 2))]
    r = acr.evaluate(members, MEDIANS, GOOD_REC)
    assert not r["l1"]["passed"]
    assert any("T-9" in o and "no-value-score" in o for o in r["l1"]["offenders"])


def test_proposed_scores_satisfy_l1():
    """Confirmed scores are 0 corpus-wide; requiring them would make L1 unpassable."""
    members = [("T-1", _fm(1, 2, proposed=True))]
    r = acr.evaluate(members, MEDIANS, GOOD_REC)
    assert r["l1"]["passed"], r["l1"]["summary"]


# ───────────────────────────────── L2 ────────────────────────────────────────


def test_l2_fails_on_a_high_value_low_cost_member_q1():
    members = [("T-1", _fm(4, 1))]  # norm 0.80 > 0.40, cost 1.0 < 4.0
    r = acr.evaluate(members, MEDIANS, GOOD_REC)
    assert not r["l2"]["passed"]
    assert any("hv-lc" in o for o in r["l2"]["offenders"]), r["l2"]["offenders"]


def test_l2_fails_on_a_high_value_high_cost_member_q2():
    members = [("T-1", _fm(4, 8))]
    r = acr.evaluate(members, MEDIANS, GOOD_REC)
    assert not r["l2"]["passed"]
    assert any("hv-hc" in o for o in r["l2"]["offenders"]), r["l2"]["offenders"]


def test_control_low_value_fully_estimated_arc_passes():
    """CONTROL. Without this, 'fail everything' passes every other test here."""
    members = [("T-1", _fm(1, 1)), ("T-2", _fm(1, 8))]  # lv-lc and lv-hc
    r = acr.evaluate(members, MEDIANS, GOOD_REC)
    assert r["l1"]["passed"], r["l1"]["summary"]
    assert r["l2"]["passed"], r["l2"]["summary"]
    assert r["l3"]["passed"], r["l3"]["summary"]
    assert r["ready"] is True


def test_one_unestimated_member_fails_l1_even_when_l2_would_pass():
    """CONTROL. A pass must not be reachable by ignoring a leg.

    The estimated members are all low-value, so L2 has nothing to object to. L1
    must still refuse — an unmeasured task is not evidence that no high-value work
    remains, and letting the arc through here would close it on the strength of
    not having looked.
    """
    members = [("T-1", _fm(1, 1)), ("T-BLIND", _fm(None, None))]
    r = acr.evaluate(members, MEDIANS, GOOD_REC)
    assert not r["l1"]["passed"]
    assert r["ready"] is False


def test_l2_does_not_pass_when_nothing_could_be_classified():
    """An arc whose every open member is unestimated must not report 'no high-value
    work left'. That sentence would be true of the measurements and false of the
    arc."""
    members = [("T-A", _fm(None, None)), ("T-B", _fm(None, None))]
    r = acr.evaluate(members, MEDIANS, GOOD_REC)
    assert not r["l1"]["passed"]
    assert not r["l2"]["passed"], r["l2"]["summary"]


def test_missing_corpus_median_fails_l2_rather_than_passing_it():
    """No median = the split cannot be computed. 'Unproven' is not 'true'."""
    med = dict(MEDIANS, value_median=None, cost_median=None)
    r = acr.evaluate([("T-1", _fm(1, 1))], med, GOOD_REC)
    assert not r["l2"]["passed"]
    assert "unproven" in r["l2"]["summary"]


# ──────────────────────── closed members / empty arcs ────────────────────────


def test_an_arc_with_no_open_members_is_ready():
    """Closure is a claim about what is LEFT. Nothing left = nothing to object to.

    This is the shape of the two arcs the live corpus surfaces
    (onboarding-shape-detection 3/3, readme-first-run 2/2).
    """
    r = acr.evaluate([], MEDIANS, GOOD_REC)
    assert r["l1"]["passed"] and r["l2"]["passed"]
    assert r["ready"] is True


def test_closed_members_are_simply_not_passed_in():
    """The caller supplies OPEN members only; a completed high-value task cannot
    block its own arc forever."""
    open_only = [("T-1", _fm(1, 1))]
    r = acr.evaluate(open_only, MEDIANS, GOOD_REC)
    assert r["ready"] is True


# ───────────────────────────────── L3 ────────────────────────────────────────


def test_l3_fails_without_a_recommendation():
    r = acr.evaluate([("T-1", _fm(1, 1))], MEDIANS, {"present": False})
    assert not r["l3"]["passed"]
    assert r["ready"] is False


def test_l3_fails_on_a_verdict_with_no_rationale():
    r = acr.evaluate([("T-1", _fm(1, 1))], MEDIANS,
                     {"present": True, "verdict": "GO", "has_rationale": False})
    assert not r["l3"]["passed"]
    assert "asserted, not argued" in r["l3"]["summary"]


def test_l3_fails_on_an_empty_verdict():
    r = acr.evaluate([("T-1", _fm(1, 1))], MEDIANS,
                     {"present": True, "verdict": "", "has_rationale": True})
    assert not r["l3"]["passed"]


# ──────────────────── the classifier is imported, not copied ─────────────────


def test_quadrant_comes_from_bvp_sh_not_a_local_copy():
    """The whole reason `lib/bvp_py.py` exists.

    Arc membership reached five readers and three disagreeing verdicts (OBS-546)
    by exactly this route. If someone re-implements the quadrant here, this fails.
    """
    import bvp_py
    mod = bvp_py.load()
    assert callable(mod.quadrant)
    src = (FW_ROOT / "lib" / "arc_close_readiness.py").read_text()
    assert "def quadrant" not in src, "quadrant was re-implemented locally"
    assert "bvp.quadrant(" in src, "the imported classifier is not the one used"


def test_bvp_py_loader_raises_rather_than_exporting_an_empty_module():
    """A loader that degrades to 'no functions found' hands every caller a
    quadrant of None — the unmeasured-absence class, rebuilt one level down."""
    import bvp_py
    try:
        bvp_py._extract("no markers in here at all")
    except RuntimeError as e:
        assert "bvp.sh" in str(e)
    else:
        raise AssertionError("expected a RuntimeError naming the cause")


# ═══════════════════ L4: demo evidence (T-3553, Slice B) ═════════════════════
#
# L3 asks whether the anchor's Recommendation asserts the goals were met — prose,
# written by an agent. G-062 says that is not enough: the mandatory question is
# whether a captured artefact shows the headline_mechanic firing. L4 is that
# question, answered by `fw arc demo-check` (which reuses lib/arc.sh's validators
# rather than forming a second opinion).


def test_l4_control_valid_demo_passes_and_arc_is_ready():
    """CONTROL. Without it, 'fail every arc' satisfies every other L4 test —
    and 14 of 18 live arcs DO fail L4, which is the shape a broken check hides in."""
    r = acr.evaluate([("T-1", _fm(1, 1))], MEDIANS, GOOD_REC,
                     demo={"state": "valid", "detail": "docs/reports/x.md"})
    assert r["l4"]["passed"], r["l4"]["summary"]
    assert r["ready"] is True


def test_l4_absent_blocks_readiness_even_when_l1_l2_l3_all_pass():
    """The exact live gap: readme-first-run cleared L1+L2+L3 with demo_evidence: null."""
    r = acr.evaluate([("T-1", _fm(1, 1))], MEDIANS, GOOD_REC,
                     demo={"state": "absent", "detail": "records no demo_evidence"})
    assert r["l1"]["passed"] and r["l2"]["passed"] and r["l3"]["passed"]
    assert not r["l4"]["passed"]
    assert r["ready"] is False


def test_l4_indeterminate_is_not_a_pass():
    """A URL cannot be judged offline. Unproven is not proven — the same line
    T-3550 drew for a killed push."""
    r = acr.evaluate([("T-1", _fm(1, 1))], MEDIANS, GOOD_REC,
                     demo={"state": "indeterminate", "detail": "https://example/x"})
    assert not r["l4"]["passed"]
    assert r["ready"] is False


def test_l4_invalid_is_worded_differently_from_absent():
    """'recorded but does not validate' and 'nothing recorded' are different
    problems with different fixes, and must not read the same."""
    absent = acr.evaluate([], MEDIANS, GOOD_REC,
                          demo={"state": "absent", "detail": ""})["l4"]["summary"]
    invalid = acr.evaluate([], MEDIANS, GOOD_REC,
                           demo={"state": "invalid", "detail": "too small"})["l4"]["summary"]
    assert absent != invalid
    assert "no demo_evidence" in absent
    assert "does not validate" in invalid


def test_l4_omitted_is_reported_as_not_evaluated_and_excluded_from_ready():
    """Backwards compatibility with a visible seam.

    Defaulting an unevaluated leg to pass would be the false-green this work
    exists to remove; defaulting it to fail would make every pre-T-3553 caller
    report not-ready for a check it never asked for. So it is excluded from
    `ready` AND said out loud.
    """
    r = acr.evaluate([("T-1", _fm(1, 1))], MEDIANS, GOOD_REC)
    assert r["l4_evaluated"] is False
    assert "not evaluated" in r["l4"]["summary"]
    assert r["ready"] is True  # three-leg verdict, unchanged
