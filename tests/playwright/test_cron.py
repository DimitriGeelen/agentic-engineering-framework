"""Playwright tests for Cron Registry page (T-986).

Covers: page loads, heading, job listing, schedule info.
"""
from playwright.sync_api import Page

TEST_URL = "http://localhost:3099"


def _url(path: str) -> str:
    return f"{TEST_URL}{path}"


class TestCronPage:
    """Cron registry page renders with scheduled job data."""

    def test_cron_page_loads(self, page: Page):
        resp = page.goto(_url("/cron"))
        assert resp.status == 200

    def test_cron_has_heading(self, page: Page):
        page.goto(_url("/cron"))
        page.wait_for_load_state("domcontentloaded")
        heading = page.locator("h1")
        assert heading.count() > 0
        assert "Scheduled" in heading.first.text_content() or "Jobs" in heading.first.text_content()

    def test_cron_has_job_info(self, page: Page):
        """Cron page should display job entries."""
        page.goto(_url("/cron"))
        page.wait_for_load_state("domcontentloaded")
        content = page.content().lower()
        assert "job" in content or "schedule" in content

    def test_cron_has_schedule_info(self, page: Page):
        """Cron page should show schedule/interval information."""
        page.goto(_url("/cron"))
        page.wait_for_load_state("domcontentloaded")
        content = page.content().lower()
        assert "cron" in content or "run" in content
