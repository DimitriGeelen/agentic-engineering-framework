"""Playwright interaction tests — dark mode, search, task filtering (T-1015).

Tests interactive UI features beyond simple page loads.
"""
from playwright.sync_api import Page

TEST_URL = "http://localhost:3099"


def _url(path: str) -> str:
    return f"{TEST_URL}{path}"


class TestDarkMode:
    """Dark mode toggle works."""

    TIMEOUT = 60000

    def test_toggle_exists(self, page: Page):
        """Theme toggle button is present."""
        page.goto(_url("/"), timeout=self.TIMEOUT)
        page.wait_for_load_state("domcontentloaded")
        toggle = page.locator(".theme-toggle")
        assert toggle.count() > 0

    def test_starts_in_light_mode(self, page: Page):
        """Default theme is light."""
        page.goto(_url("/"), timeout=self.TIMEOUT)
        page.wait_for_load_state("domcontentloaded")
        theme = page.locator("html").get_attribute("data-theme")
        assert theme == "light"

    def test_toggle_switches_theme(self, page: Page):
        """Clicking toggle changes theme attribute."""
        page.goto(_url("/"), timeout=self.TIMEOUT)
        page.wait_for_load_state("domcontentloaded")
        page.evaluate("wtToggleTheme()")
        theme = page.locator("html").get_attribute("data-theme")
        assert theme == "dark"
        page.evaluate("wtToggleTheme()")
        theme = page.locator("html").get_attribute("data-theme")
        assert theme == "light"


class TestSearch:
    """Search page interaction."""

    TIMEOUT = 60000

    def test_search_input_exists(self, page: Page):
        """Search page has an input field."""
        page.goto(_url("/search"), timeout=self.TIMEOUT)
        page.wait_for_load_state("domcontentloaded")
        search_input = page.locator("#search-input")
        assert search_input.count() > 0

    def test_search_mode_selector(self, page: Page):
        """Search page has mode selection."""
        page.goto(_url("/search"), timeout=self.TIMEOUT)
        page.wait_for_load_state("domcontentloaded")
        mode_select = page.locator("#search-mode-select")
        assert mode_select.count() > 0


class TestTaskPage:
    """Task page has interactive elements."""

    TIMEOUT = 60000

    def test_tasks_has_filter_controls(self, page: Page):
        """Tasks page should have filter/status controls."""
        page.goto(_url("/tasks"), timeout=self.TIMEOUT)
        page.wait_for_load_state("domcontentloaded")
        content = page.content().lower()
        assert "filter" in content or "status" in content or "horizon" in content

    def test_tasks_has_task_cards(self, page: Page):
        """Tasks page should display task entries."""
        page.goto(_url("/tasks"), timeout=self.TIMEOUT)
        page.wait_for_load_state("domcontentloaded")
        content = page.content()
        # Should have T-XXX task references
        assert "T-" in content
