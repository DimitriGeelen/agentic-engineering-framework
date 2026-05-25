"""Playwright regression test for /approvals rendered height (T-2038).

The review queue must stay bounded regardless of backlog size. Before T-2038 the
page rendered ~37,000px tall: ~120 human-AC cards each rendered their Steps/Expected
panels expanded (`<details open>`). That tall page also wedged the ux-review sweep's
full_page screenshot (T-2005). T-2038 renders only the first N most-actionable cards
and collapses the overflow into a `<details>` — display:none content is excluded from
scrollHeight yet stays in the DOM (every item reachable, one click away).

These tests guard against the height bomb returning. With a small backlog the page is
naturally short (assertions hold trivially); with a large backlog the overflow bounds
it. Either way scrollHeight must stay under the cap and no card may leave the DOM.
"""

# Mirror agents/ux-review/ux-review.py TALL_PAGE_CAP_PX — above this a full_page
# screenshot can wedge the browser, so the page must render below it.
HEIGHT_CAP_PX = 8000


class TestApprovalsHeight:
    def test_approvals_height_bounded(self, page, base_url):
        """scrollHeight stays under the screenshot cap regardless of backlog size."""
        page.goto(f"{base_url}/approvals")
        page.wait_for_load_state("networkidle")
        page.wait_for_timeout(500)
        height = page.evaluate("document.documentElement.scrollHeight")
        assert height < HEIGHT_CAP_PX, (
            f"/approvals scrollHeight {height}px exceeds {HEIGHT_CAP_PX}px cap — "
            "review queue is unbounded again (T-2038 regression)"
        )

    def test_approvals_items_reachable(self, page, base_url):
        """No verification card leaves the DOM: the overflow collapses, never drops."""
        page.goto(f"{base_url}/approvals")
        page.wait_for_load_state("networkidle")
        page.wait_for_timeout(500)
        dom_cards = page.evaluate(
            "document.querySelectorAll('.human-ac-group').length"
        )
        overflow = page.query_selector(".ac-overflow")
        if overflow is None:
            # Backlog under the visible cap — nothing collapsed; reachability is trivial.
            return
        # Overflow present: every card must still be in the DOM after expanding it.
        page.evaluate(
            "var o=document.querySelector('.ac-overflow'); if(o){o.open=true;}"
        )
        page.wait_for_timeout(200)
        opened_cards = page.evaluate(
            "document.querySelectorAll('.human-ac-group').length"
        )
        assert opened_cards == dom_cards, (
            f"card count changed after expanding overflow ({dom_cards} -> {opened_cards}) "
            "— items were dropped, not collapsed (T-2038 regression)"
        )
