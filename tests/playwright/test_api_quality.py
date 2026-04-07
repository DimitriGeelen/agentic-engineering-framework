"""Playwright tests for quality API endpoints (T-1030).

Tests /api/test-summary, /api/audit/run, and /api/tests/run
from web/blueprints/quality.py.
"""
import json

from playwright.sync_api import Page

TEST_URL = "http://localhost:3099"


def _url(path: str) -> str:
    return f"{TEST_URL}{path}"


class TestTestSummary:
    """Tests for GET /api/test-summary."""

    def test_test_summary_returns_json(self, page: Page):
        """Test summary returns valid JSON with suites and total."""
        resp = page.goto(_url("/api/test-summary"))
        assert resp.status == 200
        text = page.locator("body").text_content()
        data = json.loads(text)
        assert "suites" in data
        assert "total_files" in data

    def test_test_summary_has_playwright_suite(self, page: Page):
        """Test summary includes playwright suite."""
        resp = page.goto(_url("/api/test-summary"))
        text = page.locator("body").text_content()
        data = json.loads(text)
        assert "playwright" in data["suites"]
        assert data["suites"]["playwright"]["files"] > 0

    def test_test_summary_total_count(self, page: Page):
        """Total file count should be positive."""
        resp = page.goto(_url("/api/test-summary"))
        text = page.locator("body").text_content()
        data = json.loads(text)
        assert data["total_files"] > 0


    def test_test_summary_has_multiple_suites(self, page: Page):
        """Test summary includes multiple test suites."""
        resp = page.goto(_url("/api/test-summary"))
        text = page.locator("body").text_content()
        data = json.loads(text)
        # Should have at least playwright and one of unit/integration/web
        assert len(data["suites"]) >= 2
