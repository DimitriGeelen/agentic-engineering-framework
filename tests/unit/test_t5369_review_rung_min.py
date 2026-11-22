"""T-5369: frontmatter `review_rung_min` raises the review rung; it never lowers it."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "lib"))
import review_policy as rp  # noqa: E402

LOW = {"name": "tidy a docstring", "description": "internal wording", "tags": []}
MEDIUM = {"name": "fix bin/fw routing", "description": "touches bin/fw", "tags": []}
HIGH = {"name": "harden auth", "description": "security fix", "tags": []}


def _min(fm, v):
    return {**fm, "review_rung_min": v}


def test_computed_3_declared_5_gives_5_with_reason():
    assert rp.required_rung(MEDIUM, [])[0] == 3
    rung, why = rp.required_rung(_min(MEDIUM, 5), [])
    assert rung == 5 and "review_rung_min: 5 (declared)" in why


def test_numeric_string_accepted():
    rung, why = rp.required_rung(_min(MEDIUM, "5"), [])
    assert rung == 5 and "review_rung_min: 5 (declared)" in why


def test_computed_5_declared_1_stays_5():
    rung, why = rp.required_rung(_min(HIGH, 1), [])
    assert rung == 5 and "(declared)" not in why


def test_declared_3_on_low_gives_3():
    assert rp.required_rung(LOW, [])[0] == 1
    rung, why = rp.required_rung(_min(LOW, 3), [])
    assert rung == 3 and "review_rung_min: 3 (declared)" in why


def test_invalid_values_leave_rung_unchanged():
    for fm in (LOW, MEDIUM, HIGH):
        base = rp.required_rung(fm, [])[0]
        for bad in (7, "high", 2, True, 0, -5, "", [5]):
            rung, why = rp.required_rung(_min(fm, bad), [])
            assert rung == base, (fm, bad)
            assert "ignored" in why and "(declared)" not in why


def test_no_field_unchanged():
    for fm, want in ((LOW, 1), (MEDIUM, 3), (HIGH, 5)):
        rung, why = rp.required_rung(fm, [])
        assert rung == want and "review_rung_min" not in why
    assert rp.required_rung(_min(LOW, None), [])[0] == 1
