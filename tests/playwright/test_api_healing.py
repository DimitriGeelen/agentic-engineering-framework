"""Playwright tests for /api/healing/<task_id> endpoint (T-1026).

Tests error handling for the healing diagnose POST endpoint
in web/blueprints/session.py.
"""


class TestHealingValidation:
    """Tests for POST /api/healing/<task_id> error cases."""

    def test_healing_invalid_task_id(self, page, base_url):
        """Healing with malformed task ID returns 400."""
        resp = page.request.post(f"{base_url}/api/healing/INVALID")
        assert resp.status == 400
        body = resp.text()
        assert "invalid" in body.lower()

    def test_healing_nonexistent_task(self, page, base_url):
        """Healing a nonexistent task returns a result (diagnosis may fail gracefully)."""
        resp = page.request.post(f"{base_url}/api/healing/T-99999")
        # The endpoint runs fw healing diagnose and returns 200 with output
        # regardless of whether the task exists (diagnosis output shows the error)
        assert resp.status == 200
        body = resp.text()
        assert "T-99999" in body
