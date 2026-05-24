"""T-2032: the top-bar action cluster has a gear link to the settings/appearance page.

The bug: /settings/appearance (shipped by T-1988) was reachable only by typing the URL —
NAV_GROUPS has no /settings/* entry and the action cluster (search + theme toggle) had no
settings link. This pins the affordance: base.html must carry an <li class="nav-settings">
whose <a> targets the settings.appearance_page route and shows a gear <svg>. The rendered/
clicked behaviour is proven in the Playwright sibling test (T-1575: not grep-only for the UI).
"""

from __future__ import annotations

import re
from pathlib import Path

BASE = Path(__file__).resolve().parents[2] / "web" / "templates" / "base.html"


def _settings_li() -> str:
    txt = BASE.read_text()
    m = re.search(r'<li class="nav-settings">.*?</li>', txt, re.DOTALL)
    assert m, "could not find <li class=\"nav-settings\"> in base.html"
    return m.group(0)


def test_nav_settings_link_targets_appearance_route():
    li = _settings_li()
    assert "url_for('settings.appearance_page')" in li, (
        f"gear link must target settings.appearance_page; got: {li}"
    )


def test_nav_settings_has_gear_svg():
    li = _settings_li()
    assert "<svg" in li and "</svg>" in li, "gear link must contain an <svg> icon"
    # the feather gear has a central circle r=3 — a cheap structural signature
    assert 'r="3"' in li, "gear svg signature (central circle r=3) missing"


def test_nav_settings_is_anchor_not_button():
    # T-2031 lesson: <button> re-derives --pico-color to white and vanishes on light
    # palettes. The settings affordance must be an <a> so the shared --wt-text colour holds.
    li = _settings_li()
    assert "<a " in li, "settings affordance must be an <a>, not a <button>"
    assert "<button" not in li, "settings affordance must not be a <button>"


def test_settings_route_registered():
    import sys
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
    from web.app import app
    endpoints = {r.endpoint for r in app.url_map.iter_rules()}
    assert "settings.appearance_page" in endpoints, "settings.appearance_page route missing"


def test_base_template_compiles():
    import sys
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
    from web.app import app
    app.jinja_env.get_template("base.html")
