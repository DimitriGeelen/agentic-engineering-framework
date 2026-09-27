"""T-3525: the shared judge verdict contract (D-662).

THE TEST THAT MATTERS is `test_amber_without_guidance_RAISES`. Everything else here
checks shape; that one checks the property the operator actually asked for — "the
reviewer also needs to give guidance on what to do" — and it checks it by proving the
guidance-free verdict cannot be built at all.

Why that strength rather than a warning: `[REVIEWER]` criteria produce a verdict with
nothing to act on, and reached 7 uses against 412 for `[REVIEW]` (T-1878). A colour
with no instruction gets routed around, and the routing looks like compliance.

Second theme, the recurring defect of the whole session: UNKNOWN must not read as
green. Four separate instances were found and fixed today where "I could not tell" was
indistinguishable from "I checked and it was fine" — an absent blast_radius scoring
cheapest, a result line read as completion, a missing digest read as protection, and a
tooling failure read as a quality verdict.
"""

import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "lib"))
import judge_verdict as jv  # noqa: E402


# ── the contract's reason for existing ──────────────────────────────────────


@pytest.mark.parametrize("state", [jv.AMBER, jv.RED, jv.UNKNOWN])
def test_non_green_without_guidance_RAISES(state):
    with pytest.raises(jv.VerdictError) as exc:
        jv.verdict(state)
    assert "guidance" in str(exc.value)


@pytest.mark.parametrize("blank", ["", "   ", "\n", "\t  \n"])
def test_whitespace_is_not_guidance(blank):
    with pytest.raises(jv.VerdictError):
        jv.verdict(jv.RED, blank)


def test_green_needs_no_guidance():
    """The control. If green also required guidance, the mechanism would be a tax on
    every passing review and would be switched off."""
    v = jv.verdict(jv.GREEN)
    assert v["state"] == jv.GREEN
    assert v["guidance"] == ""


def test_non_green_with_guidance_is_constructible():
    v = jv.verdict(jv.AMBER, "raise D2 to 4: the task adds a structural gate, which the D2 rubric scores at 4")
    assert v["state"] == jv.AMBER
    assert "raise D2" in v["guidance"]


def test_evidence_does_not_substitute_for_guidance():
    # Evidence says what the judge SAW; guidance says what to DO. A caller can act on
    # only one of them, so evidence must not satisfy the requirement.
    with pytest.raises(jv.VerdictError):
        jv.verdict(jv.RED, "", evidence=["bvp_scores.D2 == 1", "task body names a gate"])


# ── three states, never a boolean ───────────────────────────────────────────


def test_a_typod_state_raises_rather_than_becoming_a_fourth_meaning():
    with pytest.raises(jv.VerdictError):
        jv.verdict("greenish", "guidance that is present and long enough to be real")


def test_may_proceed_distinguishes_amber_from_red():
    """Amber and red must differ in BEHAVIOUR. If they did not, the third state would
    be decoration."""
    assert jv.may_proceed(jv.verdict(jv.GREEN)) is True
    assert jv.may_proceed(jv.verdict(jv.AMBER, "record this and move on, weight looks high by one rung")) is True
    assert jv.may_proceed(jv.verdict(jv.RED, "do not confirm: no acceptance criteria exist to judge against")) is False
    assert jv.may_proceed(jv.verdict(jv.UNKNOWN, "cannot judge: the arc has no stated objective to map against")) is False


def test_truthiness_of_the_record_is_NOT_the_verdict():
    """`if verdict:` is truthy for every state including red — which is exactly the
    coercion the three-state ruling exists to prevent. may_proceed() is the only
    legitimate reduction to a boolean."""
    red = jv.verdict(jv.RED, "do not proceed; the score has no criteria behind it")
    assert bool(red) is True          # a non-empty dict
    assert jv.may_proceed(red) is False   # ...and yet not a pass


def test_every_state_has_a_distinct_documented_meaning():
    meanings = {s: jv.explain(s) for s in jv.STATES}
    assert len(set(meanings.values())) == len(jv.STATES)


# ── unknown is not green ────────────────────────────────────────────────────


def test_unknown_is_neither_green_nor_proceedable():
    u = jv.verdict(jv.UNKNOWN, "cannot judge: the estimator was not importable, so no rubric was readable")
    assert u["state"] != jv.GREEN
    assert jv.may_proceed(u) is False


def test_unknown_also_requires_guidance():
    # "I could not judge this" is actionable only if it says what would make judgement
    # possible — which is the fix OBS-559 asks for on the driver reviewer.
    assert jv.requires_guidance(jv.UNKNOWN) is True


# ── population: closed work is never reviewable ─────────────────────────────


def test_closed_work_is_not_reviewable():
    ok, why = jv.reviewable({"status": "work-completed"})
    assert ok is False
    assert "closed" in why


@pytest.mark.parametrize("status", ["captured", "started-work", "issues"])
def test_open_work_is_reviewable(status):
    ok, why = jv.reviewable({"status": status})
    assert ok is True
    assert status in why


def test_missing_status_is_not_reviewable_and_says_why():
    ok, why = jv.reviewable({})
    assert ok is False
    assert "status" in why


def test_horizon_is_only_required_when_asked():
    """Absence of a horizon must not silently shrink the population by default — that
    is the same unknown-as-exclusion error, pointing the other way."""
    fm = {"status": "captured"}
    assert jv.reviewable(fm)[0] is True
    assert jv.reviewable(fm, require_horizon=True)[0] is False
    assert jv.reviewable({"status": "captured", "horizon": "now"}, require_horizon=True)[0] is True


def test_reviewable_always_returns_a_reason():
    for fm in ({"status": "work-completed"}, {"status": "captured"}, {}, None):
        ok, why = jv.reviewable(fm)
        assert isinstance(why, str) and why.strip()


# ── one serialised shape, so two judges cannot diverge ──────────────────────


def test_record_shape_is_stable_and_versioned():
    v = jv.verdict(jv.AMBER, "guidance present", judged="T-1234", judge="bvp-score-judge",
                   evidence=["e1"])
    for key in ("state", "meaning", "guidance", "judged", "judge", "evidence", "ts", "contract"):
        assert key in v
    assert v["contract"] == "judge_verdict/1"


def test_rendering_never_omits_guidance():
    v = jv.verdict(jv.RED, "do not confirm: the arc has no objective to map against",
                   judged="arc-099")
    out = jv.format_verdict(v)
    assert "RED" in out
    assert "arc-099" in out
    assert "do not confirm" in out
