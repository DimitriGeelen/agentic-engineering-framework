"""Playwright tests for Enforcement dashboard (T-986).

Covers: page loads, heading, hooks/gates/tiers sections.
"""
from playwright.sync_api import Page

TEST_URL = "http://localhost:3099"


def _url(path: str) -> str:
    return f"{TEST_URL}{path}"


class TestEnforcementPage:
    """Enforcement dashboard renders with hook and gate information."""

    def test_enforcement_page_loads(self, page: Page):
        resp = page.goto(_url("/enforcement"))
        assert resp.status == 200

    def test_enforcement_has_heading(self, page: Page):
        page.goto(_url("/enforcement"))
        page.wait_for_load_state("domcontentloaded")
        heading = page.locator("h1")
        assert heading.count() > 0
        assert "Enforcement" in heading.first.text_content()

    def test_enforcement_has_hook_info(self, page: Page):
        """Enforcement page should show hook status."""
        page.goto(_url("/enforcement"))
        page.wait_for_load_state("domcontentloaded")
        content = page.content().lower()
        assert "hook" in content

    def test_enforcement_has_tier_info(self, page: Page):
        """Enforcement page should show enforcement tiers."""
        page.goto(_url("/enforcement"))
        page.wait_for_load_state("domcontentloaded")
        content = page.content().lower()
        assert "tier" in content

    def test_enforcement_has_git_hooks(self, page: Page):
        """Enforcement page should show git hook status."""
        page.goto(_url("/enforcement"))
        page.wait_for_load_state("domcontentloaded")
        content = page.content().lower()
        assert "git" in content
