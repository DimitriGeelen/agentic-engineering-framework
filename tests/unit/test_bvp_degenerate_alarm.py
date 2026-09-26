"""T-3489 — the degenerate-scorer alarm (slice 2 of T-3484).

The control that replaces the removed BVP confirmation gate. Every test here
exists to defend one property: **the alarm must discriminate.** A detector that
fires on everything is as useless as one that fires on nothing, and both look
like "working" from a single green run.

So the suite has a fire leg, a NOT-fire leg, and an insufficient-data leg — and
the not-fire leg is the one that matters most, because it is what proves the
fire leg means something.

No live corpus counts are pinned (T-3326) — every family here is constructed.
"""

import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from lib import bvp_degenerate as bd  # noqa: E402


def rows(family, scores):
    return [(family, dict(zip(bd.DRIVERS, s))) for s in scores]


# ── fires on a flat family ──────────────────────────────────────────────────

def test_fires_on_a_constant_family():
    """The shape procAsFit round 3 found by hand: one pattern, repeated."""
    v = bd.family_verdicts(rows("build", [(4, 0, 2, 2)] * 12))
    assert len(v) == 1 and v[0]["verdict"] == bd.FIRED
    assert v[0]["flat_drivers"] == list(bd.DRIVERS)


def test_names_the_constant_not_just_the_verdict():
    """'flat' with no pattern is unactionable — the operator needs the value."""
    v = bd.family_verdicts(rows("build", [(4, 0, 2, 2)] * 10))[0]
    pattern, count = v["modal_pattern"]
    assert list(pattern) == [4, 0, 2, 2]
    assert count == 10


def test_fires_on_a_single_flat_driver():
    """Partial flatness is still flatness: D2 constant, the rest spread."""
    v = bd.family_verdicts(rows("build", [
        (0, 3, 0, 5), (5, 3, 4, 0), (2, 3, 1, 3),
        (4, 3, 5, 1), (1, 3, 2, 4), (3, 3, 3, 2),
    ]))[0]
    assert v["verdict"] == bd.FIRED
    assert v["flat_drivers"] == ["D2"]


# ── THE CONTROL LEG: does not fire on a healthy family ──────────────────────

def test_does_NOT_fire_on_a_well_spread_family():
    """The leg that gives every other leg meaning.

    Without this, a detector hard-coded to return FIRED would pass the whole
    suite. Same class as the control legs in T-3469 and T-3486.
    """
    v = bd.family_verdicts(rows("build", [
        (0, 1, 2, 3), (5, 4, 3, 2), (2, 0, 5, 1),
        (3, 5, 0, 4), (1, 2, 4, 0), (4, 3, 1, 5),
    ]))[0]
    assert v["verdict"] == bd.OK, f"alarm fired on a spread family: {v}"
    assert v["flat_drivers"] == []


def test_a_one_step_spread_is_not_flat_at_the_chosen_floor():
    """Guards the threshold itself: real but small variation must survive.

    Half at 2 and half at 4 gives variance 1.0, above the 0.5 floor. If someone
    raises the floor past 1.0 this test fails and says why.
    """
    v = bd.family_verdicts(rows("build", [(2, 2, 2, 2)] * 5 + [(4, 4, 4, 4)] * 5))[0]
    assert v["verdict"] == bd.OK


# ── insufficient data is not a pass ─────────────────────────────────────────

def test_a_small_family_is_insufficient_not_healthy():
    """T-3099 class: a check that did not evaluate must not read as a pass."""
    v = bd.family_verdicts(rows("build", [(4, 0, 2, 2)] * 3))[0]
    assert v["verdict"] == bd.INSUFFICIENT
    assert v["verdict"] != bd.OK
    assert "variance" not in v, "no variance should be reported for an unjudgeable family"


def test_empty_corpus_concentration_is_insufficient_not_ok():
    assert bd.concentration([])["verdict"] == bd.INSUFFICIENT


# ── concentration: the shape variance misses ────────────────────────────────

def test_concentration_catches_a_bimodal_corpus_variance_would_pass():
    """Two constants have healthy variance and zero discrimination.

    This is why variance alone is not enough: the family verdict passes, and the
    scorer is still emitting one of two answers.
    """
    bimodal = rows("build", [(0, 0, 0, 0)] * 10 + [(5, 5, 5, 5)] * 10)
    assert bd.family_verdicts(bimodal)[0]["verdict"] == bd.OK      # variance is fine
    assert bd.concentration(bimodal)["verdict"] == bd.FIRED        # concentration is not


def test_concentration_does_not_fire_on_a_varied_corpus():
    """Control leg for concentration.

    The first version of this fixture was WRONG and the detector caught it:
    `(a%6, 2a%6, 3a%6, 5a%6)` cycles with period 6, so 60 rows held only 6
    distinct tuples — a 33% top-2 share, which genuinely IS concentrated. The
    detector fired correctly and the test was at fault. Using real distinct
    tuples now, which is what "varied" was supposed to mean.
    """
    import itertools
    distinct = list(itertools.islice(itertools.product(range(6), repeat=4), 0, 216, 3))
    varied = rows("build", distinct)
    c = bd.concentration(varied)
    assert len(distinct) > 50, "fixture must actually be varied"
    assert c["distinct"] == len(distinct), c
    assert c["verdict"] == bd.OK, c


def test_concentration_reports_the_patterns_and_their_share():
    c = bd.concentration(rows("build", [(4, 0, 2, 2)] * 8 + [(1, 2, 3, 4)] * 2))
    assert c["top"][0]["pattern"] == [4, 0, 2, 2]
    assert c["top"][0]["count"] == 8
    assert c["share"] == 1.0


# ── parsing and render ──────────────────────────────────────────────────────

def test_parse_requires_all_four_drivers():
    partial = "workflow_type: build\nbvp_scores_proposed:\n      D1: 4\n      D2: 0\n---\n"
    assert bd.parse_task(partial) is None


def test_parse_reads_family_and_scores():
    text = ("workflow_type: inception\nbvp_scores_proposed:\n"
            "      D1: 2\n      D2: 2\n      D3: 2\n      D4: 2\n---\n")
    family, scores = bd.parse_task(text)
    assert family == "inception"
    assert scores == {"D1": 2, "D2": 2, "D3": 2, "D4": 2}


def _fam(family, verdict, **kw):
    base = {"family": family, "n": 10, "verdict": verdict, "axis": "drivers",
            "scale": "four directives, integers 0-5", "floor": 0.5,
            "variance": {d: 0.0 for d in bd.DRIVERS},
            "flat_drivers": [], "modal_pattern": ((1, 2, 3, 4), 1),
            "modal_share": 0.1}
    base.update(kw)
    return base


def test_render_marks_every_state_distinctly():
    rep = {
        "scored_tasks": 20,
        "families": [
            _fam("flat", bd.FIRED, flat_drivers=list(bd.DRIVERS),
                 modal_pattern=((4, 0, 2, 2), 10), modal_share=1.0),
            _fam("fine", bd.OK, variance={d: 2.0 for d in bd.DRIVERS}),
            {"family": "tiny", "n": 2, "verdict": bd.INSUFFICIENT, "detail": "too few"},
            {"family": "novel", "n": 9, "verdict": bd.UNKNOWN_AXIS,
             "detail": "no declared scoring axis"},
        ],
        "concentration": {"verdict": bd.OK, "n": 20, "share": 0.1,
                          "ceiling": 0.25, "top": [], "distinct": 15},
        "fired": True,
    }
    out = bd.render(rep)
    for marker in ("[FIRED]", "[ok]", "[INSUFFICIENT]", "[UNKNOWN-AXIS]"):
        assert marker in out, f"{marker} missing from render:\n{out}"
    assert "[4, 0, 2, 2]" in out, "the modal constant must appear, not just a verdict"


# ── T-3495: each family is measured on ITS OWN axis ─────────────────────────

def test_inception_is_measured_on_voi_not_on_the_directives():
    """The false positive this task removed.

    Inceptions are scored on voi_score by ruling T-2186/T-2188
    (estimator.py:2668, 050-Inceptions.md §Scoring Exception). Reporting them as
    flat on D1-D4 flagged a documented design decision, which trains the reader
    to dismiss the alarm — the T-3453 inverted-alarm class.
    """
    incs = [("inception", {"voi_score": 0.5}) for _ in range(10)]
    v = bd.family_verdicts(incs)[0]
    assert v["axis"] == "voi"
    assert v["verdict"] == bd.FIRED
    assert v["flat_drivers"] == ["voi_score"]
    assert "D1" not in v["variance"], "inception must not be judged on the directives"
    assert v["modal_pattern"][0] == (0.5,)


def test_a_spread_of_voi_scores_does_NOT_fire():
    """Control leg on the new axis — otherwise the voi check means nothing."""
    incs = [("inception", {"voi_score": x})
            for x in (0.1, 0.3, 0.5, 0.7, 0.9, 0.2, 0.8, 0.4)]
    v = bd.family_verdicts(incs)[0]
    assert v["verdict"] == bd.OK, v


def test_the_voi_floor_is_scaled_to_its_own_range():
    """A 0..1 float cannot be judged by a threshold built for 0-5 integers.

    The pre-T-3495 detector applied one global floor of 0.5 to everything; no
    distribution on 0..1 can exceed that variance, so every voi axis would have
    read as flat forever — a check that can only ever fire.
    """
    assert bd.AXES["voi"]["floor"] < bd.AXES["drivers"]["floor"]
    assert bd.AXES["voi"]["floor"] <= 0.25, "max variance on 0..1 is 0.25"


def test_an_undeclared_family_is_unknown_axis_not_healthy():
    """T-3099 class, and the reason 4 fixtures in this file had to move.

    Before the axis table, an unrecognised workflow_type was silently measured
    on the directives. Now it reports unknown-axis, because applying the wrong
    axis is exactly how the inception false positive happened.
    """
    v = bd.family_verdicts(rows("some-new-workflow", [(4, 0, 2, 2)] * 10))[0]
    assert v["verdict"] == bd.UNKNOWN_AXIS
    assert v["verdict"] != bd.OK
    assert "variance" not in v


def test_concentration_excludes_non_driver_families():
    """An inception row has no D1 — before the fix it would KeyError, or worse
    be zero-filled and counted as a pattern it never had."""
    mixed = rows("build", [(1, 2, 3, 4)] * 6) + \
        [("inception", {"voi_score": 0.5}) for _ in range(40)]
    c = bd.concentration(mixed)
    assert c["n"] == 6, f"inception rows leaked into the driver population: {c}"


# ── the fence ───────────────────────────────────────────────────────────────

def test_detector_is_decoupled_from_the_scorer_it_watches():
    """It must still run while lib/bvp.sh is mid-change — which it was."""
    src = Path(bd.__file__).read_text(encoding="utf-8")
    import re
    assert not re.search(r"^\s*(from|import)\s+.*\bbvp\b", src, re.M)
