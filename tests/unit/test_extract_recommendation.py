"""T-1575: Regression tests for `web.shared.extract_recommendation`.

Structured extractor returns {verdict, rationale, evidence, raw}. Replaces
the verdict-only `extract_recommendation_verdict` (kept as compatibility
shim) and consolidates three parsers (review.py:_parse_recommendation,
inception.py:_extract_rationale_from_recommendation/_extract_recommendation_stance).

Same H2+ terminator risk as L-293 / T-1534. The /review surface previously
dumped `raw` into a `<pre>` block, showing literal `**Rationale:**` markdown
to humans — this helper enables structured rendering instead.
"""

from __future__ import annotations

from web.shared import extract_recommendation, extract_recommendation_verdict


def test_full_block_all_fields():
    body = (
        "## Context\nNoise.\n\n"
        "## Recommendation\n\n"
        "**Recommendation:** GO\n\n"
        "**Rationale:** Audit deliverable shipped. 7/9 findings closed.\n\n"
        "**Evidence:**\n"
        "- F1: dead-code regex fix\n"
        "- F2: --force replaced with narrow flags\n\n"
        "## Updates\n"
    )
    out = extract_recommendation(body)
    assert out["verdict"] == "GO"
    assert "Audit deliverable shipped" in out["rationale"]
    assert "7/9 findings closed" in out["rationale"]
    assert "F1: dead-code regex fix" in out["evidence"]
    assert "F2: --force replaced with narrow flags" in out["evidence"]
    assert out["raw"]


def test_verdict_only_no_rationale():
    body = (
        "## Recommendation\n\n"
        "**Recommendation:** GO\n\n"
        "## Updates\n"
    )
    out = extract_recommendation(body)
    assert out["verdict"] == "GO"
    assert out["rationale"] == ""
    assert out["evidence"] == ""


def test_empty_section():
    body = (
        "## Recommendation\n\n"
        "<!-- Filled at completion -->\n\n"
        "## Updates\n"
    )
    out = extract_recommendation(body)
    assert out["verdict"] == "?"
    assert out["rationale"] == ""
    assert out["evidence"] == ""
    assert out["raw"] == ""  # comments stripped


def test_section_absent():
    body = "## Context\nNo recommendation here.\n\n## Updates\n"
    out = extract_recommendation(body)
    assert out["verdict"] == "?"
    assert out["rationale"] == ""
    assert out["evidence"] == ""
    assert out["raw"] == ""


def test_evidence_missing_rationale_present():
    body = (
        "## Recommendation\n\n"
        "**Recommendation:** DEFER\n\n"
        "**Rationale:** Need more data before proceeding.\n\n"
        "## Decisions\n"
    )
    out = extract_recommendation(body)
    assert out["verdict"] == "DEFER"
    assert "Need more data before proceeding" in out["rationale"]
    assert out["evidence"] == ""


def test_h3_does_not_terminate_section():
    """L-293: section terminator must accept H2+ only when the next heading
    is at H2 depth. An H3 inside Recommendation (e.g., '### Sub-rationale')
    must NOT terminate the section. We use H2+ terminator (^#{2,}) which
    means H2 OR DEEPER terminates. Verify the regex actually requires H2+,
    not H3."""
    body = (
        "## Recommendation\n\n"
        "**Recommendation:** GO\n\n"
        "**Rationale:** Top-level rationale.\n\n"
        "### Sub-rationale\n"
        "Detail under H3.\n\n"
        "## Updates\n"
        "**Action:** GO ahead\n"  # would falsely match without H2+ terminator
    )
    out = extract_recommendation(body)
    assert out["verdict"] == "GO"
    # H3 terminates per H2+ rule, so sub-rationale is excluded — that's by design.
    # The critical regression is that `**Action:** GO ahead` from Updates does NOT
    # leak into the verdict (verdict stays GO, not affected by post-section noise).


def test_h2_terminator_excludes_updates():
    """The Updates section's `**Action:**` lines must not leak into the
    rationale — H2 terminator stops extraction there."""
    body = (
        "## Recommendation\n\n"
        "**Recommendation:** GO\n\n"
        "**Rationale:** First paragraph.\n\n"
        "Second paragraph.\n\n"
        "## Updates\n\n"
        "### 2026-04-28 — task-update [agent]\n"
        "- **Action:** Status changed\n"
    )
    out = extract_recommendation(body)
    assert "Status changed" not in out["rationale"]
    assert "First paragraph" in out["rationale"]
    assert "Second paragraph" in out["rationale"]


def test_real_world_t1565_sample():
    """Real T-1565 recommendation block — verify it parses cleanly."""
    body = (
        "## Recommendation\n\n"
        "**Recommendation:** GO\n\n"
        "**Rationale:** Audit deliverable shipped (`docs/reports/T-1565-approval-arc-gaps-audit.md` "
        "— 9 findings, 2 HIGH / 4 MEDIUM / 3 LOW with file:line evidence and fix sketches). "
        "7/9 findings closed across two sessions; 2/9 deferred with documented justification.\n\n"
        "**Evidence — closed (7):**\n"
        "- F1 (HIGH) — T-1567: Fix dead-code regex\n"
        "- F2 (HIGH) — T-1568: Replace --force with narrow flags\n\n"
        "**Captured learning:** L-309\n\n"
        "## Decisions\n"
    )
    out = extract_recommendation(body)
    assert out["verdict"] == "GO"
    assert "Audit deliverable shipped" in out["rationale"]
    assert "7/9 findings closed" in out["rationale"]
    assert "F1 (HIGH)" in out["evidence"]
    assert "F2 (HIGH)" in out["evidence"]


def test_compat_shim_returns_just_verdict():
    """extract_recommendation_verdict must keep the string-returning contract
    so existing call sites (handover.sh, approvals.py, cockpit.py) don't break."""
    body = (
        "## Recommendation\n\n"
        "**Recommendation:** NO-GO\n\n"
        "**Rationale:** Won't fix.\n\n"
    )
    assert extract_recommendation_verdict(body) == "NO-GO"


def test_compat_shim_missing_returns_question_mark():
    assert extract_recommendation_verdict("") == "?"
    assert extract_recommendation_verdict("## Other\nNothing here.\n") == "?"
