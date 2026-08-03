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

Warm-up (T-2777 correction): each parametrized test primes its own route with
an unmeasured goto before the measured one(s) — see `test_route_load_time_bounded`
below. This guard does NOT depend on conftest.py's session-scoped
`_warm_slow_routes()` (T-2104) staying warm — that warm-up's 30s/60s/120s TTLs
expire long before a 7.5-minute, 47-route suite reaches most of its
parametrizations, which is exactly the defect T-2777 tracked ("warm-up expires
mid-suite"). `_warm_slow_routes()` still matters for *other* Playwright test
files that goto a slow route once and assert on content/height rather than
timing it — this file no longer needs it.

Contention (T-2777, T-2776 RCA): this repo self-hosts on a shared, actively-
mutating dev host — concurrent agent sessions and cron jobs write to
`.tasks/active/*.md` and `.context/` while the suite runs, which invalidates
the blueprint-local mtime-caches (T-1954/T-2102-pattern) mid-measurement and
inflates a single sample. T-2776 measured this directly: /tasks read 0.14s
against a live server but 11.7s inside the suite, for the identical route. A
single post-warm sample can't distinguish "this route regressed" from "another
session touched a task file in the ~2ms window between this goto and the
last". `test_route_load_time_bounded` controls for this with a bounded retry:
a structurally slow route (needs the T-1954 cache-pattern fix) stays slow
across every sample; a route only caught by transient contention gets a fast
sample within a couple of retries. The assertion message reports every sample
so a genuine regression and a contention-inflated one look different in the
failure output, not just in outcome.
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
    # T-2106 (/timeline) CLOSED 2026-05-30: _FM_CACHE per-file cache landed in
    # web/blueprints/timeline.py — warm load dropped 8279ms → ~700ms. Entry removed;
    # the guard now enforces the global 5000ms cap on /timeline.
    # T-2107 (/search) CLOSED 2026-05-30: _TAG_FM_CACHE per-file mtime cache landed
    # in web/search_utils.py:aggregate_tags — post-TTL rebuild 6473ms → 33ms.
    # Entry removed; guard enforces global 5000ms cap on /search.
    # T-2108 (/) CLOSED 2026-05-30: _HUMAN_VERIFY_CACHE per-file mtime cache landed
    # in web/blueprints/cockpit.py:get_human_verify_tasks + dedupe in get_cockpit_context
    # (was running the 171-task walk twice per render). Warm 2522ms → 712ms,
    # post-TTL 4964ms → 3234ms. Entry removed; guard enforces global 5000ms cap.
    #
    # T-2775 (/timeline) OPEN: distinct from the T-2106 cache-TTL defect above — this is
    # unbounded response SIZE (69.8MB, every session ever recorded, no windowing/paging),
    # measured at 29.4s to domcontentloaded on the Flask test client. A cache can't fix an
    # unbounded page; the fix shape is windowing. Elevated cap has margin over the last
    # measurement but the underlying page grows with corpus history, so this entry may need
    # raising again before T-2775 lands a real windowing fix — that is the honest state of
    # an un-bounded route, not cap creep for a bounded one.
    "/timeline": (35000, "T-2775"),
}

# T-2777: bounded retry count for the warm-cache measurement below. Controls for transient,
# contention-driven mtime-cache invalidation (T-2776 RCA) without touching LOAD_CAP_MS or
# KNOWN_SLOW — a structurally slow route stays slow across every sample, a route only
# caught mid-flight by another session's write gets a fast sample within a retry or two.
RETRY_SAMPLES = 3


def _measure_goto_ms(page, url):
    """Time one `goto` + `domcontentloaded`. Caller decides prime vs. measured."""
    t0 = time.perf_counter()
    page.goto(url)
    page.wait_for_load_state("domcontentloaded")
    return (time.perf_counter() - t0) * 1000


@pytest.mark.skipif(not ROUTES, reason="app url_map not importable — route discovery returned []")
@pytest.mark.parametrize("route", ROUTES)
def test_route_load_time_bounded(page, base_url, route):
    """Every discovered route renders below the load-time cap on a WARM cache (no new
    T-1954-class slow page).

    Measures best-of-`RETRY_SAMPLES` warm-cache navigations, after one unmeasured
    priming goto. Two distinct costs motivate this shape (T-2777):

    - Cold-cache cost (title defect): the priming goto exists so this test never
      depends on conftest.py's session-scoped warm-up staying warm — each
      parametrization re-primes its own route regardless of how long the suite has
      been running or what TTL has since expired.
    - Contention-inflated cost (T-2776 RCA): this repo self-hosts on a shared,
      actively-mutating dev host, so a single post-warm sample can land during
      another session's write to `.tasks/active/` and read as a cache miss that
      never happens for a real user. Retrying (bounded, stops at the first sample
      under cap) and reporting the best sample separates "this route is slow" from
      "this one sample was unlucky" — a structurally slow route stays slow across
      every retry, a route only caught mid-flight gets a fast sample within one or
      two.

    A failure that stays high across all `RETRY_SAMPLES` means either (a) a new
    slow-aggregation page entered the class (apply T-1954/T-2102 mtime-keyed cache
    pattern), or (b) the page is genuinely too heavy and needs splitting/windowing
    (see /timeline, T-2775, KNOWN_SLOW below). Either way the fix lives in the
    blueprint, not in raising the cap.
    """
    url = f"{base_url}{route}"

    # Prime: first hit warms blueprint-local caches (T-1954 _FM_CACHE etc.).
    # We don't measure this — measuring cold is a different test class.
    page.goto(url)
    page.wait_for_load_state("domcontentloaded")

    cap = LOAD_CAP_MS
    todo_marker = ""
    if route in KNOWN_SLOW:
        elevated_cap, task_id = KNOWN_SLOW[route]
        cap = elevated_cap
        todo_marker = f" (KNOWN_SLOW: elevated to {elevated_cap}ms; fix tracked in {task_id})"

    # Measure: best-of-RETRY_SAMPLES warm-cache navigations. Stop as soon as a
    # sample clears the cap — the common (uncontended) case costs exactly one
    # measured goto, same as before T-2777.
    samples = [_measure_goto_ms(page, url)]
    while samples[-1] >= cap and len(samples) < RETRY_SAMPLES:
        samples.append(_measure_goto_ms(page, url))
    elapsed_ms = min(samples)
    sample_report = ", ".join(f"{s:.0f}ms" for s in samples)

    assert elapsed_ms < cap, (
        f"{route} best-of-{len(samples)} warm-cache navigation took {elapsed_ms:.0f}ms "
        f"(all samples: [{sample_report}]) — exceeds {cap}ms cap{todo_marker}. This "
        "measures warm-cache page-render time, best case across repeated samples "
        "(T-2777) — every sample landing high means the route itself is slow, not "
        "host contention (see T-2776 RCA). This is the T-1954/T-2102/T-2083 "
        "slow-aggregation class. Fix by shape (mtime-keyed _FM_CACHE / _BODY_CACHE "
        "in the blueprint, NOT by raising the cap). See web/blueprints/bvp.py:"
        "_FM_CACHE and web/blueprints/approvals.py:_BODY_CACHE for the proven "
        "pattern. (T-2105 guard)"
    )
