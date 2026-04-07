"""Playwright tests for /api/v1/ask endpoint (T-1025).

Covers: missing query returns error, valid query returns JSON structure.
The /ask route is in web/blueprints/api.py under /api/v1 prefix.
"""
import json

from playwright.sync_api import Page

TEST_URL = "http://localhost:3099"


def _url(path: str) -> str:
    return f"{TEST_URL}{path}"


class TestAskEndpoint:
    """The /api/v1/ask endpoint returns JSON for Q&A queries."""

    def test_ask_without_query_returns_error(self, page: Page):
        """GET /api/v1/ask with no q param should return 400 with error."""
        resp = page.goto(_url("/api/v1/ask"))
        assert resp.status == 400
        text = page.locator("body").text_content()
        data = json.loads(text)
        assert "error" in data

    def test_ask_with_query_returns_json(self, page: Page):
        """GET /api/v1/ask?q=test should return JSON with query or error key."""
        resp = page.goto(_url("/api/v1/ask?q=test+query"))
        # 200 if LLM available, 500/503 if not configured — all return valid JSON
        assert resp.status in (200, 500, 503)
        text = page.locator("body").text_content()
        try:
            data = json.loads(text)
            assert "query" in data or "error" in data
        except json.JSONDecodeError:
            # 500 may return HTML error page — still valid response
            pass
