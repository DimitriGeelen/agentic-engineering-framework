"""Playwright regression test for /graduation rendered height (T-2046).

The graduation pipeline page rendered ~70,201px tall (462 rows) — the tallest of the
unbounded-page class. Despite its "pipeline lists" name, the single height driver is the
pipeline `<table>` (the fixed-size flow viz, summary stats, and filter row don't grow, and
the "How to promote" section is already collapsed). T-2046 wraps the table in a max-height
scroll container with a sticky header (`<details>` can't legally wrap `<tr>`), so all rows
stay in the DOM but the page stays short — same fix as /learnings (T-2044) and /decisions
(T-2045). These tests guard against the height bomb returning, including under the
`?status=` filter.
"""

# Mirror agents/ux-review/ux-review.py TALL_PAGE_CAP_PX.
HEIGHT_CAP_PX = 8000


class TestGraduationHeight:
    def test_graduation_height_bounded(self, page, base_url):
        """scrollHeight stays under the screenshot cap regardless of pipeline size."""
        page.goto(f"{base_url}/graduation")
        page.wait_for_load_state("domcontentloaded")
        page.wait_for_timeout(500)
        height = page.evaluate("document.documentElement.scrollHeight")
        assert height < HEIGHT_CAP_PX, (
            f"/graduation scrollHeight {height}px exceeds {HEIGHT_CAP_PX}px cap — "
            "pipeline table is unbounded again (T-2046 regression)"
        )

    def test_graduation_filtered_height_bounded(self, page, base_url):
        """The ?status= filtered view also renders inside the bounded container."""
        page.goto(f"{base_url}/graduation?status=ready")
        page.wait_for_load_state("domcontentloaded")
        page.wait_for_timeout(500)
        height = page.evaluate("document.documentElement.scrollHeight")
        assert height < HEIGHT_CAP_PX, (
            f"/graduation?status=ready scrollHeight {height}px exceeds {HEIGHT_CAP_PX}px cap "
            "(T-2046 regression)"
        )

    def test_graduation_rows_in_scroll_container(self, page, base_url):
        """Rows live inside a bounded scroll container, not a page-tall table."""
        page.goto(f"{base_url}/graduation")
        page.wait_for_load_state("domcontentloaded")
        page.wait_for_timeout(500)
        rows = page.evaluate(
            "document.querySelectorAll('.graduation-table-scroll tbody tr').length"
        )
        if rows <= 30:
            # Too few rows to overflow the container — bounding is trivial.
            return
        metrics = page.evaluate(
            "() => { const c = document.querySelector('.graduation-table-scroll');"
            " return c ? {ch: c.clientHeight, sh: c.scrollHeight} : null; }"
        )
        assert metrics is not None, ".graduation-table-scroll container missing (T-2046 regression)"
        assert metrics["ch"] < metrics["sh"], (
            f"container is not scrolling ({metrics}) — table not bounded (T-2046 regression)"
        )
