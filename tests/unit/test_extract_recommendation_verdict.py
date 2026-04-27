"""T-1534: Regression tests for `web.shared.extract_recommendation_verdict`.

Helper extracts the agent's GO/DEFER/NO-GO verdict from a task body's
`## Recommendation` section. Origin: T-1530-T-1533 review-workflow arc.

The L-293 risk: section regex must terminate at any H2-or-deeper heading
so appended Updates entries (which carry `**Action:**` lines that may
incidentally contain "GO" / "DEFER" tokens) do not pollute the verdict.
Same shape as T-1519, T-1526, T-1527.
"""

from __future__ import annotations

from web.shared import extract_recommendation_verdict


def test_go_verdict_extracted():
    body = (
        "## Context\nSome context.\n\n"
        "## Recommendation\n\n"
        "**Recommendation:** GO\n\n"
        "**Rationale:** Looks fine.\n\n"
        "## Updates\n"
    )
    assert extract_recommendation_verdict(body) == "GO"


def test_defer_verdict_extracted():
    body = (
        "## Recommendation\n\n"
        "**Recommendation:** DEFER\n\n"
        "**Rationale:** Watch for recurrence.\n\n"
        "## Decisions\n"
    )
    assert extract_recommendation_verdict(body) == "DEFER"


def test_nogo_verdict_extracted():
    body = (
        "## Recommendation\n\n"
        "**Recommendation:** NO-GO\n\n"
        "**Rationale:** Out of scope.\n"
    )
    assert extract_recommendation_verdict(body) == "NO-GO"


def test_missing_section_returns_question_mark():
    body = "## Context\nNo recommendation here.\n## Updates\n"
    assert extract_recommendation_verdict(body) == "?"


def test_empty_body_returns_question_mark():
    assert extract_recommendation_verdict("") == "?"
    assert extract_recommendation_verdict(None) == "?"  # type: ignore[arg-type]


def test_section_present_but_no_verdict_returns_question_mark():
    body = (
        "## Recommendation\n\n"
        "Pending — agent has not formed a recommendation yet.\n\n"
        "## Decisions\n"
    )
    assert extract_recommendation_verdict(body) == "?"


def test_appended_updates_h3_does_not_pollute_verdict():
    """L-293 regression: an Updates `### timestamp` entry containing a literal
    `**Action:** decided to GO ahead` line must NOT trick the extractor when
    the real Recommendation section says DEFER. The H2+ terminator stops at
    the H3 boundary too (or any deeper heading)."""
    body = (
        "## Recommendation\n\n"
        "**Recommendation:** DEFER\n\n"
        "**Rationale:** Single instance.\n\n"
        "### 2026-04-27 — appended-update\n"
        "- **Action:** decided to GO ahead with X\n"
    )
    # Real verdict is DEFER; the appended H3 with "GO" must not change that.
    assert extract_recommendation_verdict(body) == "DEFER"


def test_case_insensitive_match():
    body = (
        "## Recommendation\n\n"
        "**Recommendation:** go\n\n"
        "## Updates\n"
    )
    assert extract_recommendation_verdict(body) == "GO"


def test_html_comments_in_section_ignored():
    body = (
        "## Recommendation\n\n"
        "<!-- Reviewer note: marker -->\n"
        "**Recommendation:** GO\n\n"
        "## Decisions\n"
    )
    assert extract_recommendation_verdict(body) == "GO"


def test_multiple_h2_sections_only_first_recommendation_counted():
    """If a task somehow has two `## Recommendation` blocks (rewrite glitch),
    the helper captures the first (the canonical one). Subsequent verdicts
    in later sections do not override."""
    body = (
        "## Recommendation\n\n"
        "**Recommendation:** DEFER\n\n"
        "## Recommendation\n\n"
        "**Recommendation:** GO\n"
    )
    assert extract_recommendation_verdict(body) == "DEFER"
