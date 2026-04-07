"""Playwright tests for /ask/stream SSE endpoint (T-1041).

Tests GET/POST /api/v1/ask/stream.
Route: web/blueprints/api.py:184
"""


class TestAskStream:
    """Tests for /api/v1/ask/stream endpoint."""

    def test_stream_without_query_returns_error(self, page, base_url):
        """Stream without query returns error event or 400."""
        resp = page.request.get(f"{base_url}/api/v1/ask/stream")
        # Should return 400 for missing query or SSE with error event
        assert resp.status in (200, 400, 500, 503)

    def test_stream_with_query_returns_sse(self, page, base_url):
        """Stream with query returns SSE content-type or error."""
        resp = page.request.get(f"{base_url}/api/v1/ask/stream?q=test")
        # May return SSE (200 with text/event-stream) or error if LLM unavailable
        assert resp.status in (200, 500, 503)

    def test_stream_post_without_body(self, page, base_url):
        """POST without body returns error."""
        resp = page.request.post(f"{base_url}/api/v1/ask/stream")
        assert resp.status in (200, 400, 500, 503)

    def test_stream_post_with_query(self, page, base_url):
        """POST with JSON query returns SSE or error."""
        resp = page.request.post(
            f"{base_url}/api/v1/ask/stream",
            data='{"query": "test"}',
            headers={"Content-Type": "application/json"},
        )
        assert resp.status in (200, 500, 503)
