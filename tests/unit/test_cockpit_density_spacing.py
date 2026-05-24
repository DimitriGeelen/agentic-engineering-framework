"""T-2029: cockpit spacing scales with the density axis; exclusions are honoured.

S3b makes the cockpit the first consumer of --wt-density-scale: every rem/px
padding/margin/gap is wrapped in calc(<value> * var(--wt-density-scale)) so the
Compact/Cozy/Comfortable control tightens/loosens layout. em-spacing, border-radius,
border, font-size and letter-spacing must NOT be wrapped (they're typography/corner/line
axes, or em already follows font-size — wrapping would double-scale). The computed
×0.875 / ×1 / ×1.125 behaviour is proven in the Playwright sibling test (T-1575).
"""

from __future__ import annotations

import re
from pathlib import Path

COCKPIT = Path(__file__).resolve().parents[2] / "web" / "templates" / "cockpit.html"
DENSITY = "var(--wt-density-scale)"


def _txt() -> str:
    return COCKPIT.read_text()


def test_known_spacing_rules_are_wrapped():
    txt = _txt()
    # A representative sample across the <style> block and inline styles.
    samples = [
        ".wt-header",        # margin-bottom:1.5rem
        ".wt-section",       # margin-bottom:1rem
        ".wt-card",          # padding + margin-bottom
        ".wt-card-actions",  # gap
        ".wt-columns",       # gap + margin-bottom
        ".wt-allclear",      # padding:2rem
    ]
    for sel in samples:
        # \s*\{ anchors on the rule open-brace, so ".wt-card" won't match ".wt-card-summary"
        m = re.search(re.escape(sel) + r"\s*\{[^}]*\}", txt)
        assert m, f"selector {sel!r} not found"
        rule = m.group(0)
        # at least one spacing prop in the rule must reference the density scale
        assert DENSITY in rule, f"{sel} has no density-scaled spacing: {rule}"


def test_every_rem_px_spacing_value_is_wrapped():
    """No bare rem/px padding/margin/gap may remain (zeros excluded)."""
    txt = _txt()
    offenders = []
    for m in re.finditer(r"(padding|margin|gap)[a-z-]*\s*:\s*([^;{}]+)", txt):
        prop, val = m.group(1), m.group(2)
        # find bare rem/px numbers that are NOT inside a density calc
        for num in re.finditer(r"(?<![(*\s])\b\d[\d.]*(rem|px)\b", val):
            # skip if this value chunk already carries the density scale
            if DENSITY in val:
                continue
            offenders.append(f"{m.group(1)}: {val.strip()}")
            break
    assert not offenders, f"unwrapped rem/px spacing remains: {offenders}"


def test_exclusions_not_wrapped():
    """border-radius / font-size / letter-spacing / border / em-spacing stay bare."""
    txt = _txt()
    # No excluded property may carry the density scale.
    for prop in ("border-radius", "font-size", "letter-spacing",
                 "border-left", "border-top", "border-bottom", "min-width", "max-width"):
        bad = re.findall(re.escape(prop) + r"\s*:\s*calc\([^)]*" + re.escape(DENSITY), txt)
        assert not bad, f"{prop} must not be density-scaled: {bad}"
    # em-spacing must never be wrapped (would double-scale with font-size).
    assert not re.search(r"calc\(\s*[\d.]+em\s*\*\s*" + re.escape(DENSITY), txt), \
        "em spacing must not be wrapped"


def test_density_scale_is_actually_used():
    # sanity: the slice did something — a meaningful number of wraps exist.
    assert _txt().count(DENSITY) >= 30


def test_cockpit_template_compiles():
    import sys
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
    from web.app import app
    app.jinja_env.get_template("cockpit.html")
