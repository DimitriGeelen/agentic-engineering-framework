"""Playwright tests for Constitutional Directives page (T-990).

Covers: page loads, heading, four constitutional directives listed.
"""
from playwright.sync_api import Page

TEST_URL = "http://localhost:3099"


def _url(path: str) -> str:
    return f"{TEST_URL}{path}"


class TestDirectivesPage:
    """Directives page renders with constitutional directive content."""

    def test_directives_page_loads(self, page: Page):
        resp = page.goto(_url("/directives"))
        assert resp.status == 200

    def test_directives_has_heading(self, page: Page):
        page.goto(_url("/directives"))
        page.wait_for_load_state("domcontentloaded")
        heading = page.locator("h1")
        assert heading.count() > 0
        assert "Directive" in heading.first.text_content()

    def test_directives_has_four_directives(self, page: Page):
        """Directives page should list all four constitutional directives."""
        page.goto(_url("/directives"))
        page.wait_for_load_state("domcontentloaded")
        content = page.content().lower()
        assert "antifragil" in content
        assert "reliab" in content
        assert "usab" in content
        assert "portab" in content

    def test_directives_has_constitutional_context(self, page: Page):
        """Directives page should reference constitutional framework."""
        page.goto(_url("/directives"))
        page.wait_for_load_state("domcontentloaded")
        content = page.content().lower()
        assert "constitutional" in content or "directive" in content
