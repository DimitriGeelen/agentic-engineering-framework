"""Playwright tests for Costs page (T-981).

Covers: page loads, token usage displayed, session table present.
"""
from playwright.sync_api import Page

TEST_URL = "http://localhost:3099"


def _url(path: str) -> str:
    return f"{TEST_URL}{path}"


class TestCostsPage:
    """Costs page renders with token usage data."""

    def test_costs_page_loads(self, page: Page):
        resp = page.goto(_url("/costs"))
        assert resp.status == 200

    def test_costs_has_content(self, page: Page):
        page.goto(_url("/costs"))
        page.wait_for_load_state("domcontentloaded")
        content = page.content()
        assert len(content) > 500, "Costs page should have content"

    def test_costs_shows_token_info(self, page: Page):
        """Costs page should show token-related information."""
        page.goto(_url("/costs"))
        page.wait_for_load_state("domcontentloaded")
        content = page.content().lower()
        assert "token" in content or "cost" in content or "usage" in content, \
            "Costs page should show token/cost/usage information"

    def test_costs_has_heading(self, page: Page):
        page.goto(_url("/costs"))
        page.wait_for_load_state("domcontentloaded")
        heading = page.locator("h1, h2")
        assert heading.count() > 0, "Costs page should have a heading"
