"""Exhaustive all-routes height guard (T-2048).

The unbounded-page class (9 instances: /approvals, /fabric, /inception, /timeline,
/gaps, /learnings, /decisions, /docs/generated, /graduation) slipped past detection
because the ux-review height sweep was hard-coded to 5 pages. T-2042 fixed the
*capability* by adding `discover_get_routes()` (derives every parameterless GET route
from the app url_map), but only behind the opt-in `--all-routes` flag — nothing invoked
it automatically. This test wires the exhaustive sweep into the regular test suite: it
parametrizes over every discovered route and asserts each renders below the screenshot
cap. Any new over-cap page now fails `fw test playwright` the moment it's added — the
automation leg of the G-019 prevention, complementing the per-page regression guards
(test_<page>_height.py) and the detector capability (T-2042).
"""
import importlib.util
import os

import pytest

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# Mirror agents/ux-review/ux-review.py TALL_PAGE_CAP_PX — the guard and the detector
# must stay in lockstep. (Asserted by test_height_cap_matches_detector below.)
HEIGHT_CAP_PX = 8000


def _load_uxr():
    """Load the hyphenated ux-review.py module by path (mirrors test_ux_review_routes)."""
    path = os.path.join(ROOT, "agents", "ux-review", "ux-review.py")
    spec = importlib.util.spec_from_file_location("uxr_t2048", path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def _discover_routes():
    """All parameterless GET routes, or [] if the app map can't be imported."""
    try:
        return _load_uxr().discover_get_routes()
    except Exception:
        return []


def _discover_parametrized():
    """Sampled parametrized GET routes (T-2088), or [] on failure.

    Per-pattern limit 5 keeps the suite under the 280s budget (4 patterns × 5 routes ≈
    +60s on top of the 231s parameterless sweep). Same 8000px cap as the parameterless
    guard so they never diverge.
    """
    try:
        return _load_uxr().discover_parametrized_routes(per_pattern_limit=5)
    except Exception:
        return []


ROUTES = _discover_routes()
PARAMETRIZED_ROUTES = _discover_parametrized()


def test_routes_discovered_exhaustively():
    """The guard must use the exhaustive list, not fall back to the 5-page hard-code."""
    assert len(ROUTES) > 5, (
        f"discover_get_routes() returned {len(ROUTES)} routes — expected the exhaustive "
        "set (>5). If the app url_map can't be imported, the guard is blind (T-2048)."
    )


def test_height_cap_matches_detector():
    """The cap here must equal the detector's TALL_PAGE_CAP_PX so they never diverge."""
    detector_cap = _load_uxr().TALL_PAGE_CAP_PX
    assert HEIGHT_CAP_PX == detector_cap, (
        f"HEIGHT_CAP_PX ({HEIGHT_CAP_PX}) != detector TALL_PAGE_CAP_PX ({detector_cap}) "
        "— the guard and the sweep have drifted (T-2048)"
    )


@pytest.mark.skipif(not ROUTES, reason="app url_map not importable — route discovery returned []")
@pytest.mark.parametrize("route", ROUTES)
def test_route_height_bounded(page, base_url, route):
    """Every discovered route renders below the screenshot cap (no new unbounded page)."""
    page.goto(f"{base_url}{route}")
    page.wait_for_load_state("domcontentloaded")
    page.wait_for_timeout(300)
    height = page.evaluate("document.documentElement.scrollHeight")
    assert height < HEIGHT_CAP_PX, (
        f"{route} scrollHeight {height}px exceeds {HEIGHT_CAP_PX}px cap — a new unbounded "
        "page entered the class. Fix by shape (collapse overflow or table scroll container) "
        "— see project_unbounded_watchtower_pages / CLAUDE.md. (T-2048 guard)"
    )


@pytest.mark.skipif(
    not PARAMETRIZED_ROUTES,
    reason="parametrized-route sampler returned [] — no arcs/tasks fixtures yet (T-2088)",
)
@pytest.mark.parametrize("route", PARAMETRIZED_ROUTES)
def test_parametrized_route_height_bounded(page, base_url, route):
    """Sampled parametrized routes (/arcs/<id>, /tasks/<id>, /review/<id>, /inception/<id>)
    render below the cap. Closes the T-2087 blind-spot: the parameterless guard never
    measured these patterns, so /arcs/orchestrator-rethink shipped at 15184px silently.
    Same 8000px cap; same fix shape (table scroll container or collapsed overflow).
    (T-2048 + T-2088)
    """
    page.goto(f"{base_url}{route}")
    page.wait_for_load_state("domcontentloaded")
    page.wait_for_timeout(300)
    height = page.evaluate("document.documentElement.scrollHeight")
    assert height < HEIGHT_CAP_PX, (
        f"{route} scrollHeight {height}px exceeds {HEIGHT_CAP_PX}px cap — a parametrized "
        "route entered the unbounded-page class. Fix by shape (max-height scroll container "
        "for tables, collapsed <details> for card lists) — see CLAUDE.md / T-2087 / "
        "project_unbounded_watchtower_pages. (T-2088 guard)"
    )
