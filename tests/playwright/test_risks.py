"""Playwright tests for Risk Register / Concerns page (T-986).

Covers: page loads, heading, concern entries with severity.
"""
from playwright.sync_api import Page

TEST_URL = "http://localhost:3099"


def _url(path: str) -> str:
    return f"{TEST_URL}{path}"


class TestRisksPage:
    """Risk register page renders with concern data."""

    def test_risks_page_loads(self, page: Page):
        resp = page.goto(_url("/risks"))
        assert resp.status == 200

    def test_risks_has_heading(self, page: Page):
        page.goto(_url("/risks"))
        page.wait_for_load_state("domcontentloaded")
        heading = page.locator("h1")
        assert heading.count() > 0
        assert "Concerns" in heading.first.text_content()

    def test_risks_has_entries(self, page: Page):
        """Risk page should display concern/gap entries."""
        page.goto(_url("/risks"))
        page.wait_for_load_state("domcontentloaded")
        content = page.content().lower()
        assert "concern" in content or "gap" in content

    def test_risks_has_severity(self, page: Page):
        """Risk page should show severity levels."""
        page.goto(_url("/risks"))
        page.wait_for_load_state("domcontentloaded")
        content = page.content().lower()
        assert "high" in content or "medium" in content or "low" in content
