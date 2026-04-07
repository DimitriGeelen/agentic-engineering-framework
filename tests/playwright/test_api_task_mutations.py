"""Playwright tests for POST task API error handling (T-1026).

Tests validation and error responses for task mutation endpoints
in web/blueprints/tasks.py.
"""


class TestCreateTaskValidation:
    """Tests for POST /api/task/create error cases."""

    def test_create_task_without_name_returns_400(self, page, base_url):
        """Creating a task with empty name returns 400."""
        resp = page.request.post(
            f"{base_url}/api/task/create",
            form={"name": "", "type": "build"},
        )
        assert resp.status == 400
        body = resp.text()
        assert "required" in body.lower()

    def test_create_task_invalid_type_returns_400(self, page, base_url):
        """Creating a task with invalid workflow type returns 400."""
        resp = page.request.post(
            f"{base_url}/api/task/create",
            form={"name": "Test", "type": "invalid"},
        )
        assert resp.status == 400
        body = resp.text()
        assert "invalid" in body.lower()


class TestUpdateHorizonValidation:
    """Tests for POST /api/task/<id>/horizon error cases."""

    def test_update_horizon_invalid_value(self, page, base_url):
        """Setting horizon to invalid value returns 400."""
        resp = page.request.post(
            f"{base_url}/api/task/T-001/horizon",
            form={"horizon": "invalid"},
        )
        assert resp.status == 400
        body = resp.text()
        assert "invalid" in body.lower()

    def test_update_horizon_invalid_task_id(self, page, base_url):
        """Horizon update with malformed task ID returns 404."""
        resp = page.request.post(
            f"{base_url}/api/task/INVALID/horizon",
            form={"horizon": "now"},
        )
        assert resp.status == 404


class TestUpdateStatusValidation:
    """Tests for POST /api/task/<id>/status error cases."""

    def test_update_status_invalid_value(self, page, base_url):
        """Setting status to invalid value returns 400."""
        resp = page.request.post(
            f"{base_url}/api/task/T-001/status",
            form={"status": "invalid"},
        )
        assert resp.status == 400
        body = resp.text()
        assert "invalid" in body.lower()
