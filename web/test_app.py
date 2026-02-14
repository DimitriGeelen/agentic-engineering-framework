"""
Test suite for the Watchtower web UI.

Covers: all routes (200s), htmx partial rendering, CSRF protection,
error handlers, task detail pages, kanban board, quality gate,
session cockpit, search, and data integrity.

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
            "/tasks?view=board",
            "/tasks?view=list",
            "/tasks?show_all=true",
            "/decisions",
            "/learnings",
            "/gaps",
            "/search",
            "/quality",
            "/metrics",
            "/patterns",
            "/patterns?type=failure",
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
        ["/", "/tasks", "/timeline", "/decisions", "/learnings", "/gaps", "/quality", "/metrics", "/patterns"],
    )
    def test_htmx_returns_fragment(self, client, path):
        resp = client.get(path, headers={"HX-Request": "true"})
        assert resp.status_code == 200
        html = resp.data.decode()
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
# Kanban Board
# =========================================================================


class TestKanbanBoard:
    """Kanban board view works correctly."""

    def test_board_view_renders(self, client):
        resp = client.get("/tasks?view=board")
        assert resp.status_code == 200
        html = resp.data.decode()
        assert "Board" in html or "board" in html

    def test_list_view_renders(self, client):
        resp = client.get("/tasks?view=list")
        assert resp.status_code == 200
        html = resp.data.decode()
        assert "List" in html or "table" in html.lower()

    def test_create_task_form_present(self, client):
        resp = client.get("/tasks?view=board")
        html = resp.data.decode()
        assert "Create Task" in html

    def test_create_task_api_requires_name(self, csrf_client):
        client, token = csrf_client
        resp = client.post(
            "/api/task/create",
            data={"name": "", "type": "build", "owner": "human", "_csrf_token": token},
        )
        assert resp.status_code == 400

    def test_create_task_api_validates_type(self, csrf_client):
        client, token = csrf_client
        resp = client.post(
            "/api/task/create",
            data={"name": "Test", "type": "invalid", "owner": "human", "_csrf_token": token},
        )
        assert resp.status_code == 400


# =========================================================================
# Timeline
# =========================================================================


class TestTimeline:
    """Timeline endpoints work correctly."""

    def test_timeline_page(self, client):
        resp = client.get("/timeline")
        assert resp.status_code == 200
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
        assert resp.status_code == 200


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
# Session Cockpit
# =========================================================================


class TestSessionCockpit:
    """Session status and write action endpoints."""

    def test_session_status_returns_200(self, client):
        resp = client.get("/api/session/status")
        assert resp.status_code == 200
        html = resp.data.decode()
        assert "Branch" in html or "branch" in html

    def test_session_status_shows_git_info(self, client):
        resp = client.get("/api/session/status")
        html = resp.data.decode()
        assert "master" in html or "main" in html

    def test_decision_api_requires_csrf(self, client):
        resp = client.post("/api/decision", data={"decision": "Test"})
        assert resp.status_code == 403

    def test_decision_api_requires_text(self, csrf_client):
        client, token = csrf_client
        resp = client.post(
            "/api/decision",
            data={"decision": "", "_csrf_token": token},
        )
        assert resp.status_code == 400

    def test_learning_api_requires_csrf(self, client):
        resp = client.post("/api/learning", data={"learning": "Test"})
        assert resp.status_code == 403

    def test_learning_api_requires_text(self, csrf_client):
        client, token = csrf_client
        resp = client.post(
            "/api/learning",
            data={"learning": "", "_csrf_token": token},
        )
        assert resp.status_code == 400

    def test_session_init_requires_csrf(self, client):
        resp = client.post("/api/session/init")
        assert resp.status_code == 403

    def test_healing_api_requires_csrf(self, client):
        resp = client.post("/api/healing/T-001")
        assert resp.status_code == 403

    def test_healing_api_validates_task_id(self, csrf_client):
        client, token = csrf_client
        resp = client.post(
            "/api/healing/INVALID",
            data={"_csrf_token": token},
        )
        assert resp.status_code == 400


# =========================================================================
# Data integrity
# =========================================================================


class TestDataIntegrity:
    """Pages display real framework data."""

    def test_dashboard_shows_watchtower(self, client):
        resp = client.get("/")
        html = resp.data.decode()
        assert "Watchtower" in html

    def test_dashboard_has_task_counts(self, client):
        resp = client.get("/")
        html = resp.data.decode()
        assert "task" in html.lower() or "Task" in html

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
        assert "<h" in html or "<p>" in html

    def test_tasks_page_shows_tasks(self, client):
        resp = client.get("/tasks?view=list")
        html = resp.data.decode()
        assert "T-0" in html

    def test_search_returns_results(self, client):
        resp = client.get("/search?q=antifragility")
        assert resp.status_code == 200


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


# =========================================================================
# Phase 3 — Operational Intelligence
# =========================================================================


class TestMetrics:
    """Metrics page shows project health data."""

    def test_metrics_has_task_counts(self, client):
        resp = client.get("/metrics")
        html = resp.data.decode()
        assert "Active Tasks" in html
        assert "completed" in html.lower()

    def test_metrics_has_traceability(self, client):
        resp = client.get("/metrics")
        html = resp.data.decode()
        assert "Traceability" in html
        assert "gauge-" in html

    def test_metrics_has_knowledge_counts(self, client):
        resp = client.get("/metrics")
        html = resp.data.decode()
        assert "Knowledge Items" in html

    def test_metrics_has_recent_commits(self, client):
        resp = client.get("/metrics")
        html = resp.data.decode()
        assert "Recent Commits" in html

    def test_metrics_has_refresh_button(self, client):
        resp = client.get("/metrics")
        html = resp.data.decode()
        assert "Refresh" in html


class TestPatterns:
    """Patterns page shows categorized patterns with filtering."""

    def test_patterns_has_all_types(self, client):
        resp = client.get("/patterns")
        html = resp.data.decode()
        assert "FP-" in html or "SP-" in html or "AF-" in html or "WP-" in html

    def test_patterns_filter_by_type(self, client):
        resp = client.get("/patterns?type=failure")
        html = resp.data.decode()
        assert "FP-" in html
        assert "SP-" not in html

    def test_patterns_antifragile_has_escalation(self, client):
        resp = client.get("/patterns?type=antifragile")
        html = resp.data.decode()
        assert "escalation-ladder" in html
        assert "step-letter" in html

    def test_patterns_has_tab_bar(self, client):
        resp = client.get("/patterns")
        html = resp.data.decode()
        assert "pattern-tabs" in html
        assert "Failure" in html

    def test_patterns_cards_link_to_tasks(self, client):
        resp = client.get("/patterns")
        html = resp.data.decode()
        assert "/tasks/T-" in html


class TestPhase3Integration:
    """Cross-cutting Phase 3 integration checks."""

    def test_learnings_no_longer_has_pattern_tables(self, client):
        resp = client.get("/learnings")
        html = resp.data.decode()
        assert "Failure Patterns" not in html
        assert "pattern" in html.lower()  # but has the link

    def test_learnings_has_patterns_link(self, client):
        resp = client.get("/learnings")
        html = resp.data.decode()
        assert "/patterns" in html

    def test_nav_has_patterns(self, client):
        resp = client.get("/")
        html = resp.data.decode()
        assert "Patterns" in html

    def test_nav_has_metrics(self, client):
        resp = client.get("/")
        html = resp.data.decode()
        assert "Metrics" in html

    def test_dashboard_has_system_health(self, client):
        resp = client.get("/")
        html = resp.data.decode()
        assert "System Health" in html
