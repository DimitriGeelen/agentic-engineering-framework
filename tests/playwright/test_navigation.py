"""Playwright tests for Watchtower navigation (T-1003).

Verifies that sequential page navigation works and all nav routes return 200.
"""
from playwright.sync_api import Page

TEST_URL = "http://localhost:3099"


def _url(path: str) -> str:
    return f"{TEST_URL}{path}"


class TestNavigation:
    """Sequential page navigation works correctly."""

    TIMEOUT = 60000

    def test_navigate_tasks_then_inception(self, page: Page):
        """Navigate tasks then inception via direct URL."""
        page.goto(_url("/tasks"), timeout=self.TIMEOUT)
        page.wait_for_load_state("domcontentloaded")
        assert "Tasks" in page.content()
        page.goto(_url("/inception"), timeout=self.TIMEOUT)
        page.wait_for_load_state("domcontentloaded")
        assert "Inception" in page.content()

    def test_navigate_fabric_then_quality(self, page: Page):
        """Navigate fabric then quality."""
        page.goto(_url("/fabric"), timeout=self.TIMEOUT)
        page.wait_for_load_state("domcontentloaded")
        assert "Fabric" in page.content()
        page.goto(_url("/quality"), timeout=self.TIMEOUT)
        page.wait_for_load_state("domcontentloaded")
        assert "Quality" in page.content()

    def test_navigate_metrics_then_enforcement(self, page: Page):
        """Navigate metrics then enforcement."""
        page.goto(_url("/metrics"), timeout=self.TIMEOUT)
        page.wait_for_load_state("domcontentloaded")
        assert "Metrics" in page.content()
        page.goto(_url("/enforcement"), timeout=self.TIMEOUT)
        page.wait_for_load_state("domcontentloaded")
        assert "Enforcement" in page.content()

    def test_navigate_home_then_tasks(self, page: Page):
        """Navigate home then tasks."""
        page.goto(_url("/"), timeout=self.TIMEOUT)
        page.wait_for_load_state("domcontentloaded")
        assert "Watchtower" in page.content()
        page.goto(_url("/tasks"), timeout=self.TIMEOUT)
        page.wait_for_load_state("domcontentloaded")
        assert "Tasks" in page.content()

    def test_nav_links_present(self, page: Page):
        """All major nav sections have links."""
        page.goto(_url("/"), timeout=self.TIMEOUT)
        page.wait_for_load_state("domcontentloaded")
        content = page.content()
        assert 'href="/tasks"' in content
        assert 'href="/inception"' in content
        assert 'href="/fabric"' in content

    def test_multi_page_transition(self, page: Page):
        """Visit 3 pages in sequence — verifies no state leaks between navigations."""
        for route, marker in [("/cron", "Scheduled"), ("/risks", "Concerns"), ("/learnings", "Learnings")]:
            resp = page.goto(_url(route), timeout=self.TIMEOUT)
            page.wait_for_load_state("domcontentloaded")
            assert resp.status == 200, f"{route} returned {resp.status}"
            assert marker in page.content(), f"{route} missing '{marker}'"
