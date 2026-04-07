"""Playwright tests for scan action endpoints (T-1041).

Tests POST /api/scan/approve, /api/scan/defer, /api/scan/apply.
Route: web/blueprints/cockpit.py:216-300
"""


class TestScanApprove:
    """Tests for POST /api/scan/approve/<rec_id>."""

    def test_approve_nonexistent_rec(self, page, base_url):
        """Approving nonexistent recommendation returns 400 or 404."""
        resp = page.request.post(f"{base_url}/api/scan/approve/FAKE-REC-999")
        assert resp.status in (400, 404)

    def test_approve_empty_rec_id(self, page, base_url):
        """Approve with empty rec_id hits 404 (no route match)."""
        resp = page.request.post(f"{base_url}/api/scan/approve/")
        # Flask won't match the route without a rec_id segment
        assert resp.status in (404, 405, 308)


class TestScanDefer:
    """Tests for POST /api/scan/defer/<rec_id>."""

    def test_defer_nonexistent_rec(self, page, base_url):
        """Deferring nonexistent recommendation returns 400 or 404."""
        resp = page.request.post(
            f"{base_url}/api/scan/defer/FAKE-REC-999",
            form={"reason": "test defer"},
        )
        assert resp.status in (400, 404)

    def test_defer_without_reason(self, page, base_url):
        """Defer without reason still works (has default)."""
        resp = page.request.post(f"{base_url}/api/scan/defer/FAKE-REC-999")
        # Should return 400 (no scan data) or 404 (rec not found)
        assert resp.status in (400, 404)


class TestScanApply:
    """Tests for POST /api/scan/apply/<rec_id>."""

    def test_apply_nonexistent_rec(self, page, base_url):
        """Applying nonexistent recommendation returns 400 or 404."""
        resp = page.request.post(f"{base_url}/api/scan/apply/FAKE-REC-999")
        assert resp.status in (400, 404)

    def test_apply_empty_rec_id(self, page, base_url):
        """Apply with empty rec_id hits 404."""
        resp = page.request.post(f"{base_url}/api/scan/apply/")
        assert resp.status in (404, 405, 308)
