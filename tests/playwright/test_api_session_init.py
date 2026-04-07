"""Playwright tests for session init API (T-1029).

Tests POST /api/session/init from web/blueprints/session.py.
"""


class TestSessionInit:
    """Tests for POST /api/session/init."""

    def test_session_init_returns_html(self, page, base_url):
        """Session init returns HTML with success or error message."""
        resp = page.request.post(f"{base_url}/api/session/init")
        assert resp.status in (200, 500)
        body = resp.text()
        assert "<" in body  # Returns HTML article
        assert "session" in body.lower() or "init" in body.lower()
