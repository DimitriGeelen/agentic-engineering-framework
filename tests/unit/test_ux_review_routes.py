"""Unit test for ux-review route discovery (T-2042).

The unbounded-page class (T-2038 /approvals, T-2039 /fabric, T-2040 /inception,
T-2041 /timeline) slipped past the ux-review height sweep because the page list was
hard-coded to 5 routes — /inception and /timeline were never height-checked, so they
grew to 83k/90k px undetected. `discover_get_routes()` makes the detector exhaustive by
deriving the page set from the running app's url_map. These tests pin the discovery
contract: known growing pages included, parameterized/api/static routes excluded.
"""
import importlib.util
import os

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def _load_uxr():
    path = os.path.join(ROOT, "agents", "ux-review", "ux-review.py")
    spec = importlib.util.spec_from_file_location("uxr_t2042", path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def test_discover_includes_previously_missed_pages():
    routes = _load_uxr().discover_get_routes()
    # The two pages the 5-page hard-code blind-spotted (T-2040, T-2041).
    assert "/inception" in routes, "inception not discovered — the T-2040 blind spot returns"
    assert "/timeline" in routes, "timeline not discovered — the T-2041 blind spot returns"
    # And the pages the old list already covered are still there.
    for p in ("/", "/tasks", "/approvals", "/fabric", "/arcs"):
        assert p in routes, f"{p} dropped from discovery"


def test_discover_excludes_unloadable_routes():
    routes = _load_uxr().discover_get_routes()
    # Parameterized routes can't be loaded without a value.
    assert not any("<" in p for p in routes), [p for p in routes if "<" in p]
    # API + static are not human render surfaces.
    assert not any(p.startswith("/api/") for p in routes)
    assert not any(p.startswith("/static") for p in routes)


def test_discover_is_exhaustive_vs_hardcode():
    mod = _load_uxr()
    routes = mod.discover_get_routes()
    # The whole point: the detector now covers far more than the old 5-page hard-code.
    assert len(routes) > len(mod.DEFAULT_SWEEP_PAGES), (
        f"discovery ({len(routes)}) should exceed the hard-coded "
        f"{len(mod.DEFAULT_SWEEP_PAGES)}-page list"
    )
