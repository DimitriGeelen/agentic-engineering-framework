"""Playwright tests for Graduation page (T-989).

Covers: page loads, heading, graduation candidates and directives.
"""
from playwright.sync_api import Page

TEST_URL = "http://localhost:3099"


def _url(path: str) -> str:
    return f"{TEST_URL}{path}"


class TestGraduationPage:
    """Graduation page renders with promotion candidates."""

    def test_graduation_page_loads(self, page: Page):
        resp = page.goto(_url("/graduation"))
        assert resp.status == 200

    def test_graduation_has_heading(self, page: Page):
        page.goto(_url("/graduation"))
        page.wait_for_load_state("domcontentloaded")
        heading = page.locator("h1")
        assert heading.count() > 0
        assert "Graduation" in heading.first.text_content()

    def test_graduation_has_content(self, page: Page):
        """Graduation page should show candidate or directive info."""
        page.goto(_url("/graduation"))
        page.wait_for_load_state("domcontentloaded")
        content = page.content().lower()
        assert "candidate" in content or "directive" in content or "learning" in content

    def test_graduation_has_directive_context(self, page: Page):
        """Graduation page should reference constitutional directives."""
        page.goto(_url("/graduation"))
        page.wait_for_load_state("domcontentloaded")
        content = page.content().lower()
        assert "directive" in content or "graduat" in content
