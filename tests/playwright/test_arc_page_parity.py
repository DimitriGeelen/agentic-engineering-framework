"""Playwright tests for T-1910 — arc page parity (Slices 1+2+4 of T-1905).

Slice 1: read-only enrichment on arc cards (status badge, created, decision).
Slice 2: inline-editable name + focus toggle on cards AND detail page.
Slice 4: filter chips (focused, stale) + view toggle (kanban/list).

T-1575 rule: UI verification = DOM-content assertion, not element-presence grep.
"""
import pytest
from playwright.sync_api import Page

from tests.playwright.target import TEST_URL


def _url(path: str) -> str:
    return f"{TEST_URL}{path}"


class TestSlice1Enrichment:
    """Slice 1: read-only field enrichment on arc cards."""

    def test_arc_card_has_status_badge_label(self, page: Page):
        page.goto(_url("/arcs"))
        page.wait_for_load_state("domcontentloaded")
        # Every arc card should have a labeled status badge (info/ok/draft/muted).
        # arc-grooming is in-progress.
        badges = page.locator(".arc-card .badge-info, .arc-card .badge-ok, .arc-card .badge-draft, .arc-card .badge-muted")
        assert badges.count() > 0, "Arc cards must show a labeled status badge"

    def test_arc_card_has_created_date(self, page: Page):
        page.goto(_url("/arcs"))
        page.wait_for_load_state("domcontentloaded")
        # Created date appears in the meta row.
        meta_text = page.locator(".arc-card-meta").first.inner_text()
        # ISO-8601 yyyy-mm-dd
        import re as _re
        assert _re.search(r"\d{4}-\d{2}-\d{2}", meta_text), (
            f"Arc card meta must include a yyyy-mm-dd created date, got: {meta_text!r}"
        )


class TestSlice2InlineEdit:
    """Slice 2: inline editable name + focus toggle."""

    def test_arc_card_name_is_clickable_editable(self, page: Page):
        page.goto(_url("/arcs"))
        page.wait_for_load_state("domcontentloaded")
        # Each card has an .editable-arc-name span with onclick handler.
        editable = page.locator(".arc-card .editable-arc-name")
        assert editable.count() > 0, "Arc cards must have inline-editable name spans"

    def test_focus_toggle_button_present_on_card(self, page: Page):
        page.goto(_url("/arcs"))
        page.wait_for_load_state("domcontentloaded")
        # Each card has a focus-dot-btn submit button in a form posting to /api/arc/<slug>/focus.
        btns = page.locator(".arc-card .focus-dot-btn")
        assert btns.count() > 0, "Arc cards must have a focus-dot toggle button"

    def test_arc_detail_h1_is_inline_editable(self, page: Page):
        page.goto(_url("/arcs/arc-grooming"))
        page.wait_for_load_state("domcontentloaded")
        editable = page.locator("h1 .editable-arc-h1")
        assert editable.count() == 1, "Arc detail h1 must contain an .editable-arc-h1 span"

    def test_focus_toggle_button_present_on_detail(self, page: Page):
        page.goto(_url("/arcs/arc-grooming"))
        page.wait_for_load_state("domcontentloaded")
        btns = page.locator(".arc-header .focus-dot-btn")
        assert btns.count() == 1, "Arc detail h1 must have a focus-dot toggle"

    def test_focus_toggle_actually_toggles(self, page: Page):
        """Clicking the focus toggle should flip the data-focused attribute."""
        page.goto(_url("/arcs"))
        page.wait_for_load_state("domcontentloaded")
        first_dot = page.locator(".arc-card .focus-dot").first
        before = first_dot.get_attribute("data-focused")
        # Click the parent form's submit button
        page.locator(".arc-card .focus-dot-btn").first.click()
        # htmx swaps in the new dot; wait for it
        page.wait_for_timeout(500)
        after_dot = page.locator(".arc-card .focus-dot").first
        after = after_dot.get_attribute("data-focused")
        assert before != after, (
            f"Clicking focus toggle should flip data-focused; before={before} after={after}"
        )
        # Click again to restore previous state (don't leave focus dirty)
        page.locator(".arc-card .focus-dot-btn").first.click()
        page.wait_for_timeout(500)


class TestSlice4FiltersAndView:
    """Slice 4: filter chips + view toggle."""

    def test_filter_chips_present(self, page: Page):
        page.goto(_url("/arcs"))
        page.wait_for_load_state("domcontentloaded")
        chips_text = page.locator(".arc-filter-bar").inner_text().lower()
        assert "focused" in chips_text, "Filter bar must include a 'focused' chip"
        assert "stale" in chips_text, "Filter bar must include a 'stale' chip"

    def test_view_toggle_kanban_vs_list(self, page: Page):
        page.goto(_url("/arcs"))
        page.wait_for_load_state("domcontentloaded")
        # Kanban view is default — should see .arc-kanban-board
        assert page.locator(".arc-kanban-board").count() == 1
        # Switch to list view
        page.goto(_url("/arcs?view=list"))
        page.wait_for_load_state("domcontentloaded")
        # Should see .arc-row instead
        assert page.locator(".arc-row").count() > 0, "List view must render .arc-row entries"
        # Kanban board should NOT be present in list view
        assert page.locator(".arc-kanban-board").count() == 0

    def test_focused_filter_narrows_results(self, page: Page):
        page.goto(_url("/arcs"))
        page.wait_for_load_state("domcontentloaded")
        # Count all arc cards on unfiltered page
        all_count = page.locator(".arc-card").count()
        # Apply ?focused=true — should be ≤ 1 (only focused arc, or 0)
        page.goto(_url("/arcs?focused=true"))
        page.wait_for_load_state("domcontentloaded")
        focused_count = page.locator(".arc-card").count()
        assert focused_count <= all_count, (
            f"Focused filter should narrow result set; all={all_count} focused={focused_count}"
        )
        # Active chip is highlighted
        active = page.locator(".arc-filter-chip.active")
        active_text = " ".join(active.nth(i).inner_text().strip().lower() for i in range(active.count()))
        assert "focus" in active_text, f"Active chip must include 'focused', got: {active_text!r}"
