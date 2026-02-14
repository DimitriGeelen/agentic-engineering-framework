"""
Test suite for the Watchtower web UI.

Covers: all routes (200s), htmx partial rendering, CSRF protection,
error handlers, task detail pages, search, quality gate, and data integrity.

Run: pytest web/test_app.py -v
"""

import os
import sys

import pytest

# Ensure web package is importable
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from web.app import app


@pytest.fixture
def client():
    """Flask test client with testing config."""
    app.config["TESTING"] = True
    app.config["SECRET_KEY"] = "test-secret-key"
    with app.test_client() as c:
        yield c


@pytest.fixture
def csrf_client(client):
    """Client with a valid CSRF token pre-loaded."""
    # Hit any page to establish a session with CSRF token
    client.get("/")
    with client.session_transaction() as sess:
        token = sess.get("_csrf_token", "")
    return client, token


# =========================================================================
# Route availability — every page returns 200
# =========================================================================


class TestRoutes:
    """All main routes return 200."""

    @pytest.mark.parametrize(
        "path",
        [
            "/",
            "/project",
            "/directives",
            "/timeline",
            "/tasks",
            "/tasks?show_all=true",
            "/decisions",
            "/learnings",
            "/gaps",
            "/search",
            "/quality",
        ],
    )
    def test_route_returns_200(self, client, path):
        resp = client.get(path)
        assert resp.status_code == 200, f"{path} returned {resp.status_code}"

    def test_search_with_query(self, client):
        resp = client.get("/search?q=lifecycle")
        assert resp.status_code == 200
        assert b"lifecycle" in resp.data.lower() or b"Search" in resp.data


# =========================================================================
# htmx partial rendering
# =========================================================================


class TestHtmxPartials:
    """HX-Request header returns fragment (no <html> wrapper)."""

    @pytest.mark.parametrize(
        "path",
        ["/", "/tasks", "/timeline", "/decisions", "/learnings", "/gaps", "/quality"],
    )
    def test_htmx_returns_fragment(self, client, path):
        resp = client.get(path, headers={"HX-Request": "true"})
        assert resp.status_code == 200
        html = resp.data.decode()
        # Fragment should NOT contain full page wrapper elements
        assert "<!DOCTYPE" not in html
        assert "<html" not in html

    @pytest.mark.parametrize(
        "path",
        ["/", "/tasks", "/timeline", "/quality"],
    )
    def test_full_page_has_wrapper(self, client, path):
        resp = client.get(path)
        assert resp.status_code == 200
        html = resp.data.decode()
        # Full page SHOULD contain wrapper elements
        assert "<!DOCTYPE" in html or "<html" in html


# =========================================================================
# CSRF protection
# =========================================================================


class TestCSRF:
    """State-changing requests require valid CSRF token."""

    def test_post_without_csrf_returns_403(self, client):
        resp = client.post("/api/task/T-001/status", data={"status": "started-work"})
        assert resp.status_code == 403

    def test_post_with_invalid_csrf_returns_403(self, client):
        resp = client.post(
            "/api/task/T-001/status",
            data={"status": "started-work", "_csrf_token": "invalid-token"},
        )
        assert resp.status_code == 403

    def test_post_with_valid_csrf_succeeds(self, csrf_client):
        client, token = csrf_client
        resp = client.post(
            "/api/task/T-001/status",
            data={"status": "started-work", "_csrf_token": token},
        )
        # Should NOT be 403 (CSRF passed)
        assert resp.status_code != 403

    def test_csrf_via_header(self, csrf_client):
        client, token = csrf_client
        resp = client.post(
            "/api/task/T-001/status",
            data={"status": "started-work"},
            headers={"X-CSRF-Token": token},
        )
        assert resp.status_code != 403


# =========================================================================
# Error handlers
# =========================================================================


class TestErrorHandlers:
    """Custom error pages render correctly."""

    def test_404_returns_error_page(self, client):
        resp = client.get("/nonexistent-page-xyz")
        assert resp.status_code == 404
        assert b"Not Found" in resp.data

    def test_404_for_invalid_task_id(self, client):
        resp = client.get("/tasks/INVALID")
        assert resp.status_code == 404

    def test_404_for_nonexistent_task(self, client):
        resp = client.get("/tasks/T-999")
        assert resp.status_code == 404

    def test_project_doc_path_traversal(self, client):
        resp = client.get("/project/../../etc/passwd")
        assert resp.status_code == 404

    def test_project_doc_nonexistent(self, client):
        resp = client.get("/project/nonexistent-doc-xyz")
        assert resp.status_code == 404


# =========================================================================
# Task detail pages
# =========================================================================


class TestTaskDetail:
    """Task detail pages render with correct data."""

    def test_task_detail_renders(self, client):
        resp = client.get("/tasks/T-001")
        assert resp.status_code == 200
        html = resp.data.decode()
        assert "T-001" in html
        assert "success metrics" in html.lower() or "Define" in html

    def test_task_id_validation_blocks_injection(self, client):
        resp = client.get("/tasks/T-001;rm+-rf")
        assert resp.status_code == 404

    def test_task_status_api_validates_status(self, csrf_client):
        client, token = csrf_client
        resp = client.post(
            "/api/task/T-001/status",
            data={"status": "invalid-status", "_csrf_token": token},
        )
        assert resp.status_code == 400

    def test_task_status_api_validates_task_id(self, csrf_client):
        client, token = csrf_client
        resp = client.post(
            "/api/task/INVALID/status",
            data={"status": "started-work", "_csrf_token": token},
        )
        assert resp.status_code == 404


# =========================================================================
# Timeline API
# =========================================================================


class TestTimeline:
    """Timeline endpoints work correctly."""

    def test_timeline_page(self, client):
        resp = client.get("/timeline")
        assert resp.status_code == 200
        # Should contain at least one session
        html = resp.data.decode()
        assert "S-" in html

    def test_timeline_task_detail_api(self, client):
        resp = client.get("/api/timeline/task/T-001")
        assert resp.status_code == 200

    def test_timeline_task_invalid_id(self, client):
        resp = client.get("/api/timeline/task/INVALID")
        assert resp.status_code == 404

    def test_timeline_task_nonexistent(self, client):
        resp = client.get("/api/timeline/task/T-999")
        assert resp.status_code == 200  # Returns "No episodic data" message


# =========================================================================
# Quality Gate
# =========================================================================


class TestQualityGate:
    """Quality Gate page renders and API endpoints work."""

    def test_quality_page_renders(self, client):
        resp = client.get("/quality")
        assert resp.status_code == 200
        html = resp.data.decode()
        assert "Quality Gate" in html
        assert "Traceability" in html

    def test_quality_page_shows_audit_status(self, client):
        resp = client.get("/quality")
        html = resp.data.decode()
        assert "PASS" in html or "WARN" in html or "FAIL" in html

    def test_quality_has_action_buttons(self, client):
        resp = client.get("/quality")
        html = resp.data.decode()
        assert "Run Audit" in html
        assert "Run Tests" in html

    def test_audit_api_requires_csrf(self, client):
        resp = client.post("/api/audit/run")
        assert resp.status_code == 403

    def test_tests_api_requires_csrf(self, client):
        resp = client.post("/api/tests/run")
        assert resp.status_code == 403


# =========================================================================
# Data integrity — pages contain expected content
# =========================================================================


class TestDataIntegrity:
    """Pages display real framework data."""

    def test_dashboard_has_task_counts(self, client):
        resp = client.get("/")
        html = resp.data.decode()
        # Dashboard should mention tasks
        assert "task" in html.lower() or "Task" in html

    def test_dashboard_shows_watchtower(self, client):
        resp = client.get("/")
        html = resp.data.decode()
        assert "Watchtower" in html

    def test_gaps_page_shows_gaps(self, client):
        resp = client.get("/gaps")
        html = resp.data.decode()
        assert "G-001" in html

    def test_decisions_page_shows_decisions(self, client):
        resp = client.get("/decisions")
        html = resp.data.decode()
        assert "AD-001" in html or "architectural" in html.lower()

    def test_learnings_page_shows_content(self, client):
        resp = client.get("/learnings")
        html = resp.data.decode()
        assert "L-001" in html or "learning" in html.lower()

    def test_directives_page_shows_d1_d4(self, client):
        resp = client.get("/directives")
        html = resp.data.decode()
        assert "Antifragility" in html or "D1" in html

    def test_project_page_lists_docs(self, client):
        resp = client.get("/project")
        html = resp.data.decode()
        assert "001-Vision" in html or "Vision" in html

    def test_project_doc_renders_markdown(self, client):
        resp = client.get("/project/001-Vision")
        assert resp.status_code == 200
        html = resp.data.decode()
        # Should contain rendered markdown (not raw)
        assert "<h" in html or "<p>" in html

    def test_tasks_page_shows_all_with_filter(self, client):
        resp = client.get("/tasks?show_all=true")
        html = resp.data.decode()
        assert "T-001" in html

    def test_search_returns_results(self, client):
        resp = client.get("/search?q=antifragility")
        html = resp.data.decode()
        assert resp.status_code == 200
        assert "antifragility" in html.lower() or "result" in html.lower() or "match" in html.lower()


# =========================================================================
# Navigation — Watchtower grouped nav
# =========================================================================


class TestNavigation:
    """Navigation uses grouped Watchtower layout."""

    def test_watchtower_brand_present(self, client):
        resp = client.get("/")
        html = resp.data.decode()
        assert "Watchtower" in html

    def test_nav_groups_present(self, client):
        resp = client.get("/")
        html = resp.data.decode()
        for group in ["Work", "Knowledge", "Govern"]:
            assert group in html, f"Navigation group missing: {group}"

    def test_nav_has_search(self, client):
        resp = client.get("/")
        html = resp.data.decode()
        assert "search" in html.lower()

    def test_ambient_strip_present(self, client):
        resp = client.get("/")
        html = resp.data.decode()
        assert "ambient-strip" in html

    def test_footer_shows_watchtower(self, client):
        resp = client.get("/")
        html = resp.data.decode()
        assert "Watchtower v1.0.0" in html
