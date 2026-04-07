"""Playwright tests for /api/v1/search endpoint (T-1034).

Tests search query validation and result structure.
Route: web/blueprints/api.py:219
"""
import json

from playwright.sync_api import Page

TEST_URL = "http://localhost:3099"


def _url(path: str) -> str:
    return f"{TEST_URL}{path}"


class TestApiSearch:
    """Tests for GET /api/v1/search."""

    def test_search_without_query_returns_400(self, page: Page):
        """Missing query parameter returns 400."""
        resp = page.goto(_url("/api/v1/search"))
        assert resp.status == 400
        text = page.locator("body").text_content()
        data = json.loads(text)
        assert "error" in data

    def test_search_short_query_returns_400(self, page: Page):
        """Single-character query returns 400."""
        resp = page.goto(_url("/api/v1/search?q=a"))
        assert resp.status == 400
        text = page.locator("body").text_content()
        data = json.loads(text)
        assert "error" in data

    def test_search_valid_query_returns_json(self, page: Page):
        """Valid query returns JSON with results structure."""
        resp = page.goto(_url("/api/v1/search?q=healing+loop"))
        assert resp.status == 200
        text = page.locator("body").text_content()
        data = json.loads(text)
        assert "query" in data
        assert "results" in data
        assert "total" in data

    def test_search_keyword_mode(self, page: Page):
        """Keyword mode search returns valid results."""
        resp = page.goto(_url("/api/v1/search?q=task&mode=keyword&limit=5"))
        assert resp.status == 200
        text = page.locator("body").text_content()
        data = json.loads(text)
        assert data["query"] == "task"
        assert len(data["results"]) <= 5
