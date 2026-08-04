"""T-1770 — /fabric/graph cold-load regression test.

Bug: synchronous `clientWidth/clientHeight` read in the inline script
returned 0 in Chromium when stylesheets/fonts had not finished loading,
producing a degenerate `viewBox="0 0 0 0"`. Container rendered, no nodes
visible. A page refresh worked because layout was cached.

Fix: live dim reads, requestAnimationFrame init, ResizeObserver.

This test pins the post-fix invariants: viewBox is non-degenerate AND
SVG contains node circles on cold load.
"""
import pytest
from playwright.sync_api import Page

from tests.playwright.target import TEST_URL


def _url(path: str) -> str:
    return f"{TEST_URL}{path}"


class TestFabricGraphColdLoad:
    """Cold-load render must produce a non-empty SVG (T-1770 regression)."""

    def test_graph_page_loads(self, page: Page):
        resp = page.goto(_url("/fabric/graph"))
        assert resp.status == 200

    def test_viewbox_is_non_degenerate(self, page: Page):
        """viewBox must be `0 0 W H` with W>0 and H>0 — NOT `0 0 0 0`."""
        page.goto(_url("/fabric/graph"))
        page.wait_for_load_state("domcontentloaded")
        # Allow the deferred requestAnimationFrame init + first ResizeObserver
        # callback to fire. Two animation frames is enough; 200ms is generous.
        page.wait_for_timeout(200)
        viewbox = page.evaluate(
            "() => { const s = document.querySelector('#graph-area svg'); "
            "return s ? s.getAttribute('viewBox') : null; }"
        )
        assert viewbox is not None, "SVG element missing under #graph-area"
        parts = viewbox.split()
        assert len(parts) == 4, f"viewBox malformed: {viewbox!r}"
        w, h = float(parts[2]), float(parts[3])
        assert w > 0 and h > 0, (
            f"viewBox is degenerate: {viewbox!r} — T-1770 regression "
            "(dimensions read before layout settled)"
        )

    def test_svg_contains_nodes_on_cold_load(self, page: Page):
        """SVG must contain rendered subsystem nodes (circles) — not empty."""
        page.goto(_url("/fabric/graph"))
        page.wait_for_load_state("domcontentloaded")
        page.wait_for_timeout(300)  # init + simulation tick
        circle_count = page.evaluate(
            "() => document.querySelectorAll('#graph-area svg circle').length"
        )
        assert circle_count > 0, (
            "SVG has zero circles after cold load — fabric graph rendered empty. "
            "T-1770 regression: clientWidth race or downstream bug."
        )

    def test_no_console_errors_other_than_favicon(self, page: Page):
        """No JS errors during cold load (favicon 404 is allowed)."""
        errors = []
        page.on("pageerror", lambda exc: errors.append(str(exc)))
        page.goto(_url("/fabric/graph"))
        page.wait_for_load_state("domcontentloaded")
        page.wait_for_timeout(300)
        # Filter out the harmless favicon 404 (it's a network error, not a
        # pageerror, so it shouldn't appear here — but guard anyway).
        real_errors = [e for e in errors if "favicon" not in e.lower()]
        assert not real_errors, f"JS errors on cold load: {real_errors}"
