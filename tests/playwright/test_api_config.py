"""Playwright tests for /config page content (T-1035).

Tests that the config page displays framework settings correctly.
"""
from playwright.sync_api import Page

TEST_URL = "http://localhost:3099"


def _url(path: str) -> str:
    return f"{TEST_URL}{path}"


class TestConfigPageContent:
    """Extended config page content tests."""

    def test_config_has_setting_names(self, page: Page):
        """Config page shows setting names like FW_PORT, FW_CONTEXT_WINDOW."""
        page.goto(_url("/config"))
        page.wait_for_load_state("domcontentloaded")
        content = page.content()
        # Should show at least some framework settings
        assert "FW_PORT" in content or "CONTEXT_WINDOW" in content or "context_window" in content.lower()

    def test_config_has_values(self, page: Page):
        """Config page shows setting values."""
        page.goto(_url("/config"))
        page.wait_for_load_state("domcontentloaded")
        content = page.content()
        # Should show port number or context window value
        assert "3000" in content or "300000" in content or "default" in content.lower()

    def test_config_has_source_info(self, page: Page):
        """Config page shows where settings come from (default, env, file)."""
        page.goto(_url("/config"))
        page.wait_for_load_state("domcontentloaded")
        content = page.content().lower()
        assert "default" in content or "env" in content or "file" in content
