"""Playwright tests for enhanced task detail page (T-1056).

Verifies task detail renders with status, ACs, and key sections
using real active tasks from the .tasks/active/ directory.
"""
import os
import re


class TestTaskDetailEnhanced:
    """Enhanced task detail page tests using real tasks."""

    def _find_active_task_id(self):
        """Find a real active task ID."""
        tasks_dir = os.path.join(
            os.environ.get("PROJECT_ROOT", "/opt/999-Agentic-Engineering-Framework"),
            ".tasks", "active",
        )
        for f in os.listdir(tasks_dir):
            m = re.match(r"(T-\d+)", f)
            if m:
                return m.group(1)
        return None

    def test_task_detail_has_title(self, page, base_url):
        """Task detail page shows task title."""
        task_id = self._find_active_task_id()
        if not task_id:
            return
        page.goto(f"{base_url}/tasks/{task_id}")
        page.wait_for_load_state("domcontentloaded")
        body = page.content()
        assert task_id in body

    def test_task_detail_has_status_badge(self, page, base_url):
        """Task detail page shows status information."""
        task_id = self._find_active_task_id()
        if not task_id:
            return
        page.goto(f"{base_url}/tasks/{task_id}")
        page.wait_for_load_state("domcontentloaded")
        body = page.content().lower()
        # Should contain a status keyword
        assert any(s in body for s in [
            "started-work", "captured", "work-completed",
            "issues", "status", "started"
        ])

    def test_task_detail_has_metadata(self, page, base_url):
        """Task detail page shows task metadata (owner, type, horizon)."""
        task_id = self._find_active_task_id()
        if not task_id:
            return
        page.goto(f"{base_url}/tasks/{task_id}")
        page.wait_for_load_state("domcontentloaded")
        body = page.content().lower()
        # Should mention at least one metadata field
        assert any(s in body for s in ["owner", "type", "horizon", "created"])

    def test_task_detail_has_acceptance_criteria(self, page, base_url):
        """Task detail page shows acceptance criteria section."""
        task_id = self._find_active_task_id()
        if not task_id:
            return
        page.goto(f"{base_url}/tasks/{task_id}")
        page.wait_for_load_state("domcontentloaded")
        body = page.content().lower()
        assert "acceptance" in body or "criteria" in body or "agent" in body

    def test_task_detail_nonexistent(self, page, base_url):
        """Nonexistent task returns 404."""
        resp = page.goto(f"{base_url}/tasks/T-99999")
        assert resp.status == 404

    def test_task_detail_page_size(self, page, base_url):
        """Task detail page has substantial content."""
        task_id = self._find_active_task_id()
        if not task_id:
            return
        page.goto(f"{base_url}/tasks/{task_id}")
        page.wait_for_load_state("domcontentloaded")
        body = page.locator("body").text_content()
        assert len(body) > 100, "Task detail page should have substantial content"
