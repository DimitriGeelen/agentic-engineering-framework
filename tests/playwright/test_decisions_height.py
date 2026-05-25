"""Playwright regression test for /decisions rendered height (T-2045).

The decisions page rendered ~13,418px tall (198 rows) — the decisions `<table>` had no
height bound, so every row counted toward page height and grew unbounded as decisions
accumulate (8th instance of the unbounded-page class, surfaced by the T-2042 exhaustive
probe). T-2045 wraps the table in a max-height scroll container with a sticky header
(`<details>` can't legally wrap `<tr>`), so all rows stay in the DOM but the page stays
short — same fix as /learnings (T-2044) and /fabric (T-2039). These tests guard against
the height bomb returning.
"""

# Mirror agents/ux-review/ux-review.py TALL_PAGE_CAP_PX.
HEIGHT_CAP_PX = 8000


class TestDecisionsHeight:
    def test_decisions_height_bounded(self, page, base_url):
        """scrollHeight stays under the screenshot cap regardless of decision count."""
        page.goto(f"{base_url}/decisions")
        page.wait_for_load_state("domcontentloaded")
        page.wait_for_timeout(500)
        height = page.evaluate("document.documentElement.scrollHeight")
        assert height < HEIGHT_CAP_PX, (
            f"/decisions scrollHeight {height}px exceeds {HEIGHT_CAP_PX}px cap — "
            "decisions table is unbounded again (T-2045 regression)"
        )

    def test_decisions_rows_in_scroll_container(self, page, base_url):
        """Rows live inside a bounded scroll container, not a page-tall table."""
        page.goto(f"{base_url}/decisions")
        page.wait_for_load_state("domcontentloaded")
        page.wait_for_timeout(500)
        rows = page.evaluate(
            "document.querySelectorAll('.decisions-table-scroll tbody tr').length"
        )
        if rows <= 30:
            # Too few rows to overflow the container — bounding is trivial.
            return
        metrics = page.evaluate(
            "() => { const c = document.querySelector('.decisions-table-scroll');"
            " return c ? {ch: c.clientHeight, sh: c.scrollHeight} : null; }"
        )
        assert metrics is not None, ".decisions-table-scroll container missing (T-2045 regression)"
        assert metrics["ch"] < metrics["sh"], (
            f"container is not scrolling ({metrics}) — table not bounded (T-2045 regression)"
        )
