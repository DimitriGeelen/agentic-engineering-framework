"""T-2027 (arc-007 S5a): Arcs section templates use semantic --wt-* tokens.

First slice of T-1994 (Fabric + Arcs redesign). Covers the hardcoded semantic status
colours on the Arcs templates: the OK/WARN badges (arcs_index, arc_detail), the
closed-column kanban border (arcs_index), and the NO-GO verdict pill + error banner
(arc_close, arc_review).

Convention (proven across S3 siblings — T-2023/24/25/26): semantic status colours
(success/warn/danger) map to `--wt-*`; **neutral** pico vars (`--pico-secondary`,
`--pico-card-sectioning-background-color`, `--pico-muted-*`) are retained, including
their fallback hexes. So the residual check forbids the specific converted *semantic*
hexes but explicitly allows the neutral pico-var fallbacks (#888 / #444) to remain.

Per-palette re-theming is proven in tests/playwright/test_arcs_pages_tokens.py; the
cross-palette legibility (esp. amber on light palettes) is the Human [REVIEW] AC.
"""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TPL = ROOT / "web" / "templates"

# Semantic hexes that MUST be gone (converted to --wt-* tokens).
CONVERTED_SEMANTIC_HEXES = ("#1e6a2a", "#c97a00", "#2e7d32", "#c62828")
# Neutral pico-var fallbacks that are deliberately retained.
RETAINED_NEUTRAL_FALLBACKS = ("#888", "#444")


def _txt(name: str) -> str:
    return (TPL / name).read_text()


def test_badges_use_success_warn_tokens():
    idx, detail = _txt("arcs_index.html"), _txt("arc_detail.html")
    # arcs_index: badge-ok (x2) + closed border = 3 success; badge-warn = 1 warn
    assert idx.count(".badge-ok { background: var(--wt-success);") == 2
    assert ".badge-warn { background: var(--wt-warn);" in idx
    assert 'data-state="closed"]      { border-left: 4px solid var(--wt-success);' in idx
    # arc_detail mirrors the badge pair
    assert ".badge-ok { background: var(--wt-success);" in detail
    assert ".badge-warn { background: var(--wt-warn);" in detail


def test_no_go_verdict_uses_danger_token():
    close, review = _txt("arc_close.html"), _txt("arc_review.html")
    assert ".verdict-NO-GO { background: var(--wt-danger);" in close
    assert ".verdict-NO-GO { background: var(--wt-danger);" in review
    # arc_close error banner also converted (2 danger uses total in arc_close)
    assert close.count("var(--wt-danger)") == 2


def test_converted_semantic_hexes_are_gone():
    for name in ("arcs_index.html", "arc_detail.html", "arc_close.html", "arc_review.html"):
        txt = _txt(name)
        for hexv in CONVERTED_SEMANTIC_HEXES:
            assert hexv not in txt, f"{name}: stale semantic hex {hexv} remains"


def test_neutral_pico_vars_not_over_converted():
    """Neutral pico vars (and their fallback hexes) must survive — proves scope discipline."""
    idx = _txt("arcs_index.html")
    assert "var(--pico-secondary, #888)" in idx
    assert "var(--pico-card-sectioning-background-color, #444)" in idx


def test_only_neutral_fallback_hexes_remain():
    """The only non-contrast hexes left across the four files are the neutral fallbacks."""
    allowed = {"#fff", "#1a1a1a", "#000"} | set(RETAINED_NEUTRAL_FALLBACKS)
    for name in ("arcs_index.html", "arc_detail.html", "arc_close.html", "arc_review.html"):
        txt = _txt(name)
        hexes = set(re.findall(r"(?<!&)#[0-9a-fA-F]{3,6}\b", txt))
        residual = hexes - allowed
        assert not residual, f"{name}: unexpected hexes remain: {sorted(residual)}"


def test_templates_still_compile():
    import sys
    sys.path.insert(0, str(ROOT))
    from web.app import app
    for name in ("arcs_index.html", "arc_detail.html", "arc_close.html", "arc_review.html"):
        app.jinja_env.get_template(name)  # raises on syntax error
