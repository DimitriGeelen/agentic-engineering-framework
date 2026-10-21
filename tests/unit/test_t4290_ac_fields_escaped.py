"""T-4290: Human-criterion Steps/Expected/If-not reach _ac_list.html through |safe.

The partial trusts those three fields as pre-sanitised HTML. They are produced by
web.blueprints.tasks._parse_ac_body (markdown2, safe_mode='escape', then link
post-processing). These tests drive the real producer and the real template with
hostile criterion bodies and assert nothing becomes live markup or an attribute.
"""

from __future__ import annotations

import re
import sys
from html.parser import HTMLParser
from pathlib import Path

import pytest
from jinja2 import Environment, FileSystemLoader, select_autoescape

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))

from web.blueprints.tasks import _parse_acceptance_criteria  # noqa: E402
from web.shared import render_markdown_safe  # noqa: E402

TEMPLATES = ROOT / "web" / "templates"

PAYLOADS = [
    "<script>alert(1)</script>",
    "<img src=x onerror=alert(1)>",
    "[x](javascript:alert(1))",
    '[a](http://x" onclick="alert(1))',
    '![i](x" onerror="alert(1))',
    '`http://x"onmouseover="alert(1)`',
    "`http://x'onmouseover='alert(1)`",
    '`http://x"><script>alert(1)</script>`',
]

class _Live(HTMLParser):
    """Collects what a browser would treat as live: tags, attribute names, URLs."""

    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.bad = []

    def handle_starttag(self, tag, attrs):
        if tag in ("script", "iframe", "object", "embed", "style"):
            self.bad.append(f"<{tag}>")
        for name, value in attrs:
            if name.startswith("on"):
                self.bad.append(f"{tag}[{name}]")
            if name in ("href", "src") and (value or "").strip().lower().startswith(
                    ("javascript:", "data:", "vbscript:")):
                self.bad.append(f"{tag}[{name}={value}]")

    handle_startendtag = handle_starttag


def _live(html: str) -> list:
    p = _Live()
    p.feed(html)
    p.close()
    return p.bad


def _render(body: str) -> str:
    acs = _parse_acceptance_criteria(body)
    env = Environment(loader=FileSystemLoader(str(TEMPLATES)),
                      autoescape=select_autoescape(["html"]))
    env.globals["csrf_token"] = lambda: "tok"
    return env.get_template("_ac_list.html").render(ac_items=acs, task_id="T-0000")


def _body(payload: str) -> str:
    return (
        "## Acceptance Criteria\n\n### Human\n"
        "- [ ] [REVIEW] criterion\n"
        f"  **Steps:**\n  1. Open {payload}\n"
        f"  **Expected:** {payload}\n"
        f"  **If not:** {payload}\n"
    )


@pytest.mark.parametrize("payload", PAYLOADS)
def test_hostile_steps_expected_ifnot_render_inert(payload):
    page = _render(_body(payload))
    # Judge only the field bodies: the partial's own tick form carries onclick/onchange.
    m = re.search(r'<div class="human-ac-body">(.*?)</div>', page, re.S)
    assert m, page
    out = m.group(1)
    assert "Steps" in out and "Expected" in out and "If not" in out
    assert _live(out) == [], out


@pytest.mark.parametrize("payload", PAYLOADS)
def test_render_markdown_safe_twin_inert(payload):
    # Same linkifier lives in web/shared.py for Recommendation/Rationale surfaces.
    out = str(render_markdown_safe(payload))
    assert _live(out) == [], out


def test_benign_markdown_still_renders():
    out = _render(_body("`http://example.com/x` and [doc](http://example.com/y)"))
    assert '<a href="http://example.com/x"><code>http://example.com/x</code></a>' in out
    assert '<a href="http://example.com/y">doc</a>' in out
