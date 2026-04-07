"""Playwright tests for /health endpoint (T-1008).

Covers: health check returns JSON with app, tests, embeddings status.
"""
import json

from playwright.sync_api import Page

TEST_URL = "http://localhost:3099"


def _url(path: str) -> str:
    return f"{TEST_URL}{path}"


class TestHealthEndpoint:
    """Health endpoint returns structured JSON with component status."""

    def test_health_returns_ok(self, page: Page):
        resp = page.goto(_url("/health"))
        # 200 if all healthy, 503 if Ollama unreachable (still valid)
        assert resp.status in (200, 503)

    def test_health_returns_json(self, page: Page):
        page.goto(_url("/health"))
        content = page.content()
        # Extract JSON from pre tag (browsers wrap JSON in pre/body)
        text = page.locator("body").text_content()
        data = json.loads(text)
        assert "app" in data
        assert data["app"] == "ok"

    def test_health_has_tests_section(self, page: Page):
        """Health endpoint should include test infrastructure counts."""
        page.goto(_url("/health"))
        text = page.locator("body").text_content()
        data = json.loads(text)
        assert "tests" in data
        tests = data["tests"]
        assert "playwright" in tests
        assert "unit" in tests
        assert tests["playwright"] > 0
        assert tests["unit"] > 0

    def test_health_has_embeddings(self, page: Page):
        """Health endpoint should include embeddings status."""
        page.goto(_url("/health"))
        text = page.locator("body").text_content()
        data = json.loads(text)
        assert "embeddings" in data
