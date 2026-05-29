"""Exhaustive all-routes load-time guard (T-2105).

The slow-aggregation page class (`/bvp` T-1954, `/inception` T-2083, `/approvals`
T-2102) is the latency twin of the unbounded-height class T-2048 fixed. Each
instance shipped silently for days before someone noticed the page felt slow:
T-1954 ran at 17.9s for weeks, T-2102 at 14.8s for ~2 weeks, T-2083 only got
diagnosed during a broken-link sweep. The fix shape is known and proven
(mtime-keyed per-file body/frontmatter caches), and the heights are already
guarded — but the *latency* leg of the prevention ladder was missing.

This test wires per-route load-time measurement into the regular test suite:
parametrize over every discovered route, time `page.goto + domcontentloaded`,
and assert under LOAD_CAP_MS. Any new slow page now fails `fw test playwright`
the moment it lands — the latency leg of the G-019 prevention.

Cap origin: T-2102 RCA suggested "cap, e.g. 5s". 5000ms matches.
Warm-up: conftest.py _warm_slow_routes() (T-2104) pre-warms the known-slow set
(/approvals, /inception, /tasks, /timeline, /bvp). Any new slow page either
needs adding to that list OR — better — a T-1954-pattern cache fix that
brings warm-cache load under cap.
"""
import importlib.util
import os
import time

import pytest

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# Cap origin: T-2102 RCA suggested "per-route load-time guard (cap, e.g. 5s)".
# Sibling to test_all_routes_height.py:HEIGHT_CAP_PX (8000px). Future bumps
# must update this comment AND the docstring to keep the contract auditable.
LOAD_CAP_MS = 5000


def _load_uxr():
    """Load the hyphenated ux-review.py module by path (mirrors test_all_routes_height)."""
    path = os.path.join(ROOT, "agents", "ux-review", "ux-review.py")
    spec = importlib.util.spec_from_file_location("uxr_t2105", path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def _discover_routes():
    """All parameterless GET routes, or [] if the app map can't be imported."""
    try:
        return _load_uxr().discover_get_routes()
    except Exception:
        return []


ROUTES = _discover_routes()


def test_routes_discovered_exhaustively():
    """The guard must use the exhaustive list, not fall back to a 5-page hard-code."""
    assert len(ROUTES) > 5, (
        f"discover_get_routes() returned {len(ROUTES)} routes — expected the exhaustive "
        "set (>5). If the app url_map can't be imported, the guard is blind (T-2105)."
    )


def test_load_cap_is_documented():
    """The cap must keep its T-2102-RCA provenance annotation so future bumps stay auditable."""
    with open(__file__) as fh:
        src = fh.read()
    assert "T-2102" in src, (
        "LOAD_CAP_MS provenance comment lost. Re-add the T-2102 RCA reference next to the "
        "constant or this guard becomes folklore (T-2105)."
    )


# Routes known to be slow even on warm caches. Each entry is `route -> (cap_ms, task_id)`.
# These are NOT exemptions — they are TODO markers with a tracking task. The guard still
# enforces the elevated cap so further regression is caught; the followup task is the
# path back to the global LOAD_CAP_MS.
KNOWN_SLOW: dict[str, tuple[int, str]] = {
    # T-2107: /search exercises embeddings + full task corpus; warm load 6655ms (T-2105 baseline).
    "/search": (8000, "T-2107"),
    # T-2108: cockpit / home page warm load 5137ms (T-2105 baseline) — aggregates everything.
    "/": (7000, "T-2108"),
    # T-2106 (/timeline) CLOSED 2026-05-30: _FM_CACHE per-file cache landed in
    # web/blueprints/timeline.py — warm load dropped 8279ms → ~700ms. Entry removed;
    # the guard now enforces the global 5000ms cap on /timeline.
}


@pytest.mark.skipif(not ROUTES, reason="app url_map not importable — route discovery returned []")
@pytest.mark.parametrize("route", ROUTES)
def test_route_load_time_bounded(page, base_url, route):
    """Every discovered route renders below the load-time cap on a WARM cache (no new
    T-1954-class slow page).

    Prime + measure pattern: first goto fills caches, second goto is measured. This
    isolates "warm-cache user experience" from cache-TTL-expiry noise during long
    test runs (suite walks 47 routes × ~2-3s each; TTL is 30s, so without priming
    the second half of the suite measures cold-cache loads).

    A failure means either (a) a new slow-aggregation page entered the class (apply
    T-1954/T-2102 mtime-keyed cache pattern), or (b) the page is genuinely too heavy
    and needs splitting. Either way the fix lives in the blueprint, not in raising
    the cap.
    """
    # Prime: first hit warms blueprint-local caches (T-1954 _FM_CACHE etc.).
    # We don't measure this — measuring cold is a different test class.
    page.goto(f"{base_url}{route}")
    page.wait_for_load_state("domcontentloaded")

    # Measure: second hit is what a real user sees once caches are warm.
    t0 = time.perf_counter()
    page.goto(f"{base_url}{route}")
    page.wait_for_load_state("domcontentloaded")
    elapsed_ms = (time.perf_counter() - t0) * 1000

    cap = LOAD_CAP_MS
    todo_marker = ""
    if route in KNOWN_SLOW:
        elevated_cap, task_id = KNOWN_SLOW[route]
        cap = elevated_cap
        todo_marker = f" (KNOWN_SLOW: elevated to {elevated_cap}ms; fix tracked in {task_id})"

    assert elapsed_ms < cap, (
        f"{route} warm-load took {elapsed_ms:.0f}ms — exceeds {cap}ms cap{todo_marker}. "
        "This is the T-1954/T-2102/T-2083 slow-aggregation class. Fix by shape "
        "(mtime-keyed _FM_CACHE / _BODY_CACHE in the blueprint, NOT by raising the "
        "cap). See web/blueprints/bvp.py:_FM_CACHE and web/blueprints/approvals.py:"
        "_BODY_CACHE for the proven pattern. (T-2105 guard)"
    )
