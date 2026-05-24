"""T-2024 (arc-007 S3a2): cockpit inline-style hexes use per-palette semantic tokens.

S3a (T-2023) tokenised the named status classes (.wt-badge-*, .wt-queue-status.*).
This slice covers the remaining *inline-style* theme hexes — card accent borders,
the action-summary card + count colours, the five verdict pills, the Strength line,
the concerns counts, the stale-tasks line, and the Risks heading — so the whole
cockpit honours the selected palette.

The only hexes that may remain are #fff / #1a1a1a — text contrast foregrounds on
token-coloured backgrounds (deliberately not palette colours). The per-palette
re-theming itself is proven in tests/playwright/test_cockpit_inline_tokens.py; the
contrast/taste check is the Human [REVIEW] AC.
"""

from __future__ import annotations

import re
from pathlib import Path

TEMPLATE = Path(__file__).resolve().parents[2] / "web" / "templates" / "cockpit.html"


def _css() -> str:
    return TEMPLATE.read_text()


def test_card_accent_borders_use_tokens():
    css = _css()
    assert ".wt-card-amber { border-left-color:var(--wt-warn)" in css
    assert ".wt-card-blue { border-left-color:var(--wt-info)" in css
    assert ".wt-card-green { border-left-color:var(--wt-success)" in css
    assert ".wt-card-red { border-left-color:var(--wt-danger)" in css
    # old fixed hexes gone from the card rules
    assert "border-left-color:#f9a825" not in css
    assert "border-left-color:#1565c0" not in css
    assert "border-left-color:#2e7d32" not in css
    assert "border-left-color:#c62828" not in css


def test_action_summary_counts_use_tokens():
    css = _css()
    # card accent + the three count colours
    assert "border-left: 3px solid var(--wt-warn)" in css
    assert "color:var(--wt-warn);\">{{ action_summary.tier0_count }}" in css
    assert "color:var(--wt-info);\">{{ action_summary.go_count }}" in css
    assert "color:var(--wt-accent);\">{{ action_summary.human_ac_count }}" in css
    for gone in ("#f59e0b", "#7c3aed"):
        assert gone not in css, f"stale action-summary hex {gone} still present"


def test_verdict_pills_use_semantic_tokens():
    css = _css()
    assert "background:var(--wt-success); color:#fff" in css  # GO
    assert "background:var(--wt-warn); color:#1a1a1a" in css   # DEFER (dark text on light warn)
    assert "background:var(--wt-danger); color:#fff" in css    # NO-GO
    assert "background:var(--wt-info); color:#fff" in css      # NO-REC
    assert "background:var(--wt-muted); color:#fff" in css     # ?
    for gone in ("#1b5e20", "#e65100", "#b71c1c", "#0e7490", "#616161"):
        assert gone not in css, f"stale verdict-pill hex {gone} still present"


def test_health_panel_inline_colours_use_tokens():
    css = _css()
    assert "color:var(--wt-success);\">+{{ antifragility.patterns_added_since_last_scan }}" in css
    assert "color: var(--wt-info);\">{{ concerns_summary.gaps }}" in css
    assert "color: var(--wt-warn);\">{{ concerns_summary.risks }}" in css
    assert "color: var(--wt-danger);\">{{ concerns_summary.high }}" in css
    assert "color:var(--wt-danger); font-size:0.85rem" in css  # Risks heading


def test_no_residual_theme_hexes():
    """Only #fff / #1a1a1a (contrast foregrounds) may remain."""
    css = _css()
    hexes = set(re.findall(r"#[0-9a-fA-F]{3,6}", css))
    allowed = {"#fff", "#1a1a1a"}
    residual = hexes - allowed
    assert not residual, f"unexpected theme hexes remain (should be tokenised): {sorted(residual)}"


def test_template_still_compiles():
    import sys
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
    from web.app import app
    app.jinja_env.get_template("cockpit.html")  # raises on syntax error
