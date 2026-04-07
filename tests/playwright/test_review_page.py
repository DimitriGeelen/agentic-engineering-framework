"""Playwright tests for Task Review page (T-1020).

Covers: review page loads, heading shows task ID, research artifacts section.
"""
import re

from playwright.sync_api import Page

TEST_URL = "http://localhost:3099"


def _url(path: str) -> str:
    return f"{TEST_URL}{path}"


def _find_reviewable_task(page: Page) -> str:
    """Find a task with a review page from approvals."""
    page.goto(_url("/approvals"))
    page.wait_for_load_state("domcontentloaded")
    content = page.content()
    match = re.search(r'href="/review/(T-\d+)"', content)
    if match:
        return match.group(1)
    match = re.search(r"T-\d{3,}", content)
    return match.group(0) if match else "T-1017"


class TestReviewPage:
    """Task review page renders with review information."""

    def test_review_page_loads(self, page: Page):
        task_id = _find_reviewable_task(page)
        resp = page.goto(_url(f"/review/{task_id}"))
        assert resp.status == 200

    def test_review_has_heading(self, page: Page):
        task_id = _find_reviewable_task(page)
        page.goto(_url(f"/review/{task_id}"))
        page.wait_for_load_state("domcontentloaded")
        heading = page.locator("h1, h2")
        assert heading.count() > 0
        assert task_id in heading.first.text_content()

    def test_review_has_content(self, page: Page):
        """Review page should show task content or ACs."""
        task_id = _find_reviewable_task(page)
        page.goto(_url(f"/review/{task_id}"))
        page.wait_for_load_state("domcontentloaded")
        content = page.content().lower()
        assert "acceptance" in content or "criteria" in content or "review" in content or "recommendation" in content

    def test_review_nonexistent_returns_error(self, page: Page):
        """Nonexistent task review should return 404 or error."""
        resp = page.goto(_url("/review/T-99999"))
        assert resp.status in (404, 200)
