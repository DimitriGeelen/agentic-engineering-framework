"""T-4287: _ac_list.html must escape the raw-text fallback for Agent criteria.

The partial printed `(ac.text_html or ac.text) | safe`, so an includer that did not
set text_html would emit raw criterion text unescaped (832 OBS-319). text_html is
pre-sanitised HTML and stays safe; the ac.text fallback must be escaped.
"""

from __future__ import annotations

from pathlib import Path

from jinja2 import Environment, FileSystemLoader, select_autoescape

TEMPLATES = Path(__file__).resolve().parents[2] / "web" / "templates"


def _render(ac_items):
    env = Environment(loader=FileSystemLoader(str(TEMPLATES)),
                      autoescape=select_autoescape(["html"]))
    env.globals["csrf_token"] = lambda: "tok"
    return env.get_template("_ac_list.html").render(ac_items=ac_items, task_id="T-0000")


def test_fallback_text_without_text_html_is_escaped():
    out = _render([{"section": "agent", "checked": False, "line_idx": 1,
                    "text": "<script>alert(1)</script> criterion"}])
    assert "&lt;script&gt;alert(1)&lt;/script&gt; criterion" in out
    assert "<script>alert(1)" not in out


def test_text_html_still_renders_as_html():
    out = _render([{"section": "agent", "checked": False, "line_idx": 1,
                    "text": "`x`", "text_html": "<code>x</code>"}])
    assert "<code>x</code>" in out
