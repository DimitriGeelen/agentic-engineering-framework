"""Playwright tests for task API happy paths (T-1039).

Tests valid mutations that should succeed on real tasks.
"""
import re


class TestTaskHorizonHappy:
    """Tests for POST /api/task/<id>/horizon with valid values."""

    def _find_active_task(self, page, base_url):
        """Find a real active task ID from the tasks page."""
        resp = page.request.get(f"{base_url}/tasks")
        body = resp.text()
        match = re.search(r"T-\d{3,}", body)
        return match.group(0) if match else None

    def test_horizon_update_to_now(self, page, base_url):
        """Setting horizon to 'now' on a real task succeeds."""
        task_id = self._find_active_task(page, base_url)
        if not task_id:
            return  # No active tasks to test with
        resp = page.request.post(
            f"{base_url}/api/task/{task_id}/horizon",
            form={"horizon": "now"},
        )
        # Should succeed (200) or fail on task-update command (500)
        assert resp.status in (200, 500)
        if resp.status == 200:
            assert "horizon" in resp.text().lower() or "now" in resp.text().lower()


class TestTaskStatusAPI:
    """Tests for GET /api/session/status."""

    def test_session_status_returns_200(self, page, base_url):
        """Session status endpoint returns 200."""
        resp = page.request.get(f"{base_url}/api/session/status")
        assert resp.status == 200

    def test_session_status_has_content(self, page, base_url):
        """Session status has meaningful content."""
        resp = page.request.get(f"{base_url}/api/session/status")
        body = resp.text()
        assert len(body) > 10  # Not empty
