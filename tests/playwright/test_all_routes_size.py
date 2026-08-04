"""Exhaustive all-routes response-SIZE guard (T-2775).

Watchtower had two guards on the unbounded-page class and neither could see bytes:

  * height  — test_all_routes_height.py, 8000px scrollHeight
  * latency — test_all_routes_load_time.py, 5000ms to domcontentloaded

`/timeline` shipped **69,879,595 bytes** past both. Height passed because T-2041 had already
capped the page on that axis, by rendering every session and hiding the overflow inside a
collapsed `<details>` — `display:none` is excluded from `scrollHeight`, so the measured number
went down while the payload did not. Latency passed intermittently for a different reason:
transfer over loopback took 4.4s, under the cap, because the expensive part is the browser
parsing 70 MB, not the server sending it.

So the page was "bounded" on both measured axes and unbounded on the one nobody measured.
L-429 (T-2040) already named unbounded pages as a recurring class — the learning existed, the
check did not. This is that check.

Size is worth guarding separately from latency for a reason the T-2776 thread established the
hard way: **a size measurement is contention-invariant and a latency measurement is not.**
Under load a latency guard oscillates and gets read as flaky (which is how a foreign server
came to be pinned as the test target); bytes are bytes whatever else the box is doing. When
both fire, size is the one to believe first.
"""
import importlib.util
import os
import urllib.request

import pytest

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# 2 MB. Chosen against measurement, not taste: after T-2775 the worst /timeline page is
# 513,706 bytes and the heaviest ordinary route is a few hundred KB, so 2 MB leaves ~4x
# headroom for honest growth while catching anything in the runaway class (the pre-fix page
# was 34x this). A cap that only just fits today's corpus would fail on corpus growth and
# teach everyone to raise it, which is how a guard stops meaning anything.
SIZE_CAP_BYTES = 2_000_000

# Routes measured but knowingly over cap, each with the task that owns the fix. An xfail
# here is a filed defect, not a silenced one: if a route drops under the cap the xfail turns
# XPASS and the suite tells us to delete the entry, so this list cannot quietly outlive the
# problem. Empty is the goal state.
KNOWN_OVER_CAP = {
    "/project": "T-2781 — 2,274,276 bytes, 1.14x cap; the early-warning case",
}


def _load_uxr():
    path = os.path.join(ROOT, "agents", "ux-review", "ux-review.py")
    spec = importlib.util.spec_from_file_location("uxr_t2775", path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def _discover_routes():
    try:
        return _load_uxr().discover_get_routes()
    except Exception:
        return []


ROUTES = _discover_routes()


def _measure(url: str) -> int:
    """Bytes of the response body, read off the wire.

    Deliberately not `len(page.content())`: that returns the *serialised DOM* after the
    browser has parsed, normalised and possibly mutated it, which is a different number from
    what the server sent. The defect being guarded is payload size.
    """
    req = urllib.request.Request(url, headers={"Accept": "text/html"})
    try:
        with urllib.request.urlopen(req, timeout=300) as resp:
            return len(resp.read())
    except urllib.error.HTTPError as exc:
        # A 4xx/5xx is still a response with a body, and this guard is about payload size,
        # not availability. Letting the HTTPError propagate would report every route that
        # legitimately 404s (/designer/overlay) or requires a parameter
        # (/search/load-conversation) as a size failure — a red that says nothing about
        # size and trains people to ignore the guard. Error pages can be unbounded too, so
        # they get measured rather than skipped.
        return len(exc.read())


def test_routes_discovered_exhaustively():
    """Guard the guard: a discovery failure returns [] and would skip everything silently."""
    assert len(ROUTES) > 5, (
        f"discover_get_routes() returned {len(ROUTES)} routes — expected the exhaustive set. "
        "If the app url_map can't be imported this guard is blind, and skipping reads "
        "identical to passing (T-2775)."
    )


@pytest.mark.skipif(not ROUTES, reason="app url_map not importable — route discovery returned []")
@pytest.mark.parametrize("route", ROUTES)
def test_route_response_size_bounded(base_url, route):
    size = _measure(f"{base_url}{route}")

    if route in KNOWN_OVER_CAP:
        if size < SIZE_CAP_BYTES:
            pytest.fail(
                f"{route} is now {size:,} bytes, under the {SIZE_CAP_BYTES:,} cap, but is "
                f"still listed in KNOWN_OVER_CAP ({KNOWN_OVER_CAP[route]}). Remove the entry "
                "— a stale exemption hides the next regression on this route."
            )
        pytest.xfail(f"{route} known over cap at {size:,} bytes: {KNOWN_OVER_CAP[route]}")

    assert size < SIZE_CAP_BYTES, (
        f"{route} returned {size:,} bytes, over the {SIZE_CAP_BYTES:,} cap — an unbounded "
        "page entered the class. Height and latency guards do NOT catch this: a collapsed "
        "<details> hides overflow from scrollHeight while still shipping every byte, which is "
        "exactly how /timeline reached 69,879,595 bytes with both other guards green. Fix by "
        "bounding what is rendered (server-side paging + a per-item cap with the remainder "
        "reachable), not by hiding it. (T-2775 guard)"
    )


@pytest.mark.parametrize("page_num", [1, 10, 35, 61])
def test_timeline_pages_bounded_not_just_the_first(base_url, page_num):
    """Paging bounds the page count; it does not bound what one page contains.

    Sessions are uneven — median ~37 task references, largest 2,499 — so after paging alone
    page 1 measured 609,180 bytes while page 10 measured 12,576,219. Measuring the landing
    page would have reported the fix as done. These four samples span the range, including
    the two pages that were worst before and after the per-session cap.
    """
    size = _measure(f"{base_url}/timeline?page={page_num}")
    assert size < SIZE_CAP_BYTES, (
        f"/timeline?page={page_num} returned {size:,} bytes, over the {SIZE_CAP_BYTES:,} cap. "
        "A single outlier session can blow up one page while page 1 stays small (T-2775)."
    )


def test_timeline_hidden_tasks_remain_reachable(base_url):
    """The cap has to be a window, not a deletion.

    A page that is small because it stopped saying anything is not fixed, so the session
    carrying the most task references must still render all of them on its own page.
    """
    size = _measure(f"{base_url}/timeline/session/S-2026-0706-2055")
    assert size > 10_000, (
        "the per-session page for the largest session returned almost nothing — the capped "
        "task lists are not actually reachable (T-2775)"
    )
    assert size < SIZE_CAP_BYTES, f"per-session page itself is unbounded at {size:,} bytes"
