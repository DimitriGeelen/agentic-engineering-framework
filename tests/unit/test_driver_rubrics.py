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


def test_d1_parses_six_single_score_levels():
    """D1 (Antifragility) is fully populated in the rubric file —
    parser must yield exactly 6 (label, desc) entries with labels "0".."5".
    Protected-driver tables in rubric.md never use ranges."""
    rubrics = _driver_rubrics(_real_policy())
    assert "D1" in rubrics, f"D1 missing from rubrics ({list(rubrics)})"
    assert len(rubrics["D1"]) == 6, f"D1 expected 6 levels, got {len(rubrics['D1'])}"
    labels = [label for label, _desc in rubrics["D1"]]
    assert labels == ["0", "1", "2", "3", "4", "5"], (
        f"D1 labels expected single scores 0..5, got {labels!r}"
    )


def test_d1_score_5_mentions_class():
    """D1 score 5 (the last entry) should describe class-of-behavior change
    (the rubric's 'Changes the *class* of failure' language). Pinning the
    substring catches accidental table-row reordering."""
    rubrics = _driver_rubrics(_real_policy())
    _label5, desc5 = rubrics["D1"][5]
    assert "class" in desc5.lower(), (
        f"D1 score 5 didn't mention 'class' (got: {desc5!r}) — "
        "rubric rows may have been reordered or the parser is misaligned."
    )


def test_d2_d3_d4_all_have_six_levels():
    """All four protected drivers are tabled in the rubric.md file
    and must parse with full 0-5 coverage, single-score labels each."""
    rubrics = _driver_rubrics(_real_policy())
    for did in ("D2", "D3", "D4"):
        assert did in rubrics, f"{did} missing from rubrics"
        assert len(rubrics[did]) == 6, f"{did} expected 6 levels, got {len(rubrics[did])}"
        labels = [label for label, _desc in rubrics[did]]
        assert labels == ["0", "1", "2", "3", "4", "5"], (
            f"{did} labels expected single scores 0..5, got {labels!r}"
        )


def test_unknown_driver_id_returns_empty():
    """No entry for drivers absent from both sources — `in` check is False."""
    rubrics = _driver_rubrics(_real_policy())
    assert "D99" not in rubrics
    assert "FZ" not in rubrics


def test_free_driver_inline_rationale_parses():
    """F1 (Recall_Leverage) has 0-5 coverage inline in its `rationale` field
    in value-drivers.yaml. The source uses `1–2 — desc` (range) so the result
    has FEWER than 6 entries (range collapses to one row) — T-2086.
    Total covered scores still equals 6."""
    rubrics = _driver_rubrics(_real_policy())
    # F1 may or may not be in the policy depending on the project's free-driver
    # configuration. If present, contract is the same as protected drivers.
    if "F1" in rubrics:
        entries = rubrics["F1"]
        assert 1 <= len(entries) <= 6, (
            f"F1 expected 1-6 entries, got {len(entries)}"
        )
        # Score 0 of F1 mentions 'durable artifact' / 'session' per the rubric.
        assert entries[0][1], "F1 score 0 should have non-empty desc"
        # Total coverage equals exactly {0..5} when we expand range labels.
        covered: set[int] = set()
        for label, _desc in entries:
            if "–" in label or "-" in label:
                # range label — split on en-dash OR ascii hyphen
                sep = "–" if "–" in label else "-"
                lo_s, hi_s = label.split(sep, 1)
                for s in range(int(lo_s), int(hi_s) + 1):
                    covered.add(s)
            else:
                covered.add(int(label))
        assert covered == set(range(6)), (
            f"F1 entry labels do not cover 0-5 exactly (got {covered})"
        )


def test_f1_range_collapses_to_single_entry():
    """T-2086 regression pin — value-drivers.yaml ships F1 with `1–2 — desc`
    (a deliberate two-score range). The parser must emit ONE entry labeled
    "1–2" with that description, NOT two identical entries labeled "1" and "2".

    Synthetic policy keeps the test independent of the real YAML — if the
    canonical F1 wording changes, this pin still catches a duplicate-row
    regression in the parser itself."""
    synthetic = {
        "free_drivers": [
            {
                "id": "F-TEST",
                "rationale": (
                    "0 — zero desc\n"
                    "1–2 — shared desc for one and two\n"
                    "3 — three desc\n"
                    "4 — four desc\n"
                    "5 — five desc\n"
                ),
            },
        ],
    }
    rubrics = _driver_rubrics(synthetic)
    assert "F-TEST" in rubrics, "synthetic F-TEST should parse"
    entries = rubrics["F-TEST"]
    assert len(entries) == 5, (
        f"F-TEST expected 5 entries (0, 1–2, 3, 4, 5), got {len(entries)}: {entries!r}"
    )
    labels = [label for label, _desc in entries]
    assert labels == ["0", "1–2", "3", "4", "5"], (
        f"F-TEST labels expected ['0', '1–2', '3', '4', '5'], got {labels!r}"
    )
    # Critical: the range row is NOT duplicated.
    range_descs = [desc for label, desc in entries if label == "1–2"]
    assert len(range_descs) == 1, (
        f"F-TEST range '1–2' should be exactly one entry, got {len(range_descs)} "
        "(this is the T-2086 regression — two identical rows for scores 1 and 2)"
    )
    assert range_descs[0] == "shared desc for one and two"


def test_overlapping_ranges_rejected():
    """If a free driver's rationale has overlapping ranges (e.g. `1–3` and
    `2 — …`), the result is unparseable — drop the driver rather than emit
    confusing partial output."""
    synthetic = {
        "free_drivers": [
            {
                "id": "F-BAD",
                "rationale": (
                    "0 — a\n1–3 — b\n2 — c\n4 — d\n5 — e\n"  # 2 collides
                ),
            },
        ],
    }
    rubrics = _driver_rubrics(synthetic)
    assert "F-BAD" not in rubrics, (
        "overlapping ranges should be rejected gracefully (no entry)"
    )


def test_empty_policy_returns_empty_dict():
    """No protected_drivers, no free_drivers — rubric.md still has D1-D4
    so they will still be parsed. The contract is: never raise, always
    return a dict."""
    rubrics = _driver_rubrics({})
    assert isinstance(rubrics, dict)
    # D1-D4 come from rubric.md regardless of policy contents, so they
    # may still appear. The contract is "no crash, dict returned".
