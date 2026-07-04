"""T-100188: Regression tests for `web.shared.extract_recommendation_claims_verdict`.

Helper extracts the claims-validator verdict (written by
lib/reviewer/recommendation_claims.py, T-100187) from a task body's
`## Recommendation Verdict (vX.Y)` section, for rendering on /inception/<id>
and the /approvals evidence badge (T-100186 GO slice B).

Same H2+ terminator shape as `extract_reviewer_verdict` (L-293) so appended
Updates entries cannot pollute the parse.
"""

from __future__ import annotations

from web.shared import extract_recommendation_claims_verdict


def _block(overall: str, rows: str) -> str:
    return (
        "## Recommendation Verdict (v1.0)\n\n"
        "- **Scan ID:** RC-abc123\n"
        "- **Timestamp:** 2026-07-05T00:00:00Z\n"
        f"- **Overall:** {overall}\n"
        "- **Claims:** 2\n\n"
        "| Claim | Type | Status |\n"
        "|-------|------|--------|\n"
        f"{rows}\n"
    )


def test_confirmed_all_pass():
    body = (
        "## Recommendation\nGO — evidence below.\n\n"
        + _block(
            "CONFIRMED",
            "| `lib/reviewer/recommendation_claims.py` | file | ✓ pass |\n"
            "| `T-100187` | task_ref | ✓ pass |",
        )
        + "\n## Updates\n"
    )
    r = extract_recommendation_claims_verdict(body)
    assert r["overall"] == "CONFIRMED"
    assert r["total"] == 2
    assert r["passed"] == 2
    assert r["claims"][0]["raw"] == "lib/reviewer/recommendation_claims.py"
    assert r["claims"][0]["kind"] == "file"
    assert r["claims"][0]["status"] == "pass"
    assert r["claims"][1]["kind"] == "task_ref"


def test_contradicted_row_with_detail():
    body = _block(
        "CONTRADICTED",
        "| `lib/missing.py` | file | ✗ fail — file not found |\n"
        "| `T-100187` | task_ref | ✓ pass |",
    )
    r = extract_recommendation_claims_verdict(body)
    assert r["overall"] == "CONTRADICTED"
    assert r["total"] == 2
    assert r["passed"] == 1
    failed = r["claims"][0]
    assert failed["status"] == "fail"
    assert failed["detail"] == "file not found"


def test_unverifiable_row_maps_to_unverifiable_status():
    body = _block(
        "UNVERIFIED",
        "| `foo.bar.baz` | module | ? unverifiable — symbol not found |",
    )
    r = extract_recommendation_claims_verdict(body)
    assert r["overall"] == "UNVERIFIED"
    assert r["claims"][0]["status"] == "unverifiable"
    assert r["claims"][0]["detail"] == "symbol not found"


def test_missing_block_returns_none_overall():
    body = "## Context\nNo verdict here.\n\n## Recommendation\nGO.\n"
    r = extract_recommendation_claims_verdict(body)
    assert r["overall"] is None
    assert r["claims"] == []
    assert r["total"] == 0
    assert r["passed"] == 0


def test_empty_body_returns_none_overall():
    assert extract_recommendation_claims_verdict("")["overall"] is None
    assert extract_recommendation_claims_verdict(None)["overall"] is None


def test_section_bounded_by_next_heading():
    # Table rows AFTER the next H2 must not leak into the parse.
    body = (
        _block("CONFIRMED", "| `T-100187` | task_ref | ✓ pass |")
        + "\n## Updates\n\n"
        "| `should/not/parse.py` | file | ✗ fail |\n"
    )
    r = extract_recommendation_claims_verdict(body)
    assert r["total"] == 1
    assert r["claims"][0]["raw"] == "T-100187"


def test_no_claims_block_yields_zero_total():
    body = (
        "## Recommendation Verdict (v1.0)\n\n"
        "- **Scan ID:** RC-xyz\n"
        "- **Overall:** UNVERIFIED\n"
        "- **Claims:** 0\n"
        "- No verifiable claims found in ## Recommendation\n"
    )
    r = extract_recommendation_claims_verdict(body)
    assert r["overall"] == "UNVERIFIED"
    assert r["total"] == 0
    assert r["passed"] == 0
