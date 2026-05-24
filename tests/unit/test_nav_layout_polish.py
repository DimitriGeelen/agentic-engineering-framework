"""T-2033: arc-007 nav-layout polish — static guards for the sidebar/rail fixes.

Four defects were found reviewing the T-2011 nav-layout slice in the sidebar + icon-rail
layouts (the topbar default never exposed them):

  F1  rail group flyouts were clipped (rail nav had overflow-y:auto, which forces
      overflow-x to compute to auto → the absolute flyout was clipped to nothing).
  F2  margin-left offset on full-width children → permanent horizontal scrollbar.
  F3  empty hamburger + pins <li>s reserved ~56px each → 158px dead gap under the logo.
  F4a presets carried a `nav` axis (cross-axis coupling → horizontal page jump).
  F4b per-preset webfonts (font-display:swap) were never preloaded → font-swap reflow.

These are STATIC guards (template/source text). The computed-layout behaviour (flyout
visible, no horizontal scroll, tight gap) is proven in the Playwright sibling
(tests/playwright/test_nav_layout_polish.py) — element-presence is not the sole check (T-1575).
"""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / "web" / "templates" / "base.html"
APPEARANCE = ROOT / "web" / "templates" / "appearance.html"


# ── F4a: presets no longer carry a nav layout ──────────────────────────────
def test_f4a_presets_carry_no_nav_key():
    import sys
    sys.path.insert(0, str(ROOT))
    from web.blueprints.settings import PRESETS, DEFAULT_APPEARANCE

    assert PRESETS, "no presets defined"
    for pid, p in PRESETS.items():
        assert "nav" not in p, f"preset {pid!r} still carries a nav key (F4a regression)"
    # nav remains a real independent axis — the default still has one.
    assert DEFAULT_APPEARANCE.get("nav") == "topbar", "default nav axis lost"


def test_f4a_resolve_does_not_pull_nav_from_preset():
    import sys
    sys.path.insert(0, str(ROOT))
    from web.blueprints import settings as S

    # A preset is applied, but the posted nav must survive (independent axis).
    out = S._sanitise_appearance({"preset": "console", "nav": "sidebar"})
    assert out["nav"] == "sidebar", "posted nav was overridden by preset (F4a)"
    out2 = S._sanitise_appearance({"preset": "console", "nav": "rail"})
    assert out2["nav"] == "rail", "preset must not dictate nav"
    # palette/type/density/mode still come from the preset.
    assert out["palette"] == "console"


def test_f4a_preset_buttons_have_no_data_nav():
    txt = APPEARANCE.read_text()
    # The preset button block must not emit data-nav (the JS would re-apply it).
    preset_block = re.search(r'<button class="wt-preset".*?>', txt, re.DOTALL)
    assert preset_block, "preset button not found"
    assert "data-nav" not in preset_block.group(0), "preset button still emits data-nav (F4a)"
    # The preset-click handler must not mutate state.nav.
    assert "state.nav     = btn.dataset.nav" not in txt, "preset click still sets state.nav (F4a)"
    assert "btn.dataset.nav" not in txt, "preset still reads dataset.nav (F4a)"


# ── F1: rail nav must not be a scroll container (so flyouts escape) ─────────
def test_f1_rail_nav_overflow_visible():
    txt = BASE.read_text()
    m = re.search(r'html\[data-wt-nav="rail"\]\s+nav\.site-nav\s*\{[^}]*\}', txt)
    assert m, "rail nav rule not found"
    rule = m.group(0)
    assert "overflow: visible" in rule, "rail nav must be overflow:visible so flyouts escape (F1)"
    assert "overflow-y: auto" not in rule, "rail nav overflow-y:auto re-clips flyouts (F1 regression)"


# ── F2: content offset via body padding (+ root x-clip), not margin-left ────
def test_f2_offset_uses_body_padding_not_margin_left():
    txt = BASE.read_text()
    assert re.search(r'html\[data-wt-nav="sidebar"\]\s+body\s*\{\s*padding-left:\s*232px', txt), \
        "sidebar must offset via body padding-left (F2)"
    assert re.search(r'html\[data-wt-nav="rail"\]\s+body\s*\{\s*padding-left:\s*60px', txt), \
        "rail must offset via body padding-left (F2)"
    # the old margin-left offset (the bug) must be gone
    assert "margin-left: 232px" not in txt, "old sidebar margin-left offset still present (F2 regression)"
    assert "margin-left: 60px" not in txt, "old rail margin-left offset still present (F2 regression)"
    # root x-clip suppresses the residual sub-pixel scroll
    assert "overflow-x: clip" in txt, "root overflow-x:clip missing (F2 residual)"


# ── F3: mobile hamburger + empty pins rows hidden in the column ─────────────
def test_f3_filler_rows_hidden_in_column():
    txt = BASE.read_text()
    assert "li:has(> .nav-toggle)" in txt, "hamburger row not hidden in sidebar/rail (F3)"
    assert "li:has(> .nav-pins)" in txt, "empty pins row not hidden in sidebar/rail (F3)"
    assert "li:has(.nav-pin)" in txt, "pins row not re-shown when a pin exists (F3)"
    # the forbidden nested-:has form (which silently dropped the whole rule) must be gone
    assert ":has(> .nav-pins:not(:has(" not in txt, "nested :has() inside :has() (invalid, drops rule)"


# ── F5: sidebar accordion honours [open] + lifts open list above the summary ─
def test_f5_sidebar_accordion_open_state_and_stacking():
    txt = BASE.read_text()
    assert "details.dropdown:not([open]) > ul { display: none; }" in txt, \
        "closed sidebar group not collapsed off [open] (F5)"
    # the open list must be lifted into its own stacking context above the summary
    m = re.search(r'details\.dropdown\[open\] > ul \{[^}]*\}', txt)
    assert m, "open sidebar group ul rule not found (F5)"
    assert "z-index: 2" in m.group(0), "open sidebar list not lifted above summary (F5)"
    assert re.search(r'details\.dropdown > summary \{[^}]*z-index: 1', txt), \
        "summary not given a lower stacking index (F5)"


# ── F4b: all type-pairing webfonts preloaded ───────────────────────────────
def test_f4b_webfonts_preloaded():
    txt = BASE.read_text()
    fonts_dir = ROOT / "web" / "static" / "fonts"
    expected = [f.stem for f in fonts_dir.glob("*.woff2")]
    assert expected, "no webfonts on disk to preload"
    # the preload loop must enumerate every on-disk font family-weight
    for stem in expected:
        assert stem in txt, f"webfont {stem} not in the base.html preload list (F4b)"
    assert 'rel="preload" as="font"' in txt, "no font preload links emitted (F4b)"


# ── templates still compile ────────────────────────────────────────────────
def test_templates_compile():
    import sys
    sys.path.insert(0, str(ROOT))
    from web.app import app
    app.jinja_env.get_template("base.html")
    app.jinja_env.get_template("appearance.html")
