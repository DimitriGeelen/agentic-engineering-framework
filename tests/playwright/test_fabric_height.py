"""Playwright regression test for /fabric rendered height (T-2039).

The component-fabric page rendered ~33,000px tall: a `<table>` with ~758 component
rows and no bound (sibling to the /approvals bomb fixed in T-2038). T-2039 wraps the
table in a `max-height` + `overflow-y:auto` scroll container with a sticky header —
the page height is bounded while every row stays in the DOM (reachable by scrolling
the container). These tests guard against the height bomb returning as the fabric
grows.
"""

# Mirror agents/ux-review/ux-review.py TALL_PAGE_CAP_PX.
HEIGHT_CAP_PX = 8000


class TestFabricHeight:
    def test_fabric_height_bounded(self, page, base_url):
        """scrollHeight stays under the screenshot cap regardless of component count."""
        page.goto(f"{base_url}/fabric")
        page.wait_for_load_state("networkidle")
        page.wait_for_timeout(500)
        height = page.evaluate("document.documentElement.scrollHeight")
        assert height < HEIGHT_CAP_PX, (
            f"/fabric scrollHeight {height}px exceeds {HEIGHT_CAP_PX}px cap — "
            "component table is unbounded again (T-2039 regression)"
        )

    def test_fabric_rows_in_scroll_container(self, page, base_url):
        """Every component row stays in the DOM inside the bounded scroll container."""
        page.goto(f"{base_url}/fabric")
        page.wait_for_load_state("networkidle")
        page.wait_for_timeout(500)
        container = page.query_selector(".fabric-table-scroll")
        assert container is not None, "fabric table is not wrapped in a scroll container"
        rows = page.evaluate(
            "document.querySelectorAll('.fabric-table-scroll tbody tr').length"
        )
        assert rows > 0, "no component rows rendered inside the scroll container"
        # The container must be bounded (shorter than the full table it holds),
        # otherwise the page height is not actually capped.
        container_h = page.evaluate(
            "document.querySelector('.fabric-table-scroll').clientHeight"
        )
        table_h = page.evaluate(
            "document.querySelector('.fabric-table-scroll table').scrollHeight"
        )
        if rows > 30:  # only meaningful when the table is large enough to overflow
            assert container_h < table_h, (
                f"scroll container ({container_h}px) is not shorter than its table "
                f"({table_h}px) — height is not actually bounded"
            )
