"""Playwright tests for T-1909 arc-membership badge.

Verifies that the `arc_id` design (T-1848 / T-1849 / T-1850) is visible on
the three task-rendering surfaces:

  1. /tasks?view=board       — kanban card meta row
  2. /tasks?view=list        — list-view "Arc" column
  3. /arcs/<slug>            — constituent-task table "Arc" column

T-1575 rule: UI verification needs DOM-content assertion (not element-presence
grep). Each test loads the page, queries the rendered DOM via Playwright, and
asserts the badge link resolves to /arcs/<id>.
"""
import pytest
from playwright.sync_api import Page

TEST_URL = "http://localhost:3099"


def _url(path: str) -> str:
    return f"{TEST_URL}{path}"


class TestArcBadge:
    """Arc-id badge renders wherever a task is shown."""

    def test_kanban_card_has_arc_badge(self, page: Page):
        page.goto(_url("/tasks?view=board"))
        page.wait_for_load_state("domcontentloaded")
        badges = page.locator("article.kanban-card a.arc-badge")
        # arc-grooming has 32+ constituent tasks, kanban shows top 10/column
        # so we expect at least one badge across all four columns.
        assert badges.count() > 0, "Kanban cards must show at least one arc badge"
        href = badges.first.get_attribute("href")
        assert href and href.startswith("/arcs/"), (
            f"Arc badge must link to /arcs/<id>, got: {href}"
        )

    def test_list_view_has_arc_column_and_badges(self, page: Page):
        page.goto(_url("/tasks?view=list"))
        page.wait_for_load_state("domcontentloaded")
        # Header
        headers = page.locator("table thead th")
        header_texts = [headers.nth(i).inner_text().strip() for i in range(headers.count())]
        assert "Arc" in header_texts, f"List view must have an 'Arc' column, got headers: {header_texts}"
        # At least one row has a badge
        badges = page.locator("table tbody a.arc-badge")
        assert badges.count() > 0, "List view must show at least one arc badge in the Arc column"

    def test_arc_detail_constituent_table_has_arc_column(self, page: Page):
        page.goto(_url("/arcs/arc-grooming"))
        page.wait_for_load_state("domcontentloaded")
        headers = page.locator("table thead th")
        header_texts = [headers.nth(i).inner_text().strip() for i in range(headers.count())]
        assert "Arc" in header_texts, (
            f"Arc-detail constituent table must have an 'Arc' column, got: {header_texts}"
        )
        badges = page.locator("table tbody a.arc-badge")
        assert badges.count() > 0, "Constituent-task rows must show the arc badge"

    def test_arc_badge_link_navigates(self, page: Page):
        """Click the first arc badge and confirm it lands on /arcs/<id>."""
        page.goto(_url("/tasks?view=list"))
        page.wait_for_load_state("domcontentloaded")
        first = page.locator("a.arc-badge").first
        href = first.get_attribute("href")
        assert href and href.startswith("/arcs/"), f"unexpected href: {href}"
        resp = page.goto(_url(href))
        assert resp.status == 200, f"Arc badge link returned {resp.status}, expected 200"
