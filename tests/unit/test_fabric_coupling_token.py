"""T-2028 (arc-007 S5b): fabric coupling-note uses --wt-danger; categorical map stays fixed.

Final colour slice of T-1994. The Fabric pages use an 8-type *categorical* colour map
(script/route/template/data/hook/config/fragment/else) plus a dark-canvas cytoscape
graph — identity encoding, not semantic status. Per the human decision (2026-05-24),
those stay fixed and palette-independent; only the one genuinely-semantic site converts:
fabric_detail.html coupling-note (#e53e3e → var(--wt-danger)).

This test pins BOTH directions:
  - the coupling-note is now tokenised (#e53e3e gone);
  - the categorical type-hues are UNCHANGED (so a future "tokenise everything" sweep
    can't silently re-tint the identity map without this test flagging it).
"""

from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TPL = ROOT / "web" / "templates"

# A representative subset of the categorical type-colour map that MUST stay fixed.
CATEGORICAL_HUES = ("#2d3748", "#2b6cb0", "#744210", "#553c9a", "#4a5568")


def _txt(name: str) -> str:
    return (TPL / name).read_text()


def test_coupling_note_uses_danger_token():
    txt = _txt("fabric_detail.html")
    assert 'style="color: var(--wt-danger);">{{ component.coupling_note }}' in txt
    assert "#e53e3e" not in txt, "semantic coupling-note hex #e53e3e still present"


def test_categorical_type_map_unchanged_detail():
    txt = _txt("fabric_detail.html")
    for hue in CATEGORICAL_HUES:
        assert hue in txt, f"categorical type hue {hue} was removed (decision: keep fixed)"


def test_categorical_type_map_unchanged_index():
    txt = _txt("fabric.html")
    # fabric.html carries the full map incl. the 'fragment' hue
    for hue in CATEGORICAL_HUES + ("#285e61",):
        assert hue in txt, f"categorical type hue {hue} was removed from fabric.html"


def test_template_still_compiles():
    import sys
    sys.path.insert(0, str(ROOT))
    from web.app import app
    app.jinja_env.get_template("fabric_detail.html")  # raises on syntax error
