"""Playwright tests for Review page (T-970, T-982).

Covers: review page loads, AC checkboxes present.
Approvals page tests moved to test_approvals.py (T-981).
"""
import pytest
from playwright.sync_api import Page

TEST_URL = "http://localhost:3099"


def _url(path: str) -> str:
    return f"{TEST_URL}{path}"


class TestReviewPage:
    """Task review page renders with AC checkboxes."""

    def test_review_page_loads(self, page: Page):
        # Find a task ID from the tasks page to test review
        page.goto(_url("/tasks"))
        page.wait_for_load_state("domcontentloaded")
        task_links = page.locator("a[href*='/tasks/T-']")
        if task_links.count() > 0:
            href = task_links.first.get_attribute("href")
            task_id = href.split("/")[-1] if "/" in href else href
            resp = page.goto(_url(f"/review/{task_id}"))
            assert resp.status == 200

    def test_review_has_ac_section(self, page: Page):
        page.goto(_url("/tasks"))
        page.wait_for_load_state("domcontentloaded")
        task_links = page.locator("a[href*='/tasks/T-']")
        if task_links.count() > 0:
            href = task_links.first.get_attribute("href")
            task_id = href.split("/")[-1] if "/" in href else href
            page.goto(_url(f"/review/{task_id}"))
            page.wait_for_load_state("domcontentloaded")
            content = page.content().lower()
            assert "acceptance" in content or "criteria" in content or "human" in content, (
                "Review page should show acceptance criteria section"
            )
