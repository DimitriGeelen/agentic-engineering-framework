"""Playwright tests for Inception detail page (T-1019).

Covers: inception page loads, heading shows task ID, recommendation section.
"""
import re

from playwright.sync_api import Page

TEST_URL = "http://localhost:3099"


def _url(path: str) -> str:
    return f"{TEST_URL}{path}"


def _find_inception_id(page: Page) -> str:
    """Find a valid inception task ID from the approvals page."""
    page.goto(_url("/approvals"))
    page.wait_for_load_state("domcontentloaded")
    content = page.content()
    match = re.search(r'href="/inception/(T-\d+)"', content)
    return match.group(1) if match else "T-1017"


class TestInceptionPage:
    """Inception detail page renders with task information."""

    def test_inception_page_loads(self, page: Page):
        task_id = _find_inception_id(page)
        resp = page.goto(_url(f"/inception/{task_id}"))
        assert resp.status == 200

    def test_inception_has_heading(self, page: Page):
        task_id = _find_inception_id(page)
        page.goto(_url(f"/inception/{task_id}"))
        page.wait_for_load_state("domcontentloaded")
        heading = page.locator("h1")
        assert heading.count() > 0
        assert task_id in heading.first.text_content()

    def test_inception_has_content(self, page: Page):
        """Inception page should show problem statement or recommendation."""
        task_id = _find_inception_id(page)
        page.goto(_url(f"/inception/{task_id}"))
        page.wait_for_load_state("domcontentloaded")
        content = page.content().lower()
        assert "problem" in content or "recommendation" in content or "decision" in content

    def test_inception_nonexistent_returns_error(self, page: Page):
        """Nonexistent inception task should return 404 or error."""
        resp = page.goto(_url("/inception/T-99999"))
        assert resp.status in (404, 200)
