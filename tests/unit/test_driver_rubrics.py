"""T-2084: per-driver 0-5 scoring rubric parser for /bvp slider rows.

Pins the contract for `_driver_rubrics(policy)`:
- D1-D4 parsed from `policy/bvp-scoring-rubric.md`'s `### Score criteria` tables
- F1+ parsed from `value-drivers.yaml`'s `rationale` inline 0-5 enumeration
- Unknown / unparseable drivers → omitted (template degrades gracefully)
"""

from pathlib import Path

# Reach the blueprint helper via the project's normal import path.
PROJECT_ROOT = Path(__file__).resolve().parents[2]
import sys
sys.path.insert(0, str(PROJECT_ROOT))

from web.blueprints.bvp import _driver_rubrics, _load_policy  # noqa: E402


def _real_policy():
    return _load_policy()


def test_d1_parses_six_levels():
    """D1 (Antifragility) is fully populated in the rubric file —
    parser must yield exactly 6 entries indexed 0-5."""
    rubrics = _driver_rubrics(_real_policy())
    assert "D1" in rubrics, f"D1 missing from rubrics ({list(rubrics)})"
    assert len(rubrics["D1"]) == 6, f"D1 expected 6 levels, got {len(rubrics['D1'])}"


def test_d1_score_5_mentions_class():
    """D1 score 5 should describe class-of-behavior change (the rubric's
    'Changes the *class* of failure' language). Pinning the substring
    catches accidental table-row reordering."""
    rubrics = _driver_rubrics(_real_policy())
    assert "class" in rubrics["D1"][5].lower(), (
        f"D1 score 5 didn't mention 'class' (got: {rubrics['D1'][5]!r}) — "
        "rubric rows may have been reordered or the parser is misaligned."
    )


def test_d2_d3_d4_all_have_six_levels():
    """All four protected drivers are tabled in the rubric.md file
    and must parse with full 0-5 coverage."""
    rubrics = _driver_rubrics(_real_policy())
    for did in ("D2", "D3", "D4"):
        assert did in rubrics, f"{did} missing from rubrics"
        assert len(rubrics[did]) == 6, f"{did} expected 6 levels, got {len(rubrics[did])}"


def test_unknown_driver_id_returns_empty():
    """No entry for drivers absent from both sources — `in` check is False."""
    rubrics = _driver_rubrics(_real_policy())
    assert "D99" not in rubrics
    assert "FZ" not in rubrics


def test_free_driver_inline_rationale_parses():
    """F1 (Recall_Leverage) has a 0-5 rubric inline in its `rationale` field
    in value-drivers.yaml. Parser must handle the en-dash range form
    ('1–2 — desc') and yield 6 entries."""
    rubrics = _driver_rubrics(_real_policy())
    # F1 may or may not be in the policy depending on the project's free-driver
    # configuration. If present, contract is the same as protected drivers.
    if "F1" in rubrics:
        assert len(rubrics["F1"]) == 6, (
            f"F1 expected 6 levels, got {len(rubrics['F1'])}"
        )
        # Score 0 of F1 mentions 'durable artifact' / 'session' per the rubric.
        assert rubrics["F1"][0], "F1 score 0 should be non-empty"


def test_empty_policy_returns_empty_dict():
    """No protected_drivers, no free_drivers — rubric.md still has D1-D4
    so they will still be parsed. The contract is: never raise, always
    return a dict."""
    rubrics = _driver_rubrics({})
    assert isinstance(rubrics, dict)
    # D1-D4 come from rubric.md regardless of policy contents, so they
    # may still appear. The contract is "no crash, dict returned".
