"""Playwright regression test for /timeline rendered height (T-2041).

The timeline rendered ~90,000px tall — every session handover (~1001 `<article>` cards,
one per S-*.md file) in a single flat loop, no bound (4th instance of the unbounded-page
class after /approvals T-2038, /fabric T-2039, /inception T-2040). T-2041 renders the
newest N sessions inline and collapses the older overflow into a `<details>` —
display:none content is excluded from scrollHeight yet stays in the DOM (every session
one click away). These tests guard against the height bomb returning as handovers
accumulate (the corpus grows every session).
"""

# Mirror agents/ux-review/ux-review.py TALL_PAGE_CAP_PX.
HEIGHT_CAP_PX = 8000


class TestTimelineHeight:
    def test_timeline_height_bounded(self, page, base_url):
        """scrollHeight stays under the screenshot cap regardless of session count."""
        page.goto(f"{base_url}/timeline")
        page.wait_for_load_state("domcontentloaded")
        page.wait_for_timeout(500)
        height = page.evaluate("document.documentElement.scrollHeight")
        assert height < HEIGHT_CAP_PX, (
            f"/timeline scrollHeight {height}px exceeds {HEIGHT_CAP_PX}px cap — "
            "timeline is unbounded again (T-2041 regression)"
        )

    def test_timeline_items_reachable(self, page, base_url):
        """No session card leaves the DOM: the overflow collapses, never drops."""
        page.goto(f"{base_url}/timeline")
        page.wait_for_load_state("domcontentloaded")
        page.wait_for_timeout(500)
        dom_cards = page.evaluate("document.querySelectorAll('article').length")
        overflow = page.query_selector(".timeline-overflow")
        if overflow is None:
            # Corpus under the visible cap — nothing collapsed; reachability is trivial.
            return
        page.evaluate(
            "var o=document.querySelector('.timeline-overflow'); if(o){o.open=true;}"
        )
        page.wait_for_timeout(200)
        opened_cards = page.evaluate("document.querySelectorAll('article').length")
        assert opened_cards == dom_cards, (
            f"card count changed after expanding overflow ({dom_cards} -> {opened_cards}) "
            "— sessions were dropped, not collapsed (T-2041 regression)"
        )
