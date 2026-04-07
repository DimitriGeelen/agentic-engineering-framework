"""Playwright tests for Generated Docs page (T-987).

Covers: page loads, heading, component reference listing.
"""
from playwright.sync_api import Page

TEST_URL = "http://localhost:3099"


def _url(path: str) -> str:
    return f"{TEST_URL}{path}"


class TestDocsPage:
    """Generated docs page renders with component references."""

    def test_docs_page_loads(self, page: Page):
        resp = page.goto(_url("/docs/generated"))
        assert resp.status == 200

    def test_docs_has_heading(self, page: Page):
        page.goto(_url("/docs/generated"))
        page.wait_for_load_state("domcontentloaded")
        heading = page.locator("h1")
        assert heading.count() > 0
        assert "Component" in heading.first.text_content() or "Doc" in heading.first.text_content()

    def test_docs_has_component_list(self, page: Page):
        """Docs page should list component references."""
        page.goto(_url("/docs/generated"))
        page.wait_for_load_state("domcontentloaded")
        content = page.content().lower()
        assert "component" in content

    def test_docs_has_fabric_context(self, page: Page):
        """Docs page should reference fabric/card data."""
        page.goto(_url("/docs/generated"))
        page.wait_for_load_state("domcontentloaded")
        content = page.content().lower()
        assert "fabric" in content or "card" in content
