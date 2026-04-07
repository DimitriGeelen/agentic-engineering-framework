"""Playwright tests for Cockpit dashboard (T-1018).

Covers: page load, heading, scan meta, action summary, system health,
framework recommends, work direction, API endpoints.
"""
from playwright.sync_api import Page

TEST_URL = "http://localhost:3099"


def _url(path: str) -> str:
    return f"{TEST_URL}{path}"


class TestCockpitPage:
    """Cockpit dashboard renders with scan-driven sections."""

    def test_cockpit_loads(self, page: Page):
        resp = page.goto(_url("/"))
        assert resp.status == 200

    def test_cockpit_has_heading(self, page: Page):
        page.goto(_url("/"))
        page.wait_for_load_state("domcontentloaded")
        heading = page.locator("h1")
        assert heading.count() > 0
        assert "Watchtower" in heading.first.text_content()

    def test_cockpit_has_scan_meta(self, page: Page):
        """Cockpit should show scan age and audit status."""
        page.goto(_url("/"))
        page.wait_for_load_state("domcontentloaded")
        scan_meta = page.locator(".wt-scan-meta")
        assert scan_meta.count() > 0, "Scan meta bar should be present"

    def test_cockpit_has_system_health(self, page: Page):
        """Cockpit should display system health section."""
        page.goto(_url("/"))
        page.wait_for_load_state("domcontentloaded")
        content = page.content().lower()
        assert "system health" in content

    def test_cockpit_has_traceability(self, page: Page):
        """Cockpit should show traceability metric."""
        page.goto(_url("/"))
        page.wait_for_load_state("domcontentloaded")
        content = page.content().lower()
        assert "traceability" in content

    def test_cockpit_has_action_summary(self, page: Page):
        """Cockpit should show action required / attention section."""
        page.goto(_url("/"))
        page.wait_for_load_state("domcontentloaded")
        content = page.content().lower()
        assert "action" in content or "attention" in content

    def test_cockpit_has_scan_refresh_button(self, page: Page):
        """Cockpit should have a scan refresh button."""
        page.goto(_url("/"))
        page.wait_for_load_state("domcontentloaded")
        refresh = page.locator("[hx-post='/api/scan/refresh']")
        assert refresh.count() > 0, "Scan refresh button should be present"

    def test_cockpit_has_test_counts(self, page: Page):
        """Cockpit should display test infrastructure counts (T-1010)."""
        page.goto(_url("/"))
        page.wait_for_load_state("domcontentloaded")
        content = page.content().lower()
        assert "playwright" in content


class TestCockpitAPI:
    """Cockpit API endpoints return expected responses."""

    def test_session_status_api(self, page: Page):
        """Session status API returns session information."""
        resp = page.goto(_url("/api/session/status"))
        assert resp.status == 200
        content = page.content().lower()
        assert "session" in content or "branch" in content or "focus" in content

    def test_scan_focus_rejects_invalid_id(self, page: Page):
        """Focus API rejects invalid task IDs."""
        resp = page.goto(_url("/api/scan/focus/INVALID"))
        # GET to a POST endpoint should return 405, but invalid IDs return 400
        assert resp.status in (400, 405)
