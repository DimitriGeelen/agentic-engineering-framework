"""Playwright tests for search sub-pages (T-1025).

Covers: /search/conversations JSON, /search/feedback/analytics page,
/search/load-conversation without ID.
"""
import json

from playwright.sync_api import Page

TEST_URL = "http://localhost:3099"


def _url(path: str) -> str:
    return f"{TEST_URL}{path}"


class TestSearchExtended:
    """Search sub-endpoints for conversations and feedback."""

    def test_search_conversations_returns_json(self, page: Page):
        """GET /search/conversations should return JSON with conversations key."""
        resp = page.goto(_url("/search/conversations"))
        assert resp.status == 200
        text = page.locator("body").text_content()
        data = json.loads(text)
        assert "conversations" in data

    def test_feedback_analytics_loads(self, page: Page):
        """GET /search/feedback/analytics should render a page with heading."""
        resp = page.goto(_url("/search/feedback/analytics"))
        assert resp.status == 200
        heading = page.locator("h1")
        assert heading.count() > 0

    def test_load_conversation_without_id(self, page: Page):
        """GET /search/load-conversation without id should return 400."""
        resp = page.goto(_url("/search/load-conversation"))
        assert resp.status == 400
        text = page.locator("body").text_content()
        data = json.loads(text)
        assert "error" in data
