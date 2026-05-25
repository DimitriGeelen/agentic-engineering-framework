"""Playwright regression test for /learnings rendered height (T-2044).

The learnings page rendered ~67,000px tall — the learnings `<table>` sits inside a
`<details open>`, so every row counted toward page height and grew unbounded as learnings
accumulate (7th instance of the unbounded-page class, surfaced by the T-2042 exhaustive
probe). T-2044 wraps the table in a max-height scroll container with a sticky header
(`<details>` can't legally wrap `<tr>`), so all rows stay in the DOM but the page stays
short — same fix as /fabric (T-2039). These tests guard against the height bomb returning.
"""

# Mirror agents/ux-review/ux-review.py TALL_PAGE_CAP_PX.
HEIGHT_CAP_PX = 8000


class TestLearningsHeight:
    def test_learnings_height_bounded(self, page, base_url):
        """scrollHeight stays under the screenshot cap regardless of learning count."""
        page.goto(f"{base_url}/learnings")
        page.wait_for_load_state("domcontentloaded")
        page.wait_for_timeout(500)
        height = page.evaluate("document.documentElement.scrollHeight")
        assert height < HEIGHT_CAP_PX, (
            f"/learnings scrollHeight {height}px exceeds {HEIGHT_CAP_PX}px cap — "
            "learnings table is unbounded again (T-2044 regression)"
        )

    def test_learnings_rows_in_scroll_container(self, page, base_url):
        """Rows live inside a bounded scroll container, not a page-tall table."""
        page.goto(f"{base_url}/learnings")
        page.wait_for_load_state("domcontentloaded")
        page.wait_for_timeout(500)
        rows = page.evaluate(
            "document.querySelectorAll('.learnings-table-scroll tbody tr').length"
        )
        if rows <= 30:
            # Too few rows to overflow the container — bounding is trivial.
            return
        metrics = page.evaluate(
            "() => { const c = document.querySelector('.learnings-table-scroll');"
            " return c ? {ch: c.clientHeight, sh: c.scrollHeight} : null; }"
        )
        assert metrics is not None, ".learnings-table-scroll container missing (T-2044 regression)"
        assert metrics["ch"] < metrics["sh"], (
            f"container is not scrolling ({metrics}) — table not bounded (T-2044 regression)"
        )
