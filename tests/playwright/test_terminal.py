"""Playwright tests for Terminal page (T-970).

Covers: terminal page loads, xterm container present, tab bar, status indicator.
Note: WebSocket/PTY functionality requires a full server with SocketIO — these
tests verify the UI structure loads correctly.
"""
import pytest
from playwright.sync_api import Page

TEST_URL = "http://localhost:3099"


def _url(path: str) -> str:
    return f"{TEST_URL}{path}"


class TestTerminalPage:
    """Terminal page renders with expected UI elements."""

    def test_terminal_page_loads(self, page: Page):
        resp = page.goto(_url("/terminal"))
        assert resp.status == 200

    def test_terminal_has_container(self, page: Page):
        page.goto(_url("/terminal"))
        page.wait_for_load_state("domcontentloaded")
        container = page.locator("#terminal-container, .terminal-container")
        assert container.count() > 0, "Terminal page should have a terminal container"

    def test_terminal_has_tab_bar(self, page: Page):
        page.goto(_url("/terminal"))
        page.wait_for_load_state("domcontentloaded")
        tabs = page.locator("#session-tabs, .session-tabs")
        assert tabs.count() > 0, "Terminal page should have a session tab bar"

    def test_terminal_has_new_button(self, page: Page):
        page.goto(_url("/terminal"))
        page.wait_for_load_state("domcontentloaded")
        new_btn = page.locator("#new-session, .new-session")
        assert new_btn.count() > 0, "Terminal page should have a New Session button"

    def test_terminal_has_attach_button(self, page: Page):
        page.goto(_url("/terminal"))
        page.wait_for_load_state("domcontentloaded")
        attach_btn = page.locator("#attach-termlink")
        assert attach_btn.count() > 0, "Terminal page should have an Attach TermLink button"

    def test_terminal_has_status_indicator(self, page: Page):
        page.goto(_url("/terminal"))
        page.wait_for_load_state("domcontentloaded")
        status = page.locator("#status-dot, .status-dot")
        assert status.count() > 0, "Terminal page should have a connection status indicator"

    def test_terminal_loads_xterm_css(self, page: Page):
        page.goto(_url("/terminal"))
        page.wait_for_load_state("domcontentloaded")
        content = page.content()
        assert "xterm" in content.lower(), "Terminal page should load xterm.js"

    def test_terminal_has_profile_menu(self, page: Page):
        """Profile selector menu exists in the DOM (T-980)."""
        page.goto(_url("/terminal"))
        page.wait_for_load_state("domcontentloaded")
        menu = page.locator("#profile-menu, .profile-menu")
        assert menu.count() > 0, "Terminal page should have a profile selector menu"
