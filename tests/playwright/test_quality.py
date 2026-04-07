"""Playwright tests for Quality Gate page (T-986).

Covers: page loads, heading, audit/traceability/episodic sections.
"""
from playwright.sync_api import Page

TEST_URL = "http://localhost:3099"


def _url(path: str) -> str:
    return f"{TEST_URL}{path}"


class TestQualityPage:
    """Quality gate page renders with audit and compliance data."""

    def test_quality_page_loads(self, page: Page):
        resp = page.goto(_url("/quality"))
        assert resp.status == 200

    def test_quality_has_heading(self, page: Page):
        page.goto(_url("/quality"))
        page.wait_for_load_state("networkidle")
        heading = page.locator("h1")
        assert heading.count() > 0
        assert "Quality" in heading.first.text_content()

    def test_quality_has_audit_info(self, page: Page):
        """Quality page should show audit status."""
        page.goto(_url("/quality"))
        page.wait_for_load_state("networkidle")
        content = page.content().lower()
        assert "audit" in content

    def test_quality_has_traceability(self, page: Page):
        """Quality page should show traceability metrics."""
        page.goto(_url("/quality"))
        page.wait_for_load_state("networkidle")
        content = page.content().lower()
        assert "traceability" in content

    def test_quality_has_status_indicator(self, page: Page):
        """Quality page should show pass/warn/fail status."""
        page.goto(_url("/quality"))
        page.wait_for_load_state("networkidle")
        content = page.content().lower()
        assert "pass" in content or "warn" in content or "fail" in content


class TestTestSummaryAPI:
    """Test summary API returns structured data (T-1016)."""

    def test_api_returns_json(self, page: Page):
        import json
        page.goto(_url("/api/test-summary"))
        text = page.locator("body").text_content()
        data = json.loads(text)
        assert "suites" in data
        assert "total_files" in data
        assert data["total_files"] > 0

    def test_api_has_playwright_suite(self, page: Page):
        import json
        page.goto(_url("/api/test-summary"))
        text = page.locator("body").text_content()
        data = json.loads(text)
        assert "playwright" in data["suites"]
        assert data["suites"]["playwright"]["files"] > 0
