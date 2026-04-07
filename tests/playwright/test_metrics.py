"""Playwright tests for Metrics page (T-986).

Covers: page loads, heading, task/traceability/knowledge sections.
"""
from playwright.sync_api import Page

TEST_URL = "http://localhost:3099"


def _url(path: str) -> str:
    return f"{TEST_URL}{path}"


class TestMetricsPage:
    """Metrics page renders with project statistics."""

    def test_metrics_page_loads(self, page: Page):
        resp = page.goto(_url("/metrics"))
        assert resp.status == 200

    def test_metrics_has_heading(self, page: Page):
        page.goto(_url("/metrics"))
        page.wait_for_load_state("domcontentloaded")
        heading = page.locator("h1")
        assert heading.count() > 0
        assert "Metrics" in heading.first.text_content()

    def test_metrics_has_task_counts(self, page: Page):
        """Metrics page should show task statistics."""
        page.goto(_url("/metrics"))
        page.wait_for_load_state("domcontentloaded")
        content = page.content().lower()
        assert "task" in content

    def test_metrics_has_traceability(self, page: Page):
        """Metrics page should show traceability information."""
        page.goto(_url("/metrics"))
        page.wait_for_load_state("domcontentloaded")
        content = page.content().lower()
        assert "traceability" in content

    def test_metrics_has_knowledge_section(self, page: Page):
        """Metrics page should show knowledge/commit info."""
        page.goto(_url("/metrics"))
        page.wait_for_load_state("domcontentloaded")
        content = page.content().lower()
        assert "knowledge" in content or "commit" in content
