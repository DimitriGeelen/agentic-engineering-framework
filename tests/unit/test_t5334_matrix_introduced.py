"""T-5334 — risk-matrix acceptance for a PARTLY NEW risk is computed from the
actor rows the change introduces (optional `Introduced` column), not the worst
row overall. NEW risks, the 15+ rule and matrices without the column are
unchanged.
"""

import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
if str(ROOT / "lib") not in sys.path:
    sys.path.insert(0, str(ROOT / "lib"))

import risk_register as rr  # noqa: E402

SUMMARY_HEAD = (
    "| # | Risk | Domain | How to detect the door is open | How to detect it happening "
    "| Impact | Likelihood | Exists anyway (baseline)? | Introduced by the change? | Key mitigation |\n"
    "|---|------|--------|------|------|-------:|-----------:|------|------|------|\n"
)
HEAD_COL = (
    "| # | Actor | How | L | I | Score | Mitigated L × I | Mitigated score | Introduced |\n"
    "|---|-------|-----|--:|--:|------:|-----------------|----------------:|------------|\n"
)
HEAD_NOCOL = (
    "| # | Actor | How | L | I | Score | Mitigated L × I | Mitigated score |\n"
    "|---|-------|-----|--:|--:|------:|-----------------|----------------:|\n"
)


def _matrix(introduced, impact, likelihood, head, rows):
    return "\n".join([
        "# Risk matrix — test", "", "## Summary", "",
        SUMMARY_HEAD + f"| 1 | r1 | d | x | y | {impact} | {likelihood} | yes | {introduced} | m |",
        "", "### Risk 1 — r1", "", head + "\n".join(rows), "",
    ]) + "\n"


ANYWAY_6 = "| 1.5 | intruder | host control | 2 | 3 | 6 | | | no |"
INTRO_3 = "| 1.3 | outsider-intentional | stolen token | 1 | 3 | 3 | | | yes |"
INTRO_6 = "| 1.3 | outsider-intentional | stolen token | 2 | 3 | 6 | | | Yes |"


def _listed(res):
    return [n["risk"] for n in res["needs_operator_acceptance"]]


def test_introduced_3_next_to_anyway_6_not_listed():
    res = rr.parse_matrix(_matrix("PARTLY NEW (t)", 3, 2, HEAD_COL, [INTRO_3, ANYWAY_6]))
    assert res["errors"] == []
    assert _listed(res) == []
    assert res["risks"][0]["introduced_mitigated"] == 3
    assert res["risks"][0]["worst_mitigated"] == 6


def test_introduced_6_listed_with_reason():
    res = rr.parse_matrix(_matrix("PARTLY NEW (t)", 3, 2, HEAD_COL, [INTRO_6, ANYWAY_6]))
    assert res["errors"] == []
    assert _listed(res) == [1]
    assert any("introduced rows" in r for r in res["needs_operator_acceptance"][0]["reasons"])
    assert res["risks"][0]["introduced_mitigated"] == 6


def test_no_column_unchanged():
    rows = [r.rsplit("|", 2)[0] + "|" for r in (INTRO_3, ANYWAY_6)]
    res = rr.parse_matrix(_matrix("PARTLY NEW (t)", 3, 2, HEAD_NOCOL, rows))
    assert res["errors"] == []
    assert _listed(res) == [1]                    # worst row overall, as before
    assert "introduced_mitigated" not in res["risks"][0]


def test_new_risk_counts_all_rows():
    res = rr.parse_matrix(_matrix("NEW", 3, 2, HEAD_COL, [INTRO_3, ANYWAY_6]))
    assert res["errors"] == []
    assert _listed(res) == [1]


def test_column_without_yes_row_is_error():
    no3 = INTRO_3.replace("| yes |", "| no |")
    res = rr.parse_matrix(_matrix("PARTLY NEW (t)", 3, 2, HEAD_COL, [no3, ANYWAY_6]))
    assert any("PARTLY NEW risk 1 names no introduced actor row" in e for e in res["errors"])


def test_high_row_still_listed():
    anyway_high = "| 1.5 | intruder | host control | 4 | 4 | 16 | 3 x 2 | 6 | no |"
    res = rr.parse_matrix(_matrix("PARTLY NEW (t)", 4, 4, HEAD_COL, [INTRO_3, anyway_high]))
    assert res["errors"] == []
    assert _listed(res) == [1]
    assert any("high" in r for r in res["needs_operator_acceptance"][0]["reasons"])


def test_bad_value_is_error_naming_line():
    bad = INTRO_3.replace("| yes |", "| maybe |")
    res = rr.parse_matrix(_matrix("PARTLY NEW (t)", 3, 2, HEAD_COL, [bad, ANYWAY_6]))
    errs = [e for e in res["errors"] if "introduced must be yes or no" in e]
    assert errs and errs[0].startswith("line ")
