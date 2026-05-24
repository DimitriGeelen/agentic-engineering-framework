"""T-2031: the dark-mode toggle uses --wt-text (palette text token), not --pico-color.

Root cause (see task RCA): .theme-toggle is a <button>, so Pico's button styling sets
--pico-color on it to the white accent-ink; with background:none that white icon vanished
on light surfaces (white-on-white in paper light). --wt-text always contrasts the surface
and is not overridden by Pico's button rule. This pins the fix so an edit can't silently
revert to --pico-color. Computed-contrast is proven in the Playwright sibling test.
"""

from __future__ import annotations

import re
from pathlib import Path

BASE = Path(__file__).resolve().parents[2] / "web" / "templates" / "base.html"


def _toggle_style() -> str:
    txt = BASE.read_text()
    m = re.search(r'<button class="theme-toggle".*?style="([^"]*)"', txt, re.DOTALL)
    assert m, "could not find .theme-toggle button inline style"
    return m.group(1)


def test_toggle_uses_wt_text_token():
    style = _toggle_style()
    assert "color:var(--wt-text)" in style, f"toggle should use --wt-text; got: {style}"


def test_toggle_does_not_use_pico_color():
    # --pico-color is overridden to white by Pico's button rule → the original bug.
    assert "color:var(--pico-color)" not in _toggle_style()


def test_base_template_compiles():
    import sys
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
    from web.app import app
    app.jinja_env.get_template("base.html")
