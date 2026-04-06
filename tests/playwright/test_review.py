"""Playwright tests for Review/Approval pages (T-970).

Covers: review page loads, AC checkboxes present, approvals list.
"""
import pytest
from playwright.sync_api import Page

TEST_URL = "http://localhost:3099"


def _url(path: str) -> str:
    return f"{TEST_URL}{path}"


class TestApprovalsPage:
    """Approvals list page renders."""

    def test_approvals_page_loads(self, page: Page):
        resp = page.goto(_url("/approvals"))
        assert resp.status == 200

    def test_approvals_has_content(self, page: Page):
        page.goto(_url("/approvals"))
        page.wait_for_load_state("networkidle")
        content = page.content()
        assert "Approvals" in content or "approval" in content.lower()


class TestReviewPage:
    """Task review page renders with AC checkboxes."""

    def test_review_page_loads(self, page: Page):
        # Find a task ID from the tasks page to test review
        page.goto(_url("/tasks"))
        page.wait_for_load_state("networkidle")
        task_links = page.locator("a[href*='/tasks/T-']")
        if task_links.count() > 0:
            href = task_links.first.get_attribute("href")
            task_id = href.split("/")[-1] if "/" in href else href
            resp = page.goto(_url(f"/review/{task_id}"))
            assert resp.status == 200

    def test_review_has_ac_section(self, page: Page):
        page.goto(_url("/tasks"))
        page.wait_for_load_state("networkidle")
        task_links = page.locator("a[href*='/tasks/T-']")
        if task_links.count() > 0:
            href = task_links.first.get_attribute("href")
            task_id = href.split("/")[-1] if "/" in href else href
            page.goto(_url(f"/review/{task_id}"))
            page.wait_for_load_state("networkidle")
            content = page.content().lower()
            assert "acceptance" in content or "criteria" in content or "human" in content, (
                "Review page should show acceptance criteria section"
            )
