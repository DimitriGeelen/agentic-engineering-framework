"""T-2219 (T-2217 Slice 1): inception decide side-effect-warning widening.

Pins three properties on the htmx-warning paths in
web/blueprints/inception.py:

1. Truncation length raised from 150 → 1500 for both the side-effect warning
   and the commit-failure warning.
2. The interpolated stderr/commit_msg value is HTML-escaped (no raw stderr
   injection into rendered HTML).
3. The wrapping `<div>` carries `white-space: pre-wrap` so multi-line stderr
   (e.g. the disposition-gate block message with bullet list + bypass
   options) renders readably instead of collapsing to one line.

Origin: T-2217 §0 — operator saw `⚠ Decision recorded; side-effect warning:
=== Task Update === Task: T-2209 (...` cut off at ~150 chars, no way to
recover the rest from the rendered page. The disposition-gate stderr is
~700+ chars with a bullet list and three bypass options; at 150 chars
the operator gets only the opening sentence.

This is a static-source pin (matches the file content as edited) rather
than a Flask-route render test — the route handler is heavily branched
and rendering it end-to-end is Slice 2 (Playwright contract test, M-cost).
The static pin is cheap, deterministic, and catches regression by
re-narrowing or escape-stripping.
"""
from __future__ import annotations

import re
from pathlib import Path

INCEPTION_BP = (
    Path(__file__).resolve().parents[2]
    / "web"
    / "blueprints"
    / "inception.py"
)


def _read_source() -> str:
    assert INCEPTION_BP.is_file(), f"missing source: {INCEPTION_BP}"
    return INCEPTION_BP.read_text(encoding="utf-8")


def test_side_effect_warning_truncation_widened_to_1500():
    """Line ~551 — the side-effect warning emitted when primary_landed=True
    but `ok=False`. Was [:150], must now be [:1500]."""
    src = _read_source()
    # Locate the side-effect-warning fragment.
    assert "side-effect warning" in src, (
        "could not find the side-effect-warning fragment in inception.py"
    )
    # The widened literal must be present.
    assert "[:1500]" in src, (
        "expected at least one [:1500] truncation widening in inception.py "
        "(side-effect warning at line ~551 or commit-failure warning at "
        "line ~560 must be widened from 150)"
    )
    # The narrow 150 literal MUST NOT remain on the side-effect-warning path.
    # We allow [:150] elsewhere (none expected, but defensive — the narrow
    # form must not be associated with the "side-effect warning" string).
    side_block = _extract_block_around(src, "side-effect warning", radius=400)
    assert "[:150]" not in side_block, (
        f"side-effect warning still uses [:150]; got block:\n{side_block}"
    )
    assert "[:1500]" in side_block, (
        f"side-effect warning does not carry [:1500]; got block:\n{side_block}"
    )


def test_side_effect_warning_html_escaped():
    """Raw stderr must be passed through `html.escape(...)` before
    interpolation. Origin: defensive — fw subprocess stderr is trusted, but
    XSS hygiene + future-proofing against renderer changes."""
    src = _read_source()
    side_block = _extract_block_around(src, "side-effect warning", radius=400)
    # The side-effect warning fragment must wrap (stderr or stdout) in
    # _html.escape(...).
    assert "_html.escape" in side_block, (
        f"side-effect warning does not HTML-escape stderr; got block:\n{side_block}"
    )


def test_side_effect_warning_uses_pre_wrap_style():
    """Multi-line stderr must render with `white-space: pre-wrap` so the
    bullet list / option list in gate block messages survives — instead of
    collapsing to one wrapped line."""
    src = _read_source()
    side_block = _extract_block_around(src, "side-effect warning", radius=400)
    # Match `white-space:pre-wrap` or `white-space: pre-wrap` (with optional
    # whitespace after the colon).
    assert re.search(r"white-space\s*:\s*pre-wrap", side_block), (
        f"side-effect warning <div> lacks `white-space: pre-wrap` style; "
        f"got block:\n{side_block}"
    )


def test_commit_failure_warning_widened_to_1500():
    """Sibling: line ~560 — the commit-failure warning (T-2053). Same
    widening discipline applied for consistency."""
    src = _read_source()
    commit_block = _extract_block_around(
        src, "Decision recorded but not committed", radius=400
    )
    assert "[:1500]" in commit_block, (
        f"commit-failure warning does not carry [:1500]; got block:\n{commit_block}"
    )
    assert "[:150]" not in commit_block, (
        f"commit-failure warning still uses [:150]; got block:\n{commit_block}"
    )


def test_non_htmx_redirect_paths_unchanged():
    """The form-redirect path (`?warning=`, `?error=`) is intentionally NOT
    widened (URL query-string constraint). Lines ~596/598/605 must retain
    their existing truncation lengths."""
    src = _read_source()
    # The form-redirect path uses (stderr or stdout or "...")[:300]
    # for the warn/err variables. Confirm at least one [:300] survives.
    assert "[:300]" in src, (
        "expected at least one [:300] truncation (form-redirect path); "
        "if you widened the URL-query path, that is a separate slice with "
        "URL-length concerns — see T-2219 Context section."
    )


# --- helpers ----------------------------------------------------------------


def _extract_block_around(src: str, needle: str, radius: int = 400) -> str:
    """Return a window of `src` centred on the first occurrence of `needle`.

    Used to scope per-fragment assertions so the side-effect-warning checks
    don't accidentally match the unrelated `?warning=` form-redirect code.
    """
    idx = src.find(needle)
    assert idx != -1, f"needle {needle!r} not found in source"
    start = max(0, idx - radius)
    end = min(len(src), idx + radius)
    return src[start:end]
