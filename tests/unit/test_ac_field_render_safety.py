"""T-3369: AC field rendering — escaped input, un-escaped output.

`_parse_ac_body` returns RENDERED HTML (it runs `_render_md_inline` /
`_render_md_block`, which linkify paths, task refs and URLs). A template that
interpolates those values as bare `{{ … }}` lets Jinja autoescape them a second
time, so the operator sees literal markup — `&lt;a href="/file/…"&gt;` — on the
review-handoff surface.

Two halves, and each is worthless without the other:

  * the values must be marked `| safe` in every template that renders them, or
    the markup shows through; and
  * the renderer must make them safe to mark, or `| safe` is an XSS hole.

A test asserting only the first would be satisfied by an XSS hole. A test
asserting only the second would be satisfied by reverting the fix.

Origin: found while live-verifying T-3368 on the running Watchtower. Three
templates render these fields; `_review_acs.html` had `| safe` on all three and
the other two had it on none — a silent 6-site divergence, invisible because
escaping only shows when the content CONTAINS markup, which only happens when a
linkifier fires, which only happens for paths that exist on disk.
"""

from __future__ import annotations

import re
from pathlib import Path

import pytest

from web.blueprints.tasks import _render_md_inline, _render_md_block

_REPO = Path(__file__).resolve().parents[2]

# Tags the framework's own renderer is allowed to emit.
_TRUSTED_TAGS = {"a", "code", "p", "strong", "em", "ul", "ol", "li", "br"}
_REAL_TAG = re.compile(r"<[^>]*>")   # only matches UNESCAPED markup

_PAYLOADS = [
    "<script>alert(1)</script>",
    "<img src=x onerror=alert(1)>",
    '<a href="javascript:alert(1)">click</a>',
    "<svg/onload=alert(1)>",
    "</p><script>x</script><p>",
    '<a href="data:text/html,<script>alert(1)</script>">x</a>',
]


def _audit(html: str):
    """Untrusted tag names and dangerous attributes among REAL tags only.

    Deliberately parses tags before inspecting attributes. Grepping the whole
    string for `onerror=` or `javascript:` reports danger that is not there —
    `safe_mode='escape'` escapes `<` and `>` but not quotes, so those substrings
    survive *inside inert text*. That false positive is the same
    text-instead-of-structure mistake as the T-3368 bug this test neighbours.
    """
    untrusted, dangerous = set(), []
    for tag in _REAL_TAG.findall(html):
        m = re.match(r"<\s*/?\s*([A-Za-z][A-Za-z0-9]*)", tag)
        if m and m.group(1).lower() not in _TRUSTED_TAGS:
            untrusted.add(m.group(1).lower())
        for href in re.findall(r'href="([^"]*)"', tag):
            if href.lower().startswith(("javascript:", "data:", "vbscript:")):
                dangerous.append(href)
        if re.search(r"\bon[a-z]+\s*=", tag, re.I):
            dangerous.append(tag)
    return untrusted, dangerous


@pytest.mark.parametrize("payload", _PAYLOADS)
@pytest.mark.parametrize("render", [_render_md_inline, _render_md_block])
def test_ac_field_renderer_makes_markup_inert(render, payload):
    """Half one: `| safe` is only legitimate because the renderer escapes."""
    untrusted, dangerous = _audit(render(payload))
    assert not untrusted, f"live tag(s) {sorted(untrusted)} from {payload!r}"
    assert not dangerous, f"dangerous attribute(s) {dangerous} from {payload!r}"


def test_ac_field_renderer_still_emits_real_anchors():
    """…and the escaping must not cost the feature it exists alongside."""
    out = _render_md_inline("see `web/shared.py`")
    assert '<a href="/file/web/shared.py">' in out
    assert out.count("<a ") == 1, f"expected exactly one anchor: {out!r}"


# --- Half two: every template that renders these fields marks them safe -----

_AC_TEMPLATES = (
    "web/templates/task_detail.html",
    "web/templates/_approvals_content.html",
    "web/templates/_review_acs.html",
)

# Matches an AC field interpolated WITHOUT `| safe`. Written as an absence
# assertion so it survives re-indentation and re-ordering — unlike a pin on the
# exact line, which is what let these three templates drift apart unnoticed.
_UNSAFE_INTERP = re.compile(
    r"\{\{\s*(?:step|ac\.steps|ac\.expected|ac\.if_not)\s*\}\}"
)


@pytest.mark.parametrize("template", _AC_TEMPLATES)
def test_ac_fields_are_marked_safe_in_every_template(template):
    """Parity across siblings — the actual root cause was divergence.

    `_review_acs.html` was correct and the other two were not, for long enough
    that nobody noticed. Checking one template would not have caught it; checking
    that NO template interpolates these fields unsafely does.
    """
    src = (_REPO / template).read_text()
    offenders = _UNSAFE_INTERP.findall(src)
    assert not offenders, (
        f"{template} renders AC field(s) {offenders} without `| safe` — "
        "already-rendered HTML will be escaped and shown as literal markup"
    )
