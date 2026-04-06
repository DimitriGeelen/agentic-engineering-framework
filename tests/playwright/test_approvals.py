"""Playwright tests for Approvals page (T-981).

Covers: page loads, pending approvals listed, task references present.
"""
from playwright.sync_api import Page

TEST_URL = "http://localhost:3099"


def _url(path: str) -> str:
    return f"{TEST_URL}{path}"


class TestApprovalsPage:
    """Approvals page renders with pending human review items."""

    def test_approvals_page_loads(self, page: Page):
        resp = page.goto(_url("/approvals"))
        assert resp.status == 200

    def test_approvals_has_content(self, page: Page):
        page.goto(_url("/approvals"))
        page.wait_for_load_state("networkidle")
        content = page.content()
        assert len(content) > 500, "Approvals page should have content"

    def test_approvals_has_task_references(self, page: Page):
        """Approvals page should show task references (T-XXX)."""
        page.goto(_url("/approvals"))
        page.wait_for_load_state("networkidle")
        content = page.content()
        assert "T-" in content, "Approvals page should show task references"

    def test_approvals_has_heading(self, page: Page):
        page.goto(_url("/approvals"))
        page.wait_for_load_state("networkidle")
        heading = page.locator("h1, h2")
        assert heading.count() > 0, "Approvals page should have a heading"
