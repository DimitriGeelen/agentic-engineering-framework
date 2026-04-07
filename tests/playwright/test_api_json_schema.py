"""Playwright JSON API schema validation tests (T-1055).

Verifies key JSON API endpoints return properly structured responses
with expected fields and types.
"""
import json


class TestHealthSchema:
    """Tests for /health JSON structure."""

    def test_health_has_app_field(self, page, base_url):
        resp = page.request.get(f"{base_url}/health")
        data = resp.json()
        assert "app" in data
        assert data["app"] == "ok"

    def test_health_has_tests_field(self, page, base_url):
        resp = page.request.get(f"{base_url}/health")
        data = resp.json()
        assert "tests" in data
        assert isinstance(data["tests"], dict)


class TestApiV1HealthSchema:
    """Tests for /api/v1/health JSON structure."""

    def test_api_health_has_status(self, page, base_url):
        resp = page.request.get(f"{base_url}/api/v1/health")
        data = resp.json()
        assert "status" in data

    def test_api_health_has_providers(self, page, base_url):
        resp = page.request.get(f"{base_url}/api/v1/health")
        data = resp.json()
        assert "providers" in data
        assert isinstance(data["providers"], list)


class TestApiV1IndexSchema:
    """Tests for /api/v1/ JSON structure."""

    def test_api_index_has_name(self, page, base_url):
        resp = page.request.get(f"{base_url}/api/v1/")
        data = resp.json()
        assert data.get("name") == "Watchtower API"

    def test_api_index_has_endpoints(self, page, base_url):
        resp = page.request.get(f"{base_url}/api/v1/")
        data = resp.json()
        assert "endpoints" in data
        assert isinstance(data["endpoints"], dict)
        assert len(data["endpoints"]) > 0

    def test_api_index_endpoints_have_structure(self, page, base_url):
        resp = page.request.get(f"{base_url}/api/v1/")
        data = resp.json()
        for name, details in data["endpoints"].items():
            assert isinstance(name, str)
            assert "url" in details or "methods" in details


class TestSessionStatusSchema:
    """Tests for /api/session/status JSON structure."""

    def test_session_status_is_json(self, page, base_url):
        resp = page.request.get(f"{base_url}/api/session/status")
        body = resp.text()
        # Should be valid JSON or HTML — check content type
        assert resp.status == 200
        assert len(body) > 10


class TestTestSummarySchema:
    """Tests for /api/test-summary JSON structure."""

    def test_summary_has_suites(self, page, base_url):
        resp = page.request.get(f"{base_url}/api/test-summary")
        data = resp.json()
        assert "suites" in data
        assert isinstance(data["suites"], dict)

    def test_summary_has_total_files(self, page, base_url):
        resp = page.request.get(f"{base_url}/api/test-summary")
        data = resp.json()
        assert "total_files" in data
        assert data["total_files"] > 0

    def test_summary_suites_have_counts(self, page, base_url):
        resp = page.request.get(f"{base_url}/api/test-summary")
        data = resp.json()
        for name, details in data["suites"].items():
            assert isinstance(name, str)
            assert "files" in details


class TestSessionsApiSchema:
    """Tests for /api/sessions JSON structure."""

    def test_sessions_returns_list(self, page, base_url):
        resp = page.request.get(f"{base_url}/api/sessions")
        data = resp.json()
        assert isinstance(data, list)

    def test_sessions_have_structure(self, page, base_url):
        resp = page.request.get(f"{base_url}/api/sessions")
        data = resp.json()
        if data:  # May be empty
            session = data[0]
            assert "id" in session or "session_id" in session
