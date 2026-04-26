"""T-1527 regression: _decision_recorded_in_task must not over-capture
`### timestamp` Updates entries appended below `## Decision`.

Bug context: web/blueprints/inception.py:573 used a Decision-section regex
with H2-only terminator `(?=^## |\\Z)`. update-task.sh appends `### timestamp`
Updates entries to EOF; if the task lacks a trailing `## Updates` H2, those
H3s sat between Decision and EOF and were swallowed into the captured group.
A subsequent keyword check (`if decision.upper() in m.group(0).upper()`)
would then false-positive when an Updates entry incidentally contained the
keyword (e.g. `- **Action:** decided to go ahead`).

Same shape as T-1519 (verdict regex) and T-1526 (decide rewriter). Fix:
terminate at any H2-or-deeper heading using `(?=^#{2,} |\\Z)`.

This test mirrors the regex embedded in web/blueprints/inception.py — keep
it in sync if that regex evolves.
"""

from __future__ import annotations

import re


def _decision_keyword_present(body: str, decision: str) -> bool:
    """Mirror of web/blueprints/inception.py:_decision_recorded_in_task."""
    m = re.search(
        r"^## Decision\b.*?(?=^#{2,} |\Z)",
        body,
        re.MULTILINE | re.DOTALL,
    )
    return bool(m and decision.upper() in m.group(0).upper())


def test_decision_keyword_present_for_real_decision():
    body = (
        "## Recommendation\nGO\n\n"
        "## Decision\n**Decision**: GO\n**Rationale**: ok\n"
        "**Date**: 2026-04-27T01:00:00Z\n"
    )
    assert _decision_keyword_present(body, "go") is True


def test_decision_keyword_absent_when_only_in_appended_update():
    """Updates H3 below Decision must NOT contribute to the keyword match.

    Without the H2+ terminator fix, the `GO` keyword appearing in an Updates
    entry below a `DEFER`'d Decision would be captured into the Decision
    section content and falsely return True.
    """
    body = (
        "## Recommendation\nDEFER\n\n"
        "## Decision\n**Decision**: DEFER\n**Rationale**: needs more data\n\n"
        "### 2026-04-27T01:00:00Z — task-update [agent]\n"
        "- **Action:** decided to GO ahead with research artifact next\n"
    )
    # The real decision was DEFER. The H3 mention of GO must not satisfy the check.
    assert _decision_keyword_present(body, "go") is False
    assert _decision_keyword_present(body, "defer") is True


def test_decision_keyword_with_trailing_updates_h2_section():
    """When a `## Updates` H2 follows Decision, the H2 terminator works
    (and so does the H2+ terminator — confirms backward compat)."""
    body = (
        "## Decision\n**Decision**: NO-GO\n\n"
        "## Updates\n"
        "### 2026-04-27T01:00:00Z\n"
        "- **Action:** says GO somewhere\n"
    )
    assert _decision_keyword_present(body, "no-go") is True
    assert _decision_keyword_present(body, "go") is True  # NO-GO contains "GO"
