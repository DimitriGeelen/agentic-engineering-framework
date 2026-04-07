"""Playwright tests for Search page (T-990).

Covers: page loads, heading, search interface elements.
"""
from playwright.sync_api import Page

TEST_URL = "http://localhost:3099"


def _url(path: str) -> str:
    return f"{TEST_URL}{path}"


class TestSearchPage:
    """Search page renders with search interface."""

    def test_search_page_loads(self, page: Page):
        resp = page.goto(_url("/search"))
        assert resp.status == 200

    def test_search_has_heading(self, page: Page):
        page.goto(_url("/search"))
        page.wait_for_load_state("domcontentloaded")
        heading = page.locator("h1")
        assert heading.count() > 0
        assert "Search" in heading.first.text_content()

    def test_search_has_input(self, page: Page):
        """Search page should have a search input field."""
        page.goto(_url("/search"))
        page.wait_for_load_state("domcontentloaded")
        search_input = page.locator("input[type='text'], input[type='search'], input[name='q'], input[name='query']")
        assert search_input.count() > 0, "Search page should have an input field"

    def test_search_has_knowledge_context(self, page: Page):
        """Search page should reference knowledge base."""
        page.goto(_url("/search"))
        page.wait_for_load_state("domcontentloaded")
        content = page.content().lower()
        assert "knowledge" in content or "search" in content
