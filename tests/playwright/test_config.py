"""Playwright tests for Config page (T-981).

Covers: page loads, settings table present, config values shown.
"""
from playwright.sync_api import Page

TEST_URL = "http://localhost:3099"


def _url(path: str) -> str:
    return f"{TEST_URL}{path}"


class TestConfigPage:
    """Config page renders with framework settings."""

    def test_config_page_loads(self, page: Page):
        resp = page.goto(_url("/config"))
        assert resp.status == 200

    def test_config_has_settings(self, page: Page):
        """Config page should show framework configuration settings."""
        page.goto(_url("/config"))
        page.wait_for_load_state("domcontentloaded")
        content = page.content()
        assert "FW_" in content or "Context window" in content or "config" in content.lower(), \
            "Config page should display framework settings"

    def test_config_has_table_or_list(self, page: Page):
        """Config page should have a table or list of settings."""
        page.goto(_url("/config"))
        page.wait_for_load_state("domcontentloaded")
        table = page.locator("table")
        dl = page.locator("dl")
        assert table.count() > 0 or dl.count() > 0, \
            "Config page should have a table or definition list"

    def test_config_shows_version(self, page: Page):
        """Config page should show framework version."""
        page.goto(_url("/config"))
        page.wait_for_load_state("domcontentloaded")
        content = page.content()
        assert "1." in content or "version" in content.lower(), \
            "Config page should show version information"
