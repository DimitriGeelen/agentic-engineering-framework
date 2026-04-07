"""Playwright tests for Watchtower landing page (T-986).

Covers: page loads, heading, status sections, focus/attention display.
"""
from playwright.sync_api import Page

TEST_URL = "http://localhost:3099"


def _url(path: str) -> str:
    return f"{TEST_URL}{path}"


class TestLandingPage:
    """Landing page renders with dashboard sections."""

    def test_landing_page_loads(self, page: Page):
        resp = page.goto(_url("/"))
        assert resp.status == 200

    def test_landing_has_heading(self, page: Page):
        page.goto(_url("/"))
        page.wait_for_load_state("domcontentloaded")
        heading = page.locator("h1")
        assert heading.count() > 0
        assert "Watchtower" in heading.first.text_content()

    def test_landing_has_status_sections(self, page: Page):
        """Landing page should show focus, audit, and metrics summaries."""
        page.goto(_url("/"))
        page.wait_for_load_state("domcontentloaded")
        content = page.content().lower()
        assert "focus" in content
        assert "audit" in content

    def test_landing_has_task_info(self, page: Page):
        """Landing page should display active task information."""
        page.goto(_url("/"))
        page.wait_for_load_state("domcontentloaded")
        content = page.content().lower()
        assert "active tasks" in content or "attention" in content

    def test_landing_has_approval_section(self, page: Page):
        """Landing page should have approval/action section."""
        page.goto(_url("/"))
        page.wait_for_load_state("domcontentloaded")
        content = page.content().lower()
        assert "approval" in content

    def test_landing_has_test_counts(self, page: Page):
        """Landing page should show test infrastructure counts (T-1010)."""
        page.goto(_url("/"))
        page.wait_for_load_state("domcontentloaded")
        content = page.content().lower()
        assert "playwright" in content
