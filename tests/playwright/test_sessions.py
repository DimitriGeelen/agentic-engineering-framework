"""Playwright tests for Sessions page (T-983).

Covers: page loads, summary bar present, terminal link.
"""
from playwright.sync_api import Page

TEST_URL = "http://localhost:3099"


def _url(path: str) -> str:
    return f"{TEST_URL}{path}"


class TestSessionsPage:
    """Sessions page renders with session management UI."""

    def test_sessions_page_loads(self, page: Page):
        resp = page.goto(_url("/sessions"))
        assert resp.status == 200

    def test_sessions_has_heading(self, page: Page):
        page.goto(_url("/sessions"))
        page.wait_for_load_state("domcontentloaded")
        heading = page.locator("h1")
        assert heading.count() > 0
        assert "Sessions" in heading.first.text_content()

    def test_sessions_has_summary_bar(self, page: Page):
        """Sessions page should show active/total counts."""
        page.goto(_url("/sessions"))
        page.wait_for_load_state("domcontentloaded")
        content = page.content()
        assert "active" in content.lower()
        assert "total" in content.lower()

    def test_sessions_has_terminal_link(self, page: Page):
        """Sessions page should link to /terminal."""
        page.goto(_url("/sessions"))
        page.wait_for_load_state("domcontentloaded")
        link = page.locator("a[href='/terminal']")
        assert link.count() > 0, "Sessions page should have a link to the terminal"
