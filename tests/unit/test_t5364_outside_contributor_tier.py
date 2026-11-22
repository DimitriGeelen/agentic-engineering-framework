"""T-5364: an outside contributor's change is reviewed one risk level higher
(CONTRIBUTING.md "Pull Request Process" step 6)."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "lib"))
import review_policy as rp  # noqa: E402

REASON = "outside contributor (CONTRIBUTING step 6): one level higher"
LOW = {"name": "tidy a docstring", "description": "internal wording", "tags": []}
MEDIUM = {"name": "fix bin/fw routing", "description": "touches bin/fw", "tags": []}
HIGH = {"name": "harden auth", "description": "security fix", "tags": []}


def _tag(fm):
    return {**fm, "tags": list(fm["tags"]) + ["outside-contributor"]}


def test_baselines_untagged_unchanged():
    assert rp.impact(LOW, [])["tier"] == "low"
    assert rp.impact(MEDIUM, [])["tier"] == "medium"
    assert rp.impact(HIGH, [])["tier"] == "high"
    for fm in (LOW, MEDIUM, HIGH):
        imp = rp.impact(fm, [])
        assert REASON not in imp["reasons"]
        assert imp["inputs"]["outside_contributor"] is False


def test_low_becomes_medium():
    imp = rp.impact(_tag(LOW), [])
    assert imp["tier"] == "medium" and REASON in imp["reasons"]
    assert imp["inputs"]["outside_contributor"] is True
    assert rp.required_rung(_tag(LOW), [])[0] == 3


def test_medium_becomes_high():
    imp = rp.impact(_tag(MEDIUM), [])
    assert imp["tier"] == "high" and REASON in imp["reasons"]
    rung, why = rp.required_rung(_tag(MEDIUM), [])
    assert rung == 5 and REASON in why


def test_high_stays_high_with_reason():
    imp = rp.impact(_tag(HIGH), [])
    assert imp["tier"] == "high"
    assert "security" in imp["reasons"] and REASON in imp["reasons"]
    assert rp.required_rung(_tag(HIGH), [])[0] == 5


def test_tag_case_insensitive():
    fm = {**LOW, "tags": ["Outside-Contributor"]}
    assert rp.impact(fm, [])["tier"] == "medium"
