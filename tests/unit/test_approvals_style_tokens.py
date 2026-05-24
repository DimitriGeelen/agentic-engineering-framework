"""T-2025 (arc-007 S3c): approvals.html <style> block uses per-palette semantic tokens.

The approvals page stylesheet hardcoded a Tailwind-style hex vocabulary
(#10b981/#ef4444/#f59e0b/#1565c0/#7c3aed/#6b7280/#3b82f6) that defeated the foundation
palette. This slice maps every rule onto --wt-success/danger/warn/info/accent/muted so
the page honours the selected preset. Badges follow the T-2023 queue-pill precedent:
color-mix tint background + var(--wt-*) text + color-mix tint border (no separate ink
hexes). The only literal that may remain is #000 — the darken anchor inside the
btn-approve:hover color-mix.

Per-palette re-theming is proven in tests/playwright/test_approvals_style_tokens.py;
contrast / approve-reject-legibility (a sovereignty concern) is the Human [REVIEW] AC.
"""

from __future__ import annotations

import re
from pathlib import Path

TEMPLATE = Path(__file__).resolve().parents[2] / "web" / "templates" / "approvals.html"


def _style() -> str:
    """Just the <style> block (the slice's scope)."""
    txt = TEMPLATE.read_text()
    start = txt.index("<style>")
    end = txt.index("</style>", start)
    return txt[start:end]


def test_card_accents_use_tokens():
    css = _style()
    assert "border-color: var(--wt-warn)" in css      # .pending
    assert "border-color: var(--wt-success)" in css   # .approved
    assert "border-color: var(--wt-danger)" in css    # .rejected
    assert "border-color: var(--wt-info)" in css      # .go-decision
    assert "var(--wt-accent) 27%" in css              # .human-ac-group border


def test_buttons_use_tokens():
    css = _style()
    assert ".btn-approve {\n    background: var(--wt-success);" in css
    assert "border: 1px solid var(--wt-danger);" in css  # .btn-reject
    assert "color: var(--wt-danger);" in css
    # hover uses a token-based darken / tint, not a fixed hex
    assert "color-mix(in srgb, var(--wt-success) 82%, #000)" in css
    assert "color-mix(in srgb, var(--wt-danger) 13%, transparent)" in css
    for gone in ("#10b981", "#059669", "#ef4444"):
        assert gone not in css, f"stale button hex {gone} present"


def test_badges_use_tint_token_pattern():
    css = _style()
    # status + confidence badges: tint bg + full-token text + tint border
    assert "color-mix(in srgb, var(--wt-warn) 13%, transparent); color: var(--wt-warn)" in css
    assert "color-mix(in srgb, var(--wt-success) 13%, transparent); color: var(--wt-success)" in css
    assert "color-mix(in srgb, var(--wt-danger) 13%, transparent); color: var(--wt-danger)" in css
    assert "color-mix(in srgb, var(--wt-muted) 13%, transparent); color: var(--wt-muted)" in css
    assert "color-mix(in srgb, var(--wt-info) 13%, transparent); color: var(--wt-info)" in css
    # old ink hexes gone
    for gone in ("#b45309", "#047857", "#dc2626", "#1d4ed8", "#3b82f6"):
        assert gone not in css, f"stale badge ink/tint hex {gone} present"


def test_stat_and_decision_colours_use_tokens():
    css = _style()
    assert ".tier0-active .stat-value { color: var(--wt-warn)" in css
    assert ".go-active .stat-value { color: var(--wt-info)" in css
    assert ".ac-active .stat-value { color: var(--wt-accent)" in css
    assert ".dec-go { color: var(--wt-success)" in css
    assert ".dec-nogo { color: var(--wt-danger)" in css
    assert ".dec-defer { color: var(--wt-muted)" in css


def test_no_residual_theme_hexes():
    """Only #000 (color-mix darken anchor) may remain in the style block."""
    css = _style()
    hexes = set(re.findall(r"#[0-9a-fA-F]{3,6}", css))
    residual = hexes - {"#000"}
    assert not residual, f"unexpected theme hexes remain (should be tokenised): {sorted(residual)}"


def test_template_still_compiles():
    import sys
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
    from web.app import app
    app.jinja_env.get_template("approvals.html")  # raises on syntax error
