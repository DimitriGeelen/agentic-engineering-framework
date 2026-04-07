"""Playwright tests for /api/v1 index endpoint (T-1034).

Tests the self-documenting API index.
Route: web/blueprints/api.py:21
"""
import json

from playwright.sync_api import Page

TEST_URL = "http://localhost:3099"


def _url(path: str) -> str:
    return f"{TEST_URL}{path}"


class TestApiIndex:
    """Tests for GET /api/v1/ (API index)."""

    def test_api_index_returns_json(self, page: Page):
        """API index returns JSON with name and version."""
        resp = page.goto(_url("/api/v1/"))
        assert resp.status == 200
        text = page.locator("body").text_content()
        data = json.loads(text)
        assert "name" in data
        assert data["name"] == "Watchtower API"
        assert data["version"] == "v1"

    def test_api_index_has_endpoints(self, page: Page):
        """API index lists available endpoints."""
        resp = page.goto(_url("/api/v1/"))
        text = page.locator("body").text_content()
        data = json.loads(text)
        assert "endpoints" in data
        assert "ask" in data["endpoints"]
        assert "search" in data["endpoints"]
        assert "health" in data["endpoints"]

    def test_api_index_endpoints_have_urls(self, page: Page):
        """Each endpoint has url and methods."""
        resp = page.goto(_url("/api/v1/"))
        text = page.locator("body").text_content()
        data = json.loads(text)
        for name, endpoint in data["endpoints"].items():
            assert "url" in endpoint, f"{name} missing url"
            assert "methods" in endpoint, f"{name} missing methods"
