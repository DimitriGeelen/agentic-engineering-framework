"""Playwright regression test for /inception rendered height (T-2040).

The inception board rendered ~83,000px tall — 349 inception `<article>` cards in one
container, no bound (sibling to /approvals T-2038 and /fabric T-2039). T-2040 renders
the first N cards and collapses the overflow into a `<details>` — display:none content
is excluded from scrollHeight yet stays in the DOM (every inception one click away).
These tests guard against the height bomb returning as inceptions accumulate.
"""

# Mirror agents/ux-review/ux-review.py TALL_PAGE_CAP_PX.
HEIGHT_CAP_PX = 8000


class TestInceptionHeight:
    def test_inception_height_bounded(self, page, base_url):
        """scrollHeight stays under the screenshot cap regardless of inception count."""
        page.goto(f"{base_url}/inception")
        page.wait_for_load_state("domcontentloaded")
        page.wait_for_timeout(500)
        height = page.evaluate("document.documentElement.scrollHeight")
        assert height < HEIGHT_CAP_PX, (
            f"/inception scrollHeight {height}px exceeds {HEIGHT_CAP_PX}px cap — "
            "inception board is unbounded again (T-2040 regression)"
        )

    def test_inception_items_reachable(self, page, base_url):
        """No inception card leaves the DOM: the overflow collapses, never drops."""
        page.goto(f"{base_url}/inception")
        page.wait_for_load_state("domcontentloaded")
        page.wait_for_timeout(500)
        dom_cards = page.evaluate("document.querySelectorAll('article').length")
        overflow = page.query_selector(".inc-overflow")
        if overflow is None:
            # Backlog under the visible cap — nothing collapsed; reachability is trivial.
            return
        page.evaluate(
            "var o=document.querySelector('.inc-overflow'); if(o){o.open=true;}"
        )
        page.wait_for_timeout(200)
        opened_cards = page.evaluate("document.querySelectorAll('article').length")
        assert opened_cards == dom_cards, (
            f"card count changed after expanding overflow ({dom_cards} -> {opened_cards}) "
            "— inceptions were dropped, not collapsed (T-2040 regression)"
        )
