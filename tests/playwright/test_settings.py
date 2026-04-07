"""Playwright tests for Settings page (T-987).

Covers: page loads, heading, configuration sections.
"""
from playwright.sync_api import Page

TEST_URL = "http://localhost:3099"


def _url(path: str) -> str:
    return f"{TEST_URL}{path}"


class TestSettingsPage:
    """Settings page renders with configuration options."""

    TIMEOUT = 60000

    def test_settings_page_loads(self, page: Page):
        resp = page.goto(_url("/settings/"), timeout=self.TIMEOUT)
        assert resp.status == 200

    def test_settings_has_heading(self, page: Page):
        page.goto(_url("/settings/"), timeout=self.TIMEOUT)
        page.wait_for_load_state("domcontentloaded")
        heading = page.locator("h1")
        assert heading.count() > 0
        assert "Settings" in heading.first.text_content()

    def test_settings_has_config_sections(self, page: Page):
        """Settings page should show configuration options."""
        page.goto(_url("/settings/"), timeout=self.TIMEOUT)
        page.wait_for_load_state("domcontentloaded")
        content = page.content().lower()
        assert "model" in content or "config" in content

    def test_settings_has_ollama_section(self, page: Page):
        """Settings page should show Ollama configuration."""
        page.goto(_url("/settings/"), timeout=self.TIMEOUT)
        page.wait_for_load_state("domcontentloaded")
        content = page.content().lower()
        assert "ollama" in content
