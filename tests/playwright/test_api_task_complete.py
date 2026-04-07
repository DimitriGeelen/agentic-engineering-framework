"""Playwright tests for task complete API (T-1037).

Tests POST /api/task/<id>/complete error handling.
Route: web/blueprints/tasks.py:521
"""


class TestCompleteTask:
    """Tests for POST /api/task/<id>/complete."""

    def test_complete_invalid_task_id(self, page, base_url):
        """Malformed task ID returns 404."""
        resp = page.request.post(f"{base_url}/api/task/INVALID/complete")
        assert resp.status == 404

    def test_complete_nonexistent_task(self, page, base_url):
        """Nonexistent task returns error."""
        resp = page.request.post(f"{base_url}/api/task/T-99999/complete")
        # May return 404 or 500 depending on task existence
        assert resp.status in (404, 500)
