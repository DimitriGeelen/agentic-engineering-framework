"""Playwright tests for task inline edit API endpoints (T-1029).

Tests /api/task/<id>/name, /api/task/<id>/description, /api/task/<id>/toggle-ac
error handling from web/blueprints/tasks.py.
"""


class TestUpdateTaskName:
    """Tests for POST /api/task/<id>/name error cases."""

    def test_name_empty_returns_400(self, page, base_url):
        """Empty name returns 400."""
        resp = page.request.post(
            f"{base_url}/api/task/T-001/name",
            form={"name": ""},
        )
        assert resp.status == 400
        assert "empty" in resp.text().lower()

    def test_name_invalid_task_id(self, page, base_url):
        """Malformed task ID returns 404."""
        resp = page.request.post(
            f"{base_url}/api/task/INVALID/name",
            form={"name": "Test"},
        )
        assert resp.status == 404

    def test_name_nonexistent_task(self, page, base_url):
        """Nonexistent task returns 404."""
        resp = page.request.post(
            f"{base_url}/api/task/T-99999/name",
            form={"name": "Test"},
        )
        assert resp.status == 404


class TestUpdateTaskDescription:
    """Tests for POST /api/task/<id>/description error cases."""

    def test_description_empty_returns_400(self, page, base_url):
        """Empty description returns 400."""
        resp = page.request.post(
            f"{base_url}/api/task/T-001/description",
            form={"description": ""},
        )
        assert resp.status == 400
        assert "empty" in resp.text().lower()

    def test_description_invalid_task_id(self, page, base_url):
        """Malformed task ID returns 404."""
        resp = page.request.post(
            f"{base_url}/api/task/INVALID/description",
            form={"description": "Test"},
        )
        assert resp.status == 404


class TestToggleAC:
    """Tests for POST /api/task/<id>/toggle-ac error cases."""

    def test_toggle_ac_invalid_line(self, page, base_url):
        """Invalid line index returns 400."""
        resp = page.request.post(
            f"{base_url}/api/task/T-001/toggle-ac",
            form={"line": "invalid"},
        )
        assert resp.status == 400

    def test_toggle_ac_invalid_task_id(self, page, base_url):
        """Malformed task ID returns 404."""
        resp = page.request.post(
            f"{base_url}/api/task/INVALID/toggle-ac",
            form={"line": "0"},
        )
        assert resp.status == 404


class TestUpdateTaskOwner:
    """Tests for POST /api/task/<id>/owner error cases."""

    def test_owner_invalid_value(self, page, base_url):
        """Invalid owner value returns 400."""
        resp = page.request.post(
            f"{base_url}/api/task/T-001/owner",
            form={"owner": "invalid"},
        )
        assert resp.status == 400
        assert "invalid" in resp.text().lower()

    def test_owner_invalid_task_id(self, page, base_url):
        """Malformed task ID returns 404."""
        resp = page.request.post(
            f"{base_url}/api/task/INVALID/owner",
            form={"owner": "human"},
        )
        assert resp.status == 404


class TestUpdateTaskType:
    """Tests for POST /api/task/<id>/type error cases."""

    def test_type_invalid_value(self, page, base_url):
        """Invalid workflow type returns 400."""
        resp = page.request.post(
            f"{base_url}/api/task/T-001/type",
            form={"type": "invalid"},
        )
        assert resp.status == 400

    def test_type_invalid_task_id(self, page, base_url):
        """Malformed task ID returns 404."""
        resp = page.request.post(
            f"{base_url}/api/task/INVALID/type",
            form={"type": "build"},
        )
        assert resp.status == 404
