"""Playwright tests for /review/<task_id>/acs fragment endpoint (T-1026).

Covers: returns HTML, invalid ID returns 404, nonexistent task returns 404.
Route: web/blueprints/review.py:149
"""
import re

from playwright.sync_api import Page

TEST_URL = "http://localhost:3099"


def _url(path: str) -> str:
    return f"{TEST_URL}{path}"


def _find_task_id(page: Page) -> str:
    """Find a real task ID from the tasks page."""
    page.goto(_url("/tasks"))
    page.wait_for_load_state("domcontentloaded")
    content = page.content()
    match = re.search(r"T-\d{3,}", content)
    return match.group(0) if match else "T-1017"


class TestReviewAcs:
    """AC fragment endpoint for htmx polling on review page."""

    def test_review_acs_returns_html(self, page: Page):
        task_id = _find_task_id(page)
        resp = page.goto(_url(f"/review/{task_id}/acs"))
        assert resp.status == 200

    def test_review_acs_invalid_id(self, page: Page):
        resp = page.goto(_url("/review/INVALID/acs"))
        assert resp.status == 404

    def test_review_acs_nonexistent_task(self, page: Page):
        resp = page.goto(_url("/review/T-99999/acs"))
        assert resp.status == 404
