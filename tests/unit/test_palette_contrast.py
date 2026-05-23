"""T-2007: palette-contrast lint — every foundation palette must clear WCAG AA.

Prevention guard for T-2006 (arc-007). The Editorial/linen preset shipped
`--wt-accent-ink` (#fbf8f1) on `--wt-accent` (#c4623f) at 3.83:1 — below WCAG AA's
4.5:1 for normal text — because S0 (T-1991) authored token colours by *look*, with
no contrast check before they landed. T-2006 darkened the one bad accent; this test
is the *prevention* (G-019: a gap isn't closed until recurrence is structurally
impossible).

It parses every `[data-wt-palette="X"]` block in `web/static/css/foundations.css`,
resolves each palette's accent / accent-ink (dark variants inherit accent from the
light block unless they override it), and asserts `accent-ink / accent` ≥ 4.5:1.
The next palette edit that drops a pair below AA fails `fw test unit` at authoring,
not in the browser-driven review loop.
"""
from __future__ import annotations

import re
from pathlib import Path

import pytest

FOUNDATIONS = Path(__file__).resolve().parents[2] / "web" / "static" / "css" / "foundations.css"
AA_NORMAL = 4.5  # WCAG AA contrast for normal text


# ---- WCAG relative-luminance contrast (same formula as agents/ux-review) ----
def _lin(channel: int) -> float:
    c = channel / 255
    return c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4


def _luminance(hex_color: str) -> float:
    h = hex_color.lstrip("#")
    r, g, b = int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)
    return 0.2126 * _lin(r) + 0.7152 * _lin(g) + 0.0722 * _lin(b)


def contrast_ratio(fg: str, bg: str) -> float:
    la, lb = _luminance(fg), _luminance(bg)
    hi, lo = max(la, lb), min(la, lb)
    return (hi + 0.05) / (lo + 0.05)


# ---- foundations.css palette parser -----------------------------------------
_BLOCK_RE = re.compile(
    r"(?P<sel>[^{}]*\[data-wt-palette=\"(?P<name>[a-z]+)\"\][^{]*)\{(?P<body>[^}]*)\}",
    re.DOTALL,
)


def _token(body: str, name: str) -> str | None:
    m = re.search(rf"{re.escape(name)}:\s*(#[0-9a-fA-F]{{6}})", body)
    return m.group(1) if m else None


def _resolve_palettes() -> dict[str, dict[str, str]]:
    """Return {palette: {accent, accent_ink}} merging light base + any dark override.

    The base block selector is exactly `[data-wt-palette="X"]`; dark blocks carry a
    `[data-theme="dark"]`/`[data-wt-mode="dark"]` prefix and usually omit accent —
    in which case accent/accent-ink inherit from the base block.
    """
    css = FOUNDATIONS.read_text(encoding="utf-8")
    base: dict[str, dict[str, str]] = {}
    overrides: list[tuple[str, dict[str, str]]] = []
    for m in _BLOCK_RE.finditer(css):
        name, sel, body = m.group("name"), m.group("sel"), m.group("body")
        vals = {}
        if (a := _token(body, "--wt-accent")):
            vals["accent"] = a
        if (ink := _token(body, "--wt-accent-ink")):
            vals["accent_ink"] = ink
        is_dark = "data-theme=\"dark\"" in sel or "data-wt-mode=\"dark\"" in sel
        if is_dark:
            if vals:
                overrides.append((name, vals))
        else:
            base.setdefault(name, {}).update(vals)
    # apply dark overrides on top of a copy so we can test the effective dark pair too
    resolved = {k: dict(v) for k, v in base.items()}
    for name, vals in overrides:
        resolved.setdefault(name, {}).update(vals)
    return resolved


PALETTES = _resolve_palettes()
# the 6 named palettes from settings.py PALETTES — guard against a parser miss
EXPECTED = {"slate", "linen", "stone", "paper", "bone", "console"}


def test_all_six_palettes_parsed():
    """Sanity: the parser must find every named palette, or the lint is blind."""
    assert EXPECTED.issubset(set(PALETTES)), (
        f"foundations.css palettes parsed = {sorted(PALETTES)}; "
        f"missing {sorted(EXPECTED - set(PALETTES))}"
    )


@pytest.mark.parametrize("palette", sorted(EXPECTED))
def test_accent_ink_on_accent_meets_aa(palette):
    """Every palette's button-label pair (accent-ink on accent) must clear AA 4.5:1."""
    p = PALETTES[palette]
    accent, ink = p.get("accent"), p.get("accent_ink")
    assert accent, f"{palette}: no --wt-accent resolved"
    assert ink, f"{palette}: no --wt-accent-ink resolved"
    ratio = contrast_ratio(ink, accent)
    assert ratio >= AA_NORMAL, (
        f"{palette}: accent-ink {ink} on accent {accent} = {ratio:.2f}:1 "
        f"< WCAG AA {AA_NORMAL}:1 — darken the accent (or adjust ink) to pass"
    )


def test_guard_catches_the_t2006_regression():
    """Regression proof: the helper must FAIL the exact pair T-2006 fixed, so the
    guard genuinely catches the class and isn't passing vacuously."""
    bad = contrast_ratio("#fbf8f1", "#c4623f")  # the pre-T-2006 linen pair
    assert bad < AA_NORMAL, f"expected the old linen pair to fail AA, got {bad:.2f}"
    assert abs(bad - 3.83) < 0.05, f"expected ~3.83:1 for the old pair, got {bad:.2f}"
