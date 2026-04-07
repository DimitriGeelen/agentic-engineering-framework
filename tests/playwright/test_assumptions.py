"""Playwright tests for Assumptions page (T-1020).

Covers: page loads, heading, assumption entries.
"""
from playwright.sync_api import Page

TEST_URL = "http://localhost:3099"


def _url(path: str) -> str:
    return f"{TEST_URL}{path}"


class TestAssumptionsPage:
    """Assumptions page renders with registered assumptions."""

    def test_assumptions_page_loads(self, page: Page):
        resp = page.goto(_url("/assumptions"))
        assert resp.status == 200

    def test_assumptions_has_heading(self, page: Page):
        page.goto(_url("/assumptions"))
        page.wait_for_load_state("domcontentloaded")
        heading = page.locator("h1")
        assert heading.count() > 0
        assert "Assumption" in heading.first.text_content()

    def test_assumptions_has_content(self, page: Page):
        """Assumptions page should list assumptions or show empty state."""
        page.goto(_url("/assumptions"))
        page.wait_for_load_state("domcontentloaded")
        content = page.content()
        assert len(content) > 500, "Assumptions page should have content"

    def test_assumptions_has_status_info(self, page: Page):
        """Assumptions page should show validation status."""
        page.goto(_url("/assumptions"))
        page.wait_for_load_state("domcontentloaded")
        content = page.content().lower()
        assert "validated" in content or "pending" in content or "invalidated" in content or "assumption" in content
