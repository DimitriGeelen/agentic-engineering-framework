"""Playwright tests for timeline task detail API (T-1025).

Tests /api/timeline/task/<task_id> endpoint
from web/blueprints/timeline.py.
"""


class TestTimelineTaskDetail:
    """Tests for /api/timeline/task/<task_id> endpoint."""

    def test_timeline_task_returns_html(self, page, base_url):
        """Task detail endpoint returns HTML for a valid task ID."""
        resp = page.request.get(f"{base_url}/api/timeline/task/T-001")
        assert resp.status == 200
        body = resp.text()
        assert "<" in body  # Contains HTML markup

    def test_timeline_task_invalid_id(self, page, base_url):
        """Task detail endpoint returns 404 for invalid task IDs."""
        resp = page.request.get(f"{base_url}/api/timeline/task/INVALID")
        assert resp.status == 404

    def test_timeline_task_with_episodic(self, page, base_url):
        """Task with episodic data returns rendered HTML content."""
        resp = page.request.get(f"{base_url}/api/timeline/task/T-001")
        assert resp.status == 200
        body = resp.text()
        # Episodic data renders task summary, outcomes, decisions etc
        assert "<" in body  # Contains HTML
        assert len(body) > 100  # Substantial rendered content
