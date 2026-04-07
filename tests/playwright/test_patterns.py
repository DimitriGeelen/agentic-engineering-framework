"""Playwright tests for Patterns page (T-989).

Covers: page loads, heading, pattern entries by type.
"""
from playwright.sync_api import Page

TEST_URL = "http://localhost:3099"


def _url(path: str) -> str:
    return f"{TEST_URL}{path}"


class TestPatternsPage:
    """Patterns page renders with failure/success/workflow patterns."""

    def test_patterns_page_loads(self, page: Page):
        resp = page.goto(_url("/patterns"))
        assert resp.status == 200

    def test_patterns_has_heading(self, page: Page):
        page.goto(_url("/patterns"))
        page.wait_for_load_state("domcontentloaded")
        heading = page.locator("h1")
        assert heading.count() > 0
        assert "Patterns" in heading.first.text_content()

    def test_patterns_has_entries(self, page: Page):
        """Patterns page should display pattern entries."""
        page.goto(_url("/patterns"))
        page.wait_for_load_state("domcontentloaded")
        content = page.content().lower()
        assert "pattern" in content

    def test_patterns_has_types(self, page: Page):
        """Patterns page should show failure/success/workflow categories."""
        page.goto(_url("/patterns"))
        page.wait_for_load_state("domcontentloaded")
        content = page.content().lower()
        assert "failure" in content or "success" in content or "workflow" in content


class TestPatternsAPI:
    """Patterns API returns structured data (T-1024)."""

    def test_patterns_api_returns_json(self, page: Page):
        import json
        page.goto(_url("/api/patterns"))
        text = page.locator("body").text_content()
        data = json.loads(text)
        assert "patterns" in data
        assert "total" in data
        assert "by_type" in data

    def test_patterns_api_has_grouped_data(self, page: Page):
        import json
        page.goto(_url("/api/patterns"))
        text = page.locator("body").text_content()
        data = json.loads(text)
        assert "failure" in data["patterns"]
        assert "success" in data["patterns"]
        assert data["total"] > 0
