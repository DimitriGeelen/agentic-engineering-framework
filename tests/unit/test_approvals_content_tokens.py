"""T-2026 (arc-007 S3c2): _approvals_content.html inline styles use semantic tokens.

S3c (T-2025) tokenised the approvals page <style> block. This slice covers the inline
styles in the content partial: the three agent verdict-pill blocks (inception /
arc-closure / partial-complete), the reviewer mechanical badges, the recommendation
decision text, the "no recommendation" fallback box, severity spans, the verdict /
review / rubber-stamp / stale filter buttons, the stale-age span, and the
batch-complete / complete-task submit buttons.

Mapping mirrors the cockpit verdict pills (T-2024): GO/CLOSE→success, DEFER→warn with
#1a1a1a dark text, NO-GO→danger, NO-REC→info, KEEP-OPEN/?→muted; reviewer good→success
/ bad→danger; severity high→danger / med→warn / low→muted. The only literals that may
remain are #fff / #1a1a1a (contrast foregrounds) — HTML numeric entities (&#9888; etc.)
are not colours and are excluded from the residual check.

Per-palette re-theming is proven in tests/playwright/test_approvals_content_tokens.py;
the GO/NO-GO legibility (a sovereignty concern) is the Human [REVIEW] AC.
"""

from __future__ import annotations

import re
from pathlib import Path

TEMPLATE = (
    Path(__file__).resolve().parents[2] / "web" / "templates" / "_approvals_content.html"
)


def _txt() -> str:
    return TEMPLATE.read_text()


def test_verdict_pills_use_tokens():
    txt = _txt()
    # DEFER gets warn + dark text in all three blocks
    assert txt.count("background:var(--wt-warn); color:#1a1a1a;") >= 3
    # GO/CLOSE success, NO-GO danger, NO-REC info, muted fallback all present
    assert "background:var(--wt-success); color:#fff;" in txt
    assert "background:var(--wt-danger); color:#fff;" in txt
    assert "background:var(--wt-info); color:#fff;" in txt
    assert "background:var(--wt-muted); color:#fff;" in txt
    for gone in ("#1b5e20", "#e65100", "#b71c1c", "#0e7490", "#616161"):
        assert gone not in txt, f"stale verdict/filter hex {gone} present"


def test_reviewer_badges_use_tokens():
    txt = _txt()
    assert "{% if _bad %}background:var(--wt-danger); color:#fff;{% else %}background:var(--wt-success); color:#fff;{% endif %}" in txt
    for gone in ("#7f1d1d", "#14532d"):
        assert gone not in txt, f"stale reviewer-badge hex {gone} present"


def test_recommendation_and_severity_use_tokens():
    txt = _txt()
    assert '<span style="color:var(--wt-success);">GO</span>' in txt
    assert '<span style="color:var(--wt-danger);">NO-GO</span>' in txt
    assert '<span style="color:var(--wt-muted);">DEFER</span>' in txt
    assert '<span style="color:var(--wt-danger);">[HIGH]</span>' in txt
    assert '<span style="color:var(--wt-warn);">[MED]</span>' in txt
    for gone in ("#10b981", "#ef4444", "#6b7280", "#f59e0b"):
        assert gone not in txt, f"stale rec/severity hex {gone} present"


def test_fallback_box_and_filter_buttons_use_tokens():
    txt = _txt()
    # no-recommendation fallback box (tinted warn) + ink text
    assert "color-mix(in srgb, var(--wt-warn) 7%, transparent)" in txt
    assert "color:var(--wt-warn); margin-bottom:0.3rem;" in txt
    # filter buttons: outline (border+text both token)
    assert "border-color:var(--wt-success); color:var(--wt-success);" in txt
    assert "border-color:var(--wt-warn); color:var(--wt-warn);" in txt
    assert "border-color:var(--wt-info); color:var(--wt-info);" in txt
    for gone in ("#b45309", "#047857"):
        assert gone not in txt, f"stale filter/box hex {gone} present"


def test_submit_buttons_use_success_token():
    txt = _txt()
    assert txt.count("background:var(--wt-success); border-color:var(--wt-success); color:white;") >= 2


def test_no_residual_theme_hexes():
    """Only #fff / #1a1a1a may remain; HTML numeric entities (&#NNNN;) are not colours."""
    txt = _txt()
    # exclude entities: a colour hex is a # NOT immediately preceded by '&'
    hexes = set(re.findall(r"(?<!&)#[0-9a-fA-F]{3,6}\b", txt))
    residual = hexes - {"#fff", "#1a1a1a"}
    assert not residual, f"unexpected theme hexes remain (should be tokenised): {sorted(residual)}"


def test_template_still_compiles():
    import sys
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
    from web.app import app
    app.jinja_env.get_template("_approvals_content.html")  # raises on syntax error
