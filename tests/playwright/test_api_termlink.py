"""Playwright tests for TermLink sessions API (T-1025).

Tests /api/termlink/sessions endpoint
from web/blueprints/terminal.py.
"""


class TestTermlinkSessions:
    """Tests for /api/termlink/sessions endpoint."""

    def test_termlink_sessions_returns_json(self, page, base_url):
        """TermLink sessions endpoint returns 200 with a JSON array."""
        resp = page.request.get(f"{base_url}/api/termlink/sessions")
        assert resp.status == 200
        data = resp.json()
        assert isinstance(data, list)
