"""T-2222: tasks.py sibling widening (OBS-049 full closure derived from T-2219/T-2221).

Pins the T-2219/T-2221 render-side correctness shape on the 6 tasks.py routes
that previously truncated `(stderr or stdout)` at 200 chars with raw f-string
interpolation (no escape, no pre-wrap):

- `/api/task/create` action error (was [:200], multi-line return tuple)
- `/api/task/<id>/horizon` action error (was [:200])
- `/api/task/<id>/owner` action error (was [:200])
- `/api/task/<id>/type` action error (was [:200])
- `/api/task/<id>/complete` action error (was [:200])
- `/api/task/<id>/status` action error (was [:200])

For each: assert the widened [:1500] truncation, presence of `_escape(...)`,
and `white-space:pre-wrap` on the wrapping element. The static-source pin
matches the T-2221 sibling test (`test_cockpit_error_render_widen.py`)
so future re-narrowing, escape-stripping, or pre-wrap removal fails before
merge. Also asserts the module-level `_escape` helper is defined (vs the
T-2221 cockpit.py case where it was already present).
"""
from __future__ import annotations

import re
from pathlib import Path

TASKS_BP = (
    Path(__file__).resolve().parents[2]
    / "web"
    / "blueprints"
    / "tasks.py"
)


def _read_source() -> str:
    assert TASKS_BP.is_file(), f"missing source: {TASKS_BP}"
    return TASKS_BP.read_text(encoding="utf-8")


def test_no_narrow_stderr_truncations_remain():
    """Class invariant: no [:200] or [:300] truncations of (stderr or stdout)
    survive on the tasks.py error-render paths. The widened [:1500] form is
    the only allowed shape for these routes."""
    src = _read_source()
    # Match `)[:200]` or `)[:300]` — the narrow pre-T-2222 form (closes the
    # `(stderr or stdout)` expression).
    narrow = re.findall(r"\)\[:(?:200|300)\]", src)
    assert not narrow, (
        f"tasks.py still contains narrow truncations: {narrow!r}; "
        "T-2222 widening incomplete"
    )


def test_six_widened_sites_present():
    """Exactly six `)[:1500]` truncations expected — one per route closed by
    T-2222 (create, horizon, owner, type, complete, status)."""
    src = _read_source()
    widened = re.findall(r"\)\[:1500\]", src)
    assert len(widened) == 6, (
        f"expected 6 )[:1500] widenings in tasks.py; got {len(widened)}: "
        f"{widened!r}"
    )


def test_widened_paths_use_html_escape():
    """All six widened sites must wrap (stderr or stdout) in `_escape(...)`
    — no raw interpolation into the HTML fragment (XSS defence)."""
    src = _read_source()
    # `_escape((stderr or stdout)[:1500])` is the expected shape.
    escaped = re.findall(r"_escape\(\(stderr or stdout\)\[:1500\]\)", src)
    assert len(escaped) == 6, (
        f"expected 6 `_escape((stderr or stdout)[:1500])` occurrences; "
        f"got {len(escaped)}: {escaped!r}"
    )


def test_widened_paths_use_pre_wrap_style():
    """All six widened sites must carry `white-space:pre-wrap` on the
    wrapping `<p>` element so multi-line gate stderr renders readably."""
    src = _read_source()
    pre_wrap_count = len(re.findall(r"white-space:\s*pre-wrap", src))
    assert pre_wrap_count >= 6, (
        f"expected ≥6 `white-space:pre-wrap` style occurrences in tasks.py; "
        f"got {pre_wrap_count}"
    )

    # Stronger pin: each `[:1500]` site must have `pre-wrap` within 200 chars
    # before it (in the same return tuple / style declaration).
    for match in re.finditer(r"\)\[:1500\]", src):
        idx = match.start()
        window_start = max(0, idx - 200)
        window = src[window_start:idx]
        assert "pre-wrap" in window, (
            f"`)[:1500]` at char {idx} lacks nearby `pre-wrap` style "
            f"declaration; window:\n{window}"
        )


def test_escape_helper_defined():
    """T-2222 contract: tasks.py must define its own `_escape` helper at
    module level (mirrors cockpit.py:255-258 shape). Imports from another
    blueprint are not acceptable — keep blueprints self-contained."""
    src = _read_source()
    assert re.search(r"^def _escape\(", src, re.MULTILINE), (
        "missing module-level `def _escape(` in tasks.py — T-2222 helper "
        "contract not satisfied"
    )
    # Sanity: helper body must perform at least the &, <, >, " escapes
    # (matches cockpit.py:255-258 baseline).
    helper_match = re.search(
        r"def _escape\(text\):.*?(?=\n(?:def |\Z))", src, re.DOTALL
    )
    assert helper_match, "_escape helper body not parseable"
    body = helper_match.group(0)
    for required in ("&amp;", "&lt;", "&gt;", "&quot;"):
        assert required in body, (
            f"_escape helper missing `{required}` replacement"
        )
