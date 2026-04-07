"""Playwright tests for Discoveries dashboard (T-987).

Covers: page loads, heading, discovery/finding entries.
"""
from playwright.sync_api import Page

TEST_URL = "http://localhost:3099"


def _url(path: str) -> str:
    return f"{TEST_URL}{path}"


class TestDiscoveriesPage:
    """Discoveries dashboard renders with audit discovery data."""

    def test_discoveries_page_loads(self, page: Page):
        resp = page.goto(_url("/discoveries"))
        assert resp.status == 200

    def test_discoveries_has_heading(self, page: Page):
        page.goto(_url("/discoveries"))
        page.wait_for_load_state("domcontentloaded")
        heading = page.locator("h1")
        assert heading.count() > 0
        assert "Discoveries" in heading.first.text_content()

    def test_discoveries_has_content(self, page: Page):
        """Discoveries page should show finding or discovery entries."""
        page.goto(_url("/discoveries"))
        page.wait_for_load_state("domcontentloaded")
        content = page.content().lower()
        assert "finding" in content or "discover" in content

    def test_discoveries_has_audit_context(self, page: Page):
        """Discoveries page should reference audit data."""
        page.goto(_url("/discoveries"))
        page.wait_for_load_state("domcontentloaded")
        content = page.content().lower()
        assert "audit" in content or "gap" in content
