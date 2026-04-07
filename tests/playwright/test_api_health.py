"""Playwright tests for health endpoints (T-1033).

Tests /health (app-level) and /api/v1/health (API-level).
"""
import json

from playwright.sync_api import Page

TEST_URL = "http://localhost:3099"


def _url(path: str) -> str:
    return f"{TEST_URL}{path}"


class TestAppHealth:
    """Tests for GET /health (app-level health check)."""

    def test_health_returns_json(self, page: Page):
        """App health returns JSON with app status."""
        resp = page.goto(_url("/health"))
        assert resp.status == 200
        text = page.locator("body").text_content()
        data = json.loads(text)
        assert "app" in data
        assert data["app"] == "ok"

    def test_health_has_tests_info(self, page: Page):
        """Health includes test suite counts."""
        resp = page.goto(_url("/health"))
        text = page.locator("body").text_content()
        data = json.loads(text)
        assert "tests" in data
        assert "playwright" in data["tests"]


class TestApiHealth:
    """Tests for GET /api/v1/health (API-level health check)."""

    def test_api_health_returns_json(self, page: Page):
        """API health returns JSON with status and providers."""
        resp = page.goto(_url("/api/v1/health"))
        assert resp.status == 200
        text = page.locator("body").text_content()
        data = json.loads(text)
        assert "status" in data
        assert data["status"] == "ok"

    def test_api_health_has_providers(self, page: Page):
        """API health includes provider information."""
        resp = page.goto(_url("/api/v1/health"))
        text = page.locator("body").text_content()
        data = json.loads(text)
        assert "providers" in data
        assert "active_provider" in data
