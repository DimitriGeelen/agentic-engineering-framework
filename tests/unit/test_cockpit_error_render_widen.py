"""T-2221: cockpit.py sibling widening (OBS-049 class-fix derived from T-2219).

Pins the T-2219 render-side correctness shape on the 4 cockpit.py routes
that previously truncated `stderr` at 200/300 chars:
- `scan_refresh` (was [:300])
- `scan_approve` action error (was [:200])
- `scan_apply` error (was [:200])
- `scan_focus` error (was [:200])

For each: assert the widened [:1500] truncation, presence of `_escape(...)`,
and `white-space:pre-wrap` on the wrapping element. The static-source pin
matches the T-2219 sibling test (`test_inception_decide_warning_widen.py`)
so future re-narrowing or escape-stripping fails before merge.
"""
from __future__ import annotations

import re
from pathlib import Path

COCKPIT_BP = (
    Path(__file__).resolve().parents[2]
    / "web"
    / "blueprints"
    / "cockpit.py"
)


def _read_source() -> str:
    assert COCKPIT_BP.is_file(), f"missing source: {COCKPIT_BP}"
    return COCKPIT_BP.read_text(encoding="utf-8")


def test_no_narrow_stderr_truncations_remain():
    """Class invariant: no [:200] or [:300] truncations of stderr survive
    on the cockpit error-render paths. The widened [:1500] form is the
    only allowed shape for these routes."""
    src = _read_source()
    # Match `stderr[:200]` or `stderr[:300]` (the narrow pre-T-2221 form).
    narrow = re.findall(r"stderr\[:(?:200|300)\]", src)
    assert not narrow, (
        f"cockpit.py still contains narrow stderr truncations: {narrow!r}; "
        "T-2221 widening incomplete"
    )


def test_four_widened_sites_present():
    """Exactly four `[:1500]` stderr truncations expected — one per route
    closed by T-2221 (scan_refresh, scan_approve, scan_apply, scan_focus)."""
    src = _read_source()
    widened = re.findall(r"stderr\[:1500\]", src)
    assert len(widened) == 4, (
        f"expected 4 [:1500] stderr widenings in cockpit.py; got {len(widened)}: "
        f"{widened!r}"
    )


def test_widened_paths_use_html_escape():
    """All four widened sites must wrap stderr in `_escape(...)` — no raw
    interpolation into the HTML fragment."""
    src = _read_source()
    # `_escape(stderr[:1500])` is the expected shape.
    escaped = re.findall(r"_escape\(stderr\[:1500\]\)", src)
    assert len(escaped) == 4, (
        f"expected 4 `_escape(stderr[:1500])` occurrences; got {len(escaped)}: "
        f"{escaped!r}"
    )


def test_widened_paths_use_pre_wrap_style():
    """All four widened sites must carry `white-space:pre-wrap` on the
    wrapping `<p>` element so multi-line gate stderr renders readably."""
    src = _read_source()
    # Each widened block should contain a <p style="...white-space:pre-wrap..."
    # We assert at least 4 `white-space:pre-wrap` occurrences AND that they
    # appear in close proximity to the [:1500] sites.
    pre_wrap_count = len(re.findall(r"white-space:\s*pre-wrap", src))
    assert pre_wrap_count >= 4, (
        f"expected ≥4 `white-space:pre-wrap` style occurrences in cockpit.py; "
        f"got {pre_wrap_count}"
    )

    # Stronger pin: each `stderr[:1500]` site must have `pre-wrap` within
    # 200 chars before it (in the same return tuple / style declaration).
    for match in re.finditer(r"stderr\[:1500\]", src):
        idx = match.start()
        window_start = max(0, idx - 200)
        window = src[window_start:idx]
        assert "pre-wrap" in window, (
            f"`stderr[:1500]` at char {idx} lacks nearby `pre-wrap` style "
            f"declaration; window:\n{window}"
        )


def test_scan_refresh_route_widened():
    """Spot-check: `scan_refresh` (the originally most-impactful route per
    OBS-049) carries the widened shape."""
    src = _read_source()
    # Locate the scan_refresh function and assert the widened shape appears
    # within ~600 chars after its `def` line.
    m = re.search(r"def scan_refresh\b", src)
    assert m, "could not locate `def scan_refresh` in cockpit.py"
    # Window large enough to cover the multi-line return tuple post-widening.
    block = src[m.start() : m.start() + 1000]
    assert "[:1500]" in block, (
        f"scan_refresh body does not contain [:1500] widening; block:\n{block}"
    )
    assert "pre-wrap" in block, (
        f"scan_refresh body does not contain pre-wrap style; block:\n{block}"
    )
