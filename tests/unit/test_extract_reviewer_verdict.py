"""T-1569: Regression tests for `web.shared.extract_reviewer_verdict`.

Helper extracts the reviewer agent's mechanical scan verdict from a task body's
`## Reviewer Verdict (vX.Y)` section. Origin: F3 from T-1565 audit — the reviewer
is the only mechanical advisor in the approval arc, but /approvals never surfaced
its findings at decision time.

Same H2+ terminator shape as `extract_recommendation_verdict` (L-293) so appended
Updates entries cannot pollute the parse.
"""

from __future__ import annotations

from web.shared import extract_reviewer_verdict


def test_pass_no_findings():
    body = (
        "## Context\nSome context.\n\n"
        "## Reviewer Verdict (v1.4)\n\n"
        "- **Scan ID:** R-abc123\n"
        "- **Overall:** PASS\n"
        "- **Needs Human:** no\n"
        "- **Findings:** none\n\n"
        "## Updates\n"
    )
    r = extract_reviewer_verdict(body)
    assert r["overall"] == "PASS"
    assert r["findings"] == 0
    assert r["needs_human"] is False


def test_warn_with_findings_needs_human():
    body = (
        "## Reviewer Verdict (v1.5)\n\n"
        "- **Overall:** WARN\n"
        "- **Needs Human:** yes\n"
        "- **Findings:** 3\n"
        "## Updates\n"
    )
    r = extract_reviewer_verdict(body)
    assert r["overall"] == "WARN"
    assert r["findings"] == 3
    assert r["needs_human"] is True


def test_fail_with_many_findings():
    body = (
        "## Reviewer Verdict (v1.0)\n\n"
        "- **Overall:** FAIL\n"
        "- **Needs Human:** yes\n"
        "- **Findings:** 12\n"
    )
    r = extract_reviewer_verdict(body)
    assert r["overall"] == "FAIL"
    assert r["findings"] == 12
    assert r["needs_human"] is True


def test_missing_section_returns_none_overall():
    r = extract_reviewer_verdict("## Context\nNo verdict here.\n")
    assert r["overall"] is None
    assert r["findings"] == 0
    assert r["needs_human"] is None


def test_empty_body():
    r = extract_reviewer_verdict("")
    assert r["overall"] is None
    r2 = extract_reviewer_verdict(None)  # type: ignore[arg-type]
    assert r2["overall"] is None


def test_section_terminator_stops_at_appended_h3():
    """L-293 shape: an appended `### timestamp` Updates entry inside the verdict
    region must not bleed into subsequent sections' parsing. The terminator
    matches any heading at H2+ — so a deeper heading inside the section is fine,
    but the next H2 ends it cleanly."""
    body = (
        "## Reviewer Verdict (v1.4)\n\n"
        "- **Overall:** PASS\n"
        "- **Needs Human:** no\n"
        "- **Findings:** none\n\n"
        "### 2026-04-27 — status-update\n"
        "- **Change:** status: started-work → work-completed\n"
    )
    r = extract_reviewer_verdict(body)
    # The H3 inside the verdict block doesn't break extraction — fields above it parse.
    assert r["overall"] == "PASS"


def test_does_not_pick_up_unrelated_overall_lines():
    """A different section's `**Overall:**` must not be parsed when no
    `## Reviewer Verdict` block exists."""
    body = (
        "## Context\n"
        "- **Overall:** GREAT\n"
    )
    r = extract_reviewer_verdict(body)
    assert r["overall"] is None


def test_real_world_sample():
    """Verify against the canonical shape emitted by render_verdict_md."""
    body = (
        "## Reviewer Verdict (v1.4)\n"
        "\n"
        "- **Scan ID:** R-b6f133c1\n"
        "- **Timestamp:** 2026-04-25T18:17:43Z\n"
        "- **Catalogue:** v1.3-seed\n"
        "- **Overall:** PASS\n"
        "- **Needs Human:** no\n"
        "- **Findings:** none\n"
        "\n"
        "## Updates\n"
    )
    r = extract_reviewer_verdict(body)
    assert r == {"overall": "PASS", "findings": 0, "needs_human": False}
