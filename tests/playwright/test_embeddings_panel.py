"""Playwright tests for the /embeddings panel (T-1719 A4).

Why Playwright and not a curl+grep check: T-1575/T-971 forbid element-presence
grep for UI acceptance. A `grep -q "Miss rate"` passes on a page whose value
never rendered, on a page that 500s below the fold, and on a page whose CSS
collapsed every panel to zero height. The whole point of this surface is that a
missing answer must not look like a good one — verifying it with a method that
cannot tell those apart would reproduce the exact bug (T-3004) one level up.

So these assert on VISIBILITY and on RENDERED TEXT, not on markup presence.
"""

import re

import pytest

ROUTE = "/embeddings"


class TestEmbeddingsPanelLoads:
    def test_page_returns_ok(self, page, base_url):
        resp = page.goto(f"{base_url}{ROUTE}")
        assert resp is not None, f"{ROUTE}: no response"
        assert resp.status == 200, f"{ROUTE}: HTTP {resp.status}"

    def test_verdict_banner_is_visible(self, page, base_url):
        """The headline verdict must be visible, and must be one of the four states."""
        page.goto(f"{base_url}{ROUTE}")
        page.wait_for_load_state("domcontentloaded")
        banner = page.locator(".emb-verdict").first
        banner.wait_for(state="visible", timeout=5000)
        label = banner.locator(".label").inner_text().strip().lower()
        assert label in {"ok", "stale", "unused", "unknown"}, (
            f"unexpected verdict label: {label!r}"
        )


class TestFourSignalsRendered:
    """All four signals get their own visible section — deliberately not blended.

    An index can be fresh and unqueried, queried and missing, hitting and useless.
    If any one of these sections silently disappears, that failure mode becomes
    invisible again.
    """

    @pytest.mark.parametrize(
        "heading",
        ["Index", "Recall usage", "Retrieval happiness", "Recent routing decisions"],
    )
    def test_section_heading_visible(self, page, base_url, heading):
        page.goto(f"{base_url}{ROUTE}")
        page.wait_for_load_state("domcontentloaded")
        locator = page.get_by_role("heading", name=re.compile(heading, re.I)).first
        locator.wait_for(state="visible", timeout=5000)
        assert locator.is_visible(), f"section {heading!r} not visible"

    def test_four_stat_cards_are_visible(self, page, base_url):
        page.goto(f"{base_url}{ROUTE}")
        page.wait_for_load_state("domcontentloaded")
        cards = page.locator(".emb-stat")
        assert cards.count() == 4, f"expected 4 stat cards, found {cards.count()}"
        for i in range(4):
            assert cards.nth(i).is_visible(), f"stat card {i} not visible"

    @pytest.mark.parametrize(
        "label", ["Index age", "Chunks", "Miss rate", "Happiness"]
    )
    def test_stat_card_has_a_rendered_value(self, page, base_url, label):
        """Each card shows SOMETHING — a number or an explicit unknown, never blank.

        A blank value is the failure this page exists to prevent. 'unknown' is an
        acceptable answer here; empty is not.
        """
        page.goto(f"{base_url}{ROUTE}")
        page.wait_for_load_state("domcontentloaded")
        card = page.locator(".emb-stat", has=page.get_by_text(re.compile(label, re.I)))
        card.first.wait_for(state="visible", timeout=5000)
        value = card.first.locator(".num").inner_text().strip()
        assert value, f"{label}: stat value rendered empty"


class TestTriStateHonesty:
    """A missing answer must READ as missing (T-3004 is the origin of this rule)."""

    def test_unknown_values_say_unknown_not_zero(self, page, base_url):
        """Any .num marked unknown must carry non-numeric text.

        If a loader returns None and the template renders '0', the page reports a
        five-month-old index as brand new — which is precisely how T-3004 happened.
        """
        page.goto(f"{base_url}{ROUTE}")
        page.wait_for_load_state("domcontentloaded")
        unknowns = page.locator(".emb-stat .num.unknown")
        for i in range(unknowns.count()):
            text = unknowns.nth(i).inner_text().strip()
            assert text, "unknown stat rendered empty"
            assert not re.fullmatch(r"[-+]?[\d.,]+%?d?", text), (
                f"unknown value rendered as a number: {text!r} — "
                "a missing answer must not be indistinguishable from a real one"
            )

    def test_page_does_not_scroll_horizontally(self, page, base_url):
        """Wide tables must scroll inside their own container, not the body."""
        page.goto(f"{base_url}{ROUTE}")
        page.wait_for_load_state("domcontentloaded")
        overflow = page.evaluate(
            "() => document.documentElement.scrollWidth - "
            "document.documentElement.clientWidth"
        )
        assert overflow <= 1, f"page overflows horizontally by {overflow}px"
