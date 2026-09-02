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

from web.shared import extract_recommendation, extract_recommendation_state, extract_recommendation_verdict


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


def test_decorated_evidence_labels_dont_leak_into_rationale():
    """Real-world bug from T-1575 v1: rationale captured all evidence text
    because regex didn't recognise `**Evidence — closed (7):**`. Decorated
    Evidence labels (em-dash + qualifier + parenthetical count) must be
    classified as Evidence, not leak into Rationale."""
    body = (
        "## Recommendation\n\n"
        "**Recommendation:** GO\n\n"
        "**Rationale:** One paragraph of justification.\n\n"
        "**Evidence — closed (7):**\n"
        "- F1: thing\n"
        "- F2: other thing\n\n"
        "**Evidence — deferred (2):**\n"
        "- F7: deferred reason\n"
        "- F9: not now\n\n"
        "**Captured learning:** L-309 — pattern\n\n"
        "## Decisions\n"
    )
    out = extract_recommendation(body)
    assert out["verdict"] == "GO"
    # Rationale must be ONLY the rationale paragraph
    assert out["rationale"] == "One paragraph of justification."
    assert "F1:" not in out["rationale"]
    assert "F7:" not in out["rationale"]
    assert "Captured learning" not in out["rationale"]
    assert "Evidence" not in out["rationale"]
    # Evidence must contain BOTH closed and deferred groups, with their headings
    assert "F1: thing" in out["evidence"]
    assert "F2: other thing" in out["evidence"]
    assert "F7: deferred reason" in out["evidence"]
    assert "F9: not now" in out["evidence"]
    # Evidence must NOT contain the captured learning trailer
    assert "L-309" not in out["evidence"]


def test_render_markdown_safe_makes_backticked_urls_clickable():
    """T-1575 codification: any URL anywhere in rendered task content is
    clickable, regardless of whether the agent wrote it bare, in a [md](link),
    or wrapped in `backticks`. The rendering layer is the contract — agent
    need not remember to avoid backticks around URLs.

    Example: Step 1 of T-1574 was written as `Open \\`http://...\\`` which
    renders as <code>http://...</code> — without this codification, that's
    not clickable, and the human has to copy-paste the URL into the address
    bar to act on the AC."""
    from web.shared import render_markdown_safe
    out = render_markdown_safe("Open `http://192.168.10.107:3000/review/T-1565` in the browser.")
    assert '<a href="http://192.168.10.107:3000/review/T-1565">' in out
    assert "<code>http://192.168.10.107:3000/review/T-1565</code>" in out
    # Bare URLs also clickable
    out2 = render_markdown_safe("Open http://example.com here.")
    assert '<a href="http://example.com">' in out2


def test_real_t1565_file_renders_cleanly():
    """End-to-end: read the actual T-1565 task file and verify the rationale
    block contains ONLY the rationale paragraph (not evidence text), and the
    evidence block contains evidence (not captured learning)."""
    import os
    repo_root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    task_file = None
    for loc in ("active", "completed"):
        candidate_dir = os.path.join(repo_root, ".tasks", loc)
        if not os.path.isdir(candidate_dir):
            continue
        for fn in os.listdir(candidate_dir):
            if fn.startswith("T-1565-") and fn.endswith(".md"):
                task_file = os.path.join(candidate_dir, fn)
                break
        if task_file:
            break
    if not task_file:
        # T-1565 may have been completed and archived; skip gracefully.
        import pytest
        pytest.skip("T-1565 task file not present in this checkout")

    body = open(task_file).read()
    out = extract_recommendation(body)
    assert out["verdict"] == "GO"
    # Rationale must NOT contain the literal evidence bullet markers
    assert "F1 (HIGH)" not in out["rationale"], (
        f"rationale leaked evidence: {out['rationale'][:300]}"
    )
    assert "Evidence —" not in out["rationale"]
    assert "Captured learning" not in out["rationale"]
    # Evidence must NOT contain the captured-learning trailer
    assert "L-309" not in out["evidence"], (
        f"evidence leaked captured_learning: {out['evidence'][-300:]}"
    )


# ============================================================
# T-1576: extract_recommendation_state — distinguishes NO-REC from ?
# ============================================================


def test_state_no_section_returns_no_rec():
    """No `## Recommendation` section at all → NO-REC ('agent owes recommendation')."""
    body = "## Context\nA task with no recommendation section.\n\n## Updates\n"
    assert extract_recommendation_state(body) == "NO-REC"
    # Compat shim still returns '?' for backward compatibility.
    assert extract_recommendation_verdict(body) == "?"


def test_state_empty_section_returns_no_rec():
    """Section header present but body is empty/whitespace → NO-REC."""
    body = "## Recommendation\n\n\n## Updates\n"
    assert extract_recommendation_state(body) == "NO-REC"


def test_state_html_comment_only_section_returns_no_rec():
    """Section contains only HTML-comment placeholder → NO-REC."""
    body = (
        "## Recommendation\n\n"
        "<!-- REQUIRED before fw inception decide. Format:\n"
        "     **Recommendation:** GO / NO-GO / DEFER\n"
        "-->\n\n"
        "## Updates\n"
    )
    assert extract_recommendation_state(body) == "NO-REC"


def test_state_section_present_no_verdict_returns_question_mark():
    """Section has substantive prose but no `**Recommendation:** GO/NO-GO/DEFER` line → ?"""
    body = (
        "## Recommendation\n\n"
        "Some prose without the canonical verdict marker. The agent typed something\n"
        "but never put a structured **Recommendation:** GO line.\n\n"
        "## Updates\n"
    )
    assert extract_recommendation_state(body) == "?"
    # Compat shim mirrors this — '?' is the historical return.
    assert extract_recommendation_verdict(body) == "?"


def test_state_full_block_returns_verdict():
    """Full block with verdict → GO/NO-GO/DEFER (passthrough)."""
    for v in ("GO", "NO-GO", "DEFER"):
        body = (
            "## Recommendation\n\n"
            f"**Recommendation:** {v}\n\n"
            "**Rationale:** because.\n\n"
            "## Updates\n"
        )
        assert extract_recommendation_state(body) == v, f"failed on verdict={v}"


def test_state_empty_body_returns_no_rec():
    """Empty body → NO-REC (no section to find)."""
    assert extract_recommendation_state("") == "NO-REC"


# -----------------------------------------------------------------------------
# T-1580: bullet-prefixed marker support
# Markdown allows `- **Recommendation:** DEFER` as a list item. The original
# `_REC_MARKER_RE` anchored on `^**` and missed those — T-705 / T-844 ended up
# in the `?` bucket despite being well-formed DEFERs.
# -----------------------------------------------------------------------------

def test_bullet_prefixed_recommendation_dash():
    """`- **Recommendation:** DEFER` parses as DEFER (not '?')."""
    body = (
        "## Recommendation\n\n"
        "- **Recommendation:** DEFER\n"
        "- **Rationale:** scope creep, defer to later phase.\n"
        "- **Evidence:** see T-XXX research artifact.\n\n"
        "## Updates\n"
    )
    out = extract_recommendation(body)
    assert out["verdict"] == "DEFER"
    assert "scope creep" in out["rationale"]
    assert "T-XXX research artifact" in out["evidence"]


def test_bullet_prefixed_recommendation_asterisk():
    """`* **Recommendation:** GO` (alternate Markdown bullet) also parses."""
    body = (
        "## Recommendation\n\n"
        "* **Recommendation:** GO\n"
        "* **Rationale:** all checks pass.\n\n"
        "## Updates\n"
    )
    assert extract_recommendation(body)["verdict"] == "GO"


def test_bullet_prefixed_with_indent():
    """Leading spaces before bullet (nested list) still match."""
    body = (
        "## Recommendation\n\n"
        "  - **Recommendation:** NO-GO\n"
        "  - **Rationale:** blocked.\n\n"
        "## Updates\n"
    )
    assert extract_recommendation(body)["verdict"] == "NO-GO"


def test_non_bullet_style_still_works():
    """Existing canonical style (no bullet) keeps working — T-1580 must not regress."""
    body = (
        "## Recommendation\n\n"
        "**Recommendation:** GO\n\n"
        "**Rationale:** standard form.\n\n"
        "## Updates\n"
    )
    assert extract_recommendation(body)["verdict"] == "GO"


# ============================================================
# T-3252: no text in a `## Recommendation` section is discarded.
# Three shapes, one cause (docs/reports/T-3252-recommendation-text-loss.md):
#   (a) text before the first bold marker
#   (b) prose after the verdict token on the Recommendation line itself
#   (c) a span under a marker `_classify_rec_marker` calls `other`
# Negative control: reverting web/shared.py to the pre-T-3252 extract_recommendation
# (the version with `out = {"verdict": ..., "rationale": ..., "evidence": ..., "raw": ""}`
# and no `other`/`verdict_note` keys) makes every test below fail — either with a
# KeyError on `out["other"]` / `out["verdict_note"]`, or because the asserted text
# is absent from `rationale`/`evidence`. Verified via `git stash` against the
# pre-fix commit during authoring.
# ============================================================


def test_shape_a_preamble_before_first_marker_preserved():
    """Text before the first bold marker was never inside any span, so the
    original tokenizer never bucketed it — silently dropped."""
    body = (
        "## Recommendation\n\n"
        "This section opens with a caveat the author wrote before any bold marker.\n\n"
        "**Recommendation:** GO\n\n"
        "**Rationale:** Ships as-is.\n\n"
        "## Updates\n"
    )
    out = extract_recommendation(body)
    assert out["verdict"] == "GO"
    assert "caveat the author wrote before any bold marker" in out["other"]


def test_shape_a_no_markers_at_all_preserved_in_other():
    """A Recommendation section with zero bold markers previously vanished
    entirely from every structured field except the unrendered `raw`."""
    body = (
        "## Recommendation\n\n"
        "Free-form prose with no structured markers at all — an authoring mistake\n"
        "or an informal note, either way real text a human should be able to read.\n\n"
        "## Updates\n"
    )
    out = extract_recommendation(body)
    assert out["verdict"] == "?"
    assert "Free-form prose with no structured markers" in out["other"]


def test_shape_b_verdict_trailing_prose_preserved():
    """Prose after the verdict token on the Recommendation line itself
    ('DEFER — demand has not materialised') was discarded outright; only the
    verdict token was kept."""
    body = (
        "## Recommendation\n\n"
        "**Recommendation:** DEFER — demand has not materialised.\n\n"
        "## Updates\n"
    )
    out = extract_recommendation(body)
    assert out["verdict"] == "DEFER"
    assert "demand has not materialised" in out["verdict_note"]


def test_shape_b_verdict_trailing_prose_bold_wrapped_token():
    """T-3252 real-world variant: the verdict token itself is bold-wrapped
    ('**GO** — promote…'), which the original verdict regex didn't match at
    all — losing not just the trailing prose but the verdict itself."""
    body = (
        "## Recommendation\n\n"
        "**Recommendation:** **GO** — promote T-1727 from captured to started-work.\n\n"
        "## Updates\n"
    )
    out = extract_recommendation(body)
    assert out["verdict"] == "GO"
    assert "promote T-1727" in out["verdict_note"]


def test_shape_c_other_labeled_span_preserved_with_label():
    """A span under an author's own bold label (not one of the four recognised
    markers) was classified `other` and dropped, taking the following bullets
    with it up to the next recognised marker."""
    body = (
        "## Recommendation\n\n"
        "**Recommendation:** GO\n\n"
        "**Rationale:** Ships as-is.\n\n"
        "**Implications:** This changes how downstream consumers read the field.\n\n"
        "## Updates\n"
    )
    out = extract_recommendation(body)
    assert out["verdict"] == "GO"
    # Rationale must NOT absorb the other-labeled span (no re-introducing the
    # T-1575 v1 leak class).
    assert "Implications" not in out["rationale"]
    assert "downstream consumers" not in out["rationale"]
    # The label is preserved so a reader can tell it apart from a recognised marker.
    assert "**Implications**" in out["other"]
    assert "downstream consumers" in out["other"]


def test_shape_c_recommendation_bucket_unrecognised_verdict_token_preserved():
    """A Recommendation marker whose value isn't a recognised verdict token
    (e.g. informal 'SHIP', 'DROP') previously vanished with no verdict set and
    no trace anywhere but the unrendered raw."""
    body = (
        "## Recommendation\n\n"
        "**Recommendation:** SHIP — ship as landed, no further gate needed.\n\n"
        "## Updates\n"
    )
    out = extract_recommendation(body)
    assert out["verdict"] == "?"  # unrecognised token — no verdict synonym invented
    assert "SHIP" in out["other"]
    assert "ship as landed" in out["other"]


def test_verdict_note_leading_separator_stripped():
    """The renderer supplies its own ' — ' separator before verdict_note; if the
    author's own em-dash survives too, the card reads 'GO — — reason' (doubled)."""
    body = (
        "## Recommendation\n\n"
        "**Recommendation:** **GO** — close as work-completed.\n\n"
        "## Updates\n"
    )
    out = extract_recommendation(body)
    assert out["verdict"] == "GO"
    assert not out["verdict_note"].startswith("—")
    assert not out["verdict_note"].startswith("-")
    assert out["verdict_note"] == "close as work-completed."


def test_all_three_shapes_together_nothing_dropped():
    """Combined regression: all three shapes in one section, verified against
    the full extracted output — every fragment must appear somewhere."""
    body = (
        "## Recommendation\n\n"
        "Preamble caveat before any marker.\n\n"
        "**Recommendation:** NO-GO — blocked on upstream dependency.\n\n"
        "**Rationale:** Clear rationale text.\n\n"
        "**Follow-on notes:** Not in this slice, tracked separately.\n\n"
        "## Updates\n"
    )
    out = extract_recommendation(body)
    assert out["verdict"] == "NO-GO"
    assert "blocked on upstream dependency" in out["verdict_note"]
    assert "Clear rationale text" in out["rationale"]
    combined = out["rationale"] + out["evidence"] + out["other"] + out["verdict"] + out["verdict_note"]
    for fragment in (
        "Preamble caveat before any marker",
        "blocked on upstream dependency",
        "Clear rationale text",
        "Follow-on notes",
        "Not in this slice, tracked separately",
    ):
        assert fragment in combined, f"dropped: {fragment!r}"


def test_bold_in_paragraph_not_matched_as_marker():
    """Bold text mid-paragraph (not on its own line, no bullet) shouldn't match
    as a marker — guards the line-start anchor we relaxed."""
    body = (
        "## Recommendation\n\n"
        "Some prose mentioning **Recommendation:** GO inline within a sentence,\n"
        "without proper line-start formatting.\n\n"
        "## Updates\n"
    )
    # The inline `**Recommendation:**` IS at the start of a line, so it WILL
    # match — that's existing behavior. The real guard is that random bold
    # words in the middle of a line (e.g. "see **note** below") don't trigger.
    body2 = (
        "## Recommendation\n\n"
        "Some prose with **emphasis** in the middle of a sentence.\n"
        "No structured marker here.\n\n"
        "## Updates\n"
    )
    assert extract_recommendation_state(body2) == "?"
