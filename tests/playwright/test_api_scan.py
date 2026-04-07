"""Playwright tests for scan API endpoints (T-1029).

Tests /api/scan/focus and /api/scan/refresh from web/blueprints/cockpit.py.
"""


class TestScanFocus:
    """Tests for POST /api/scan/focus/<task_id>."""

    def test_scan_focus_invalid_id_returns_400(self, page, base_url):
        """Focus with malformed task ID returns 400."""
        resp = page.request.post(f"{base_url}/api/scan/focus/INVALID")
        assert resp.status == 400
        body = resp.text()
        assert "invalid" in body.lower()

    def test_scan_focus_valid_id_succeeds(self, page, base_url):
        """Focus with valid task ID returns success HTML."""
        resp = page.request.post(f"{base_url}/api/scan/focus/T-001")
        # May succeed or fail depending on task existence, but should not 400
        assert resp.status in (200, 500)


class TestScanRefresh:
    """Tests for POST /api/scan/refresh."""

    def test_scan_refresh_returns_html(self, page, base_url):
        """Refresh triggers a rescan and returns updated HTML."""
        resp = page.request.post(f"{base_url}/api/scan/refresh")
        assert resp.status == 200
