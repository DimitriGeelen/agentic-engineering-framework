"""T-1551: Regression tests for Markdown rendering in /review/T-XXX AC steps.

Origin: T-1548 surface friction — Human ACs that say "Open `docs/reports/T-XXX-*.md`"
showed `[label](url)` as literal text because Jinja escaped Markdown. Fix renders
through markdown2 with safe_mode='escape' before reaching the template.
"""
from __future__ import annotations

from web.blueprints.tasks import (
    _parse_ac_body,
    _render_md_inline,
    _render_md_block,
    _auto_link_task_refs,
)


# ---- T-1552: bare T-NNNN auto-linking ---------------------------------------

def test_bare_task_ref_linkified():
    out = _auto_link_task_refs("See T-1448 for context.")
    assert out == "See [T-1448](/tasks/T-1448) for context."


def test_already_linked_task_ref_unchanged():
    out = _auto_link_task_refs("See [T-1448](other-url) for context.")
    assert out == "See [T-1448](other-url) for context."


def test_task_ref_inside_inline_code_unchanged():
    out = _auto_link_task_refs("Run `bin/fw show T-1448` and check.")
    assert "`bin/fw show T-1448`" in out
    assert "[T-1448]" not in out


def test_too_many_digits_not_linkified():
    out = _auto_link_task_refs("Code T-9999999 should not link.")
    assert "[T-9999999]" not in out


def test_multiple_task_refs_in_one_step():
    out = _auto_link_task_refs("T-1548 → T-1549 → T-1550")
    assert "[T-1548](/tasks/T-1548)" in out
    assert "[T-1549](/tasks/T-1549)" in out
    assert "[T-1550](/tasks/T-1550)" in out


def test_render_step_with_bare_task_ref():
    html = _render_md_inline("See T-1448")
    assert '<a href="/tasks/T-1448">T-1448</a>' in html


def test_inline_markdown_link_rendered_to_anchor():
    html = _render_md_inline("Open [the report](docs/reports/T-1548.md)")
    assert '<a href="docs/reports/T-1548.md">the report</a>' in html
    # No <p> wrapper for inline use (will live inside <li>)
    assert not html.startswith('<p>')


def test_inline_markdown_strips_p_wrapper():
    html = _render_md_inline("plain text")
    assert html == "plain text"


def test_inline_markdown_renders_inline_code():
    html = _render_md_inline("Run `bin/fw doctor`")
    assert "<code>bin/fw doctor</code>" in html


def test_inline_markdown_renders_emphasis():
    html = _render_md_inline("**bold** text")
    assert "<strong>bold</strong>" in html


def test_inline_markdown_xss_blocked():
    html = _render_md_inline('<script>alert(1)</script>Hi')
    # Raw HTML must be escaped, not executed
    assert "<script>" not in html
    assert "&lt;script&gt;" in html
    assert "Hi" in html


def test_inline_markdown_empty_returns_empty():
    assert _render_md_inline("") == ""
    assert _render_md_inline(None) == ""


def test_block_markdown_keeps_p_wrapper():
    html = _render_md_block("expected outcome")
    assert html.startswith("<p>")
    assert html.endswith("</p>")


def test_parse_ac_body_renders_steps_as_html():
    body = """**Steps:**
1. Open [the report](docs/reports/X.md)
2. Run `bin/fw doctor`
**Expected:** Output shows `ok`
**If not:** Capture in [feedback-stream](.context/working/feedback-stream.yaml)
"""
    steps, expected, if_not = _parse_ac_body(body)
    assert len(steps) == 2
    assert '<a href="docs/reports/X.md">the report</a>' in steps[0]
    assert "<code>bin/fw doctor</code>" in steps[1]
    assert "<code>ok</code>" in expected
    assert 'feedback-stream' in if_not
    # T-1551: leading-dot relative paths are normalized to ./ for safe_mode
    assert 'href="./.context/working/feedback-stream.yaml"' in if_not


def test_parse_ac_body_plain_text_unaffected():
    body = """**Steps:**
1. Do thing
**Expected:** It works
**If not:** Try again
"""
    steps, expected, if_not = _parse_ac_body(body)
    assert steps == ["Do thing"]
    assert "It works" in expected
    assert "Try again" in if_not


def test_parse_ac_body_xss_in_step_blocked():
    body = """**Steps:**
1. <script>alert(1)</script>
"""
    steps, expected, if_not = _parse_ac_body(body)
    assert "<script>" not in steps[0]
    assert "&lt;script&gt;" in steps[0]
