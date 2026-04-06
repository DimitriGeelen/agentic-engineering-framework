"""Playwright tests for web terminal session API (T-979).

Tests /api/sessions CRUD and /api/sessions/profiles endpoints
added by T-967 (provider registry + session profiles).
"""

import json


class TestSessionProfiles:
    """Tests for /api/sessions/profiles endpoint."""

    def test_profiles_returns_json(self, page, base_url):
        """Profiles endpoint returns valid JSON."""
        resp = page.request.get(f"{base_url}/api/sessions/profiles")
        assert resp.status == 200
        data = resp.json()
        assert isinstance(data, dict)

    def test_profiles_has_four_defaults(self, page, base_url):
        """Default profiles include local-bash, local-zsh, claude-code, claude-dispatch."""
        resp = page.request.get(f"{base_url}/api/sessions/profiles")
        data = resp.json()
        assert "local-bash" in data
        assert "local-zsh" in data
        assert "claude-code" in data
        assert "claude-dispatch" in data

    def test_profile_has_required_fields(self, page, base_url):
        """Each profile has name, type, provider, and ui fields."""
        resp = page.request.get(f"{base_url}/api/sessions/profiles")
        data = resp.json()
        for profile_id, profile in data.items():
            assert "name" in profile, f"{profile_id} missing name"
            assert "type" in profile, f"{profile_id} missing type"
            assert "provider" in profile, f"{profile_id} missing provider"
            assert "ui" in profile, f"{profile_id} missing ui"

    def test_profile_provider_has_name(self, page, base_url):
        """Each profile's provider has a name field."""
        resp = page.request.get(f"{base_url}/api/sessions/profiles")
        data = resp.json()
        for profile_id, profile in data.items():
            assert "name" in profile["provider"], f"{profile_id} provider missing name"


class TestSessionList:
    """Tests for GET /api/sessions."""

    def test_sessions_returns_list(self, page, base_url):
        """Sessions endpoint returns a JSON array."""
        resp = page.request.get(f"{base_url}/api/sessions")
        assert resp.status == 200
        data = resp.json()
        assert isinstance(data, list)

    def test_sessions_filterable_by_provider(self, page, base_url):
        """Sessions can be filtered by provider query param."""
        resp = page.request.get(f"{base_url}/api/sessions?provider=local")
        assert resp.status == 200
        data = resp.json()
        assert isinstance(data, list)

    def test_sessions_filterable_by_status(self, page, base_url):
        """Sessions can be filtered by status query param."""
        resp = page.request.get(f"{base_url}/api/sessions?status=active")
        assert resp.status == 200
        data = resp.json()
        assert isinstance(data, list)


class TestSessionCRUD:
    """Tests for session create/get/delete lifecycle."""

    def test_create_session_returns_201(self, page, base_url):
        """Creating a session returns 201 with session data."""
        resp = page.request.post(
            f"{base_url}/api/sessions",
            data=json.dumps({"profile": "local-bash"}),
            headers={"Content-Type": "application/json"},
        )
        assert resp.status == 201
        data = resp.json()
        assert "id" in data
        assert data["status"] == "active"
        assert data["provider"]["name"] == "local"

        # Cleanup: delete the session
        session_id = data["id"]
        page.request.delete(f"{base_url}/api/sessions/{session_id}")

    def test_get_session_by_id(self, page, base_url):
        """Can retrieve a created session by ID."""
        # Create
        resp = page.request.post(
            f"{base_url}/api/sessions",
            data=json.dumps({"profile": "local-bash"}),
            headers={"Content-Type": "application/json"},
        )
        session_id = resp.json()["id"]

        # Get
        resp = page.request.get(f"{base_url}/api/sessions/{session_id}")
        assert resp.status == 200
        data = resp.json()
        assert data["id"] == session_id

        # Cleanup
        page.request.delete(f"{base_url}/api/sessions/{session_id}")

    def test_delete_session(self, page, base_url):
        """Deleting a session kills and removes it."""
        # Create
        resp = page.request.post(
            f"{base_url}/api/sessions",
            data=json.dumps({"profile": "local-bash"}),
            headers={"Content-Type": "application/json"},
        )
        session_id = resp.json()["id"]

        # Delete
        resp = page.request.delete(f"{base_url}/api/sessions/{session_id}")
        assert resp.status == 200
        data = resp.json()
        assert data["deleted"] == session_id

        # Verify gone
        resp = page.request.get(f"{base_url}/api/sessions/{session_id}")
        assert resp.status == 404

    def test_get_nonexistent_returns_404(self, page, base_url):
        """Getting a non-existent session returns 404."""
        resp = page.request.get(f"{base_url}/api/sessions/S-0000-0000-xxxx")
        assert resp.status == 404

    def test_session_appears_in_list(self, page, base_url):
        """Created session appears in the sessions list."""
        # Create
        resp = page.request.post(
            f"{base_url}/api/sessions",
            data=json.dumps({"profile": "local-bash"}),
            headers={"Content-Type": "application/json"},
        )
        session_id = resp.json()["id"]

        # List
        resp = page.request.get(f"{base_url}/api/sessions")
        data = resp.json()
        session_ids = [s["id"] for s in data]
        assert session_id in session_ids

        # Cleanup
        page.request.delete(f"{base_url}/api/sessions/{session_id}")
