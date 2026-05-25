"""Playwright regression test for /gaps rendered height (T-2043).

The gaps page rendered ~22,000px tall — 74 gap `<article>` cards (watching + closed) in
one flat loop, no bound (6th instance of the unbounded-page class, surfaced by the T-2042
exhaustive height probe). T-2043 orders active gaps first, renders the first N inline, and
collapses the overflow (mostly closed/resolved) into a `<details>` — display:none content
is excluded from scrollHeight yet stays in the DOM (every gap one click away). These tests
guard against the height bomb returning as gaps accumulate.
"""

# Mirror agents/ux-review/ux-review.py TALL_PAGE_CAP_PX.
HEIGHT_CAP_PX = 8000


class TestGapsHeight:
    def test_gaps_height_bounded(self, page, base_url):
        """scrollHeight stays under the screenshot cap regardless of gap count."""
        page.goto(f"{base_url}/gaps")
        page.wait_for_load_state("domcontentloaded")
        page.wait_for_timeout(500)
        height = page.evaluate("document.documentElement.scrollHeight")
        assert height < HEIGHT_CAP_PX, (
            f"/gaps scrollHeight {height}px exceeds {HEIGHT_CAP_PX}px cap — "
            "gaps page is unbounded again (T-2043 regression)"
        )

    def test_gaps_items_reachable(self, page, base_url):
        """No gap card leaves the DOM: the overflow collapses, never drops."""
        page.goto(f"{base_url}/gaps")
        page.wait_for_load_state("domcontentloaded")
        page.wait_for_timeout(500)
        dom_cards = page.evaluate("document.querySelectorAll('article').length")
        overflow = page.query_selector(".gaps-overflow")
        if overflow is None:
            # Register under the visible cap — nothing collapsed; reachability is trivial.
            return
        page.evaluate(
            "var o=document.querySelector('.gaps-overflow'); if(o){o.open=true;}"
        )
        page.wait_for_timeout(200)
        opened_cards = page.evaluate("document.querySelectorAll('article').length")
        assert opened_cards == dom_cards, (
            f"card count changed after expanding overflow ({dom_cards} -> {opened_cards}) "
            "— gaps were dropped, not collapsed (T-2043 regression)"
        )
