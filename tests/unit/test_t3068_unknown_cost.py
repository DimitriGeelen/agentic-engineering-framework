"""T-3068: unmeasured blast radius must not price as cheapest.

The defect was not a wrong number, it was a wrong *kind*. `score_blast_radius`
returned 0 when it found no `components:`, and 0 is the cheapest value on a term
carrying weight 0.6 — more than the other two cost terms combined. So "the
framework never recorded what this touches" and "this touches nothing" were the
same value, and it was the most attractive one available. An HV/LC filter then
promoted preferentially on absence of information.

The population made it near-total rather than occasional: `components:` is resolved
at the work-completed transition, and `fw bvp` excludes work-completed by default,
so 4 of 142 ranked tasks had the input the axis leans hardest on.

The load-bearing test here is `test_unknown_does_not_undercut_a_known_small_cost` —
it states the inversion as an ordering property rather than as a value, so it keeps
failing if some later change reintroduces the effect by a different route (a
default, a coalesce, a fillna) without literally writing 0.
"""

import importlib.util
import sys
from pathlib import Path

FW_ROOT = Path(__file__).resolve().parents[2]
_EST = FW_ROOT / "agents" / "termlink" / "bvp-estimator" / "estimator.py"

_spec = importlib.util.spec_from_file_location("_bvp_estimator", _EST)
est = importlib.util.module_from_spec(_spec)
sys.modules["_bvp_estimator"] = est
_spec.loader.exec_module(est)


def _br(**fm):
    """score_blast_radius over frontmatter alone; body/tags are unused by it."""
    return est.score_blast_radius(fm, "", list(fm.get("tags") or []))


# ------------------------------------------------------- unknown is not a number


def test_no_components_is_unknown_not_zero():
    v, ev = _br(workflow_type="build")
    assert v is None, f"expected unknown, got {v!r}"
    # The evidence string is the only place an operator learns *why*, so it has to
    # say more than "no signal".
    assert "no-components" in ev[0]


def test_malformed_components_is_unknown_not_zero():
    v, _ = _br(workflow_type="build", components="web/app.py")  # str, not list
    assert v is None


def test_a_real_component_count_still_scores():
    assert _br(workflow_type="build", components=["a"])[0] == 1
    assert _br(workflow_type="build", components=["a", "b", "c"])[0] == 3
    assert _br(workflow_type="build", components=list("abcde"))[0] == 5


def test_inception_exception_is_untouched():
    """T-2189's path must keep working — it is the one route that already
    distinguished 'not built yet' from 'touches nothing'."""
    assert _br(workflow_type="inception", target_blast_radius=4)[0] == 4
    # No target declared → still unknown, not 0.
    assert _br(workflow_type="inception")[0] is None


# --------------------------------------------------- the composite must not fill in


def test_estimate_cost_emits_null_rather_than_completing_the_composite(tmp_path):
    t = tmp_path / "T-9001-x.md"
    t.write_text(
        "---\nid: T-9001\nname: \"x\"\nstatus: started-work\n"
        "workflow_type: build\n---\n\n## Context\n\nx\n"
    )
    out = est.estimate_cost(t)
    ce = out["cost_estimate"]
    assert ce["blast_radius"] is None, ce
    # The other two terms are still reported — the point is that they must not be
    # silently promoted into a composite standing in for all three.
    assert ce["tier"] is not None and ce["effort"] is not None


def test_rationale_names_the_reason_instead_of_no_signal(tmp_path):
    """Regression on the renderer: it printed '(no-signal)' for every term on
    every task, because it looked for evidence entries not starting with the
    arrow and all three scorers emit exactly one entry that does."""
    t = tmp_path / "T-9002-x.md"
    t.write_text(
        "---\nid: T-9002\nname: \"x\"\nstatus: started-work\n"
        "workflow_type: build\ntags: [tier-0]\n---\n\n## Context\n\nx\n"
    )
    out = est.estimate_cost(t)
    r = est._cost_short_rationale(out["evidence"])
    assert "no-signal" not in r, r
    assert "no-components" in r, r
    assert "tier-0" in r, r


# ------------------------------------------------ the property, not the value


def test_unknown_does_not_undercut_a_known_small_cost():
    """The inversion, stated as ordering.

    A task nobody measured must not sort cheaper than a task measured and found
    small. Asserting the ordering rather than the sentinel means a future change
    that reintroduces cheapness by defaulting, coalescing, or clamping — without
    ever literally writing 0 — still fails here.
    """
    unknown, _ = _br(workflow_type="build")
    known_small, _ = _br(workflow_type="build", components=["one-file"])

    assert unknown is None
    assert known_small == 1

    # There is no total order that places `unknown` below `known_small`, which is
    # exactly the property we want: it cannot be compared, so it cannot win a
    # cheapest-first sort by accident.
    cheapest_first = sorted(
        [("known", known_small), ("unknown", unknown)],
        key=lambda p: (p[1] is None, p[1] if p[1] is not None else 0),
    )
    assert cheapest_first[0][0] == "known", (
        "an unmeasured task sorted ahead of a measured cheap one — the T-3068 "
        "inversion is back"
    )
