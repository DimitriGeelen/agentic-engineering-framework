"""T-1600: Mobile viewport assertions for review surfaces.

Pin the contract that /cockpit, /approvals, /review/<id> render usefully at
375x667 (iPhone SE). Assertions:
- No horizontal page overflow (scrollWidth <= clientWidth + 1px tolerance).
- The Action Required card / verdict badges remain visible (the "decision
  surface" must stay distinguishable on small screens).

Strategy: resize the page, navigate, evaluate window measurements + visible
locators. No mocked content — we want the real templates' responsive
behavior verified.

Drift class: responsive regressions that pass desktop-only tests but ship
horizontal scrollbars on mobile.
"""
import re
from typing import Optional

import pytest
from playwright.sync_api import Page


TEST_URL = "http://localhost:3099"
MOBILE_VIEWPORT = {"width": 375, "height": 667}  # iPhone SE


def _url(path: str) -> str:
    return f"{TEST_URL}{path}"


def _find_reviewable_task(page: Page) -> Optional[str]:
    page.goto(_url("/approvals"))
    page.wait_for_load_state("domcontentloaded")
    match = re.search(r'href="/review/(T-\d+)"', page.content())
    return match.group(1) if match else None


def _no_horizontal_overflow(page: Page, surface: str, tolerance: int = 1):
    """Assert document scrollWidth <= clientWidth + tolerance.

    Tolerance: 1px accommodates sub-pixel rounding. Anything beyond that is
    a real overflow (a child widening the body past the viewport).
    """
    measurements = page.evaluate(
        """() => ({
            scrollWidth: document.documentElement.scrollWidth,
            clientWidth: document.documentElement.clientWidth,
            bodyScrollWidth: document.body.scrollWidth,
        })"""
    )
    sw = measurements["scrollWidth"]
    cw = measurements["clientWidth"]
    assert sw <= cw + tolerance, (
        f"{surface}: horizontal overflow at 375x667 — "
        f"scrollWidth={sw} > clientWidth={cw}. "
        f"Some child widens the body past the mobile viewport."
    )


class TestMobileViewportCockpit:
    def test_cockpit_no_horizontal_overflow_on_mobile(self, page: Page):
        page.set_viewport_size(MOBILE_VIEWPORT)
        page.goto(_url("/cockpit"))
        page.wait_for_load_state("domcontentloaded")
        _no_horizontal_overflow(page, "/cockpit")


class TestMobileViewportApprovals:
    def test_approvals_no_horizontal_overflow_on_mobile(self, page: Page):
        page.set_viewport_size(MOBILE_VIEWPORT)
        page.goto(_url("/approvals"))
        page.wait_for_load_state("domcontentloaded")
        _no_horizontal_overflow(page, "/approvals")

    def test_approvals_verdict_pills_visible_on_mobile(self, page: Page):
        """data-verdict elements remain visible at 375px."""
        page.set_viewport_size(MOBILE_VIEWPORT)
        page.goto(_url("/approvals"))
        page.wait_for_load_state("domcontentloaded")
        verdicts = page.locator('[data-verdict]')
        # Page may legitimately have zero verdict pills if no recommendations
        # are pending — but if any exist, at least the first must be visible.
        if verdicts.count() == 0:
            pytest.skip("No verdict pills on /approvals at present — nothing to assert")
        assert verdicts.first.is_visible(), (
            "First verdict pill is not visible at mobile viewport — likely "
            "clipped or set to display:none by a desktop-only stylesheet rule."
        )


class TestMobileViewportReview:
    def test_review_no_horizontal_overflow_on_mobile(self, page: Page):
        task_id = _find_reviewable_task(page)
        if task_id is None:
            pytest.skip("No reviewable task in /approvals — fixture inapplicable")
        page.set_viewport_size(MOBILE_VIEWPORT)
        page.goto(_url(f"/review/{task_id}"))
        page.wait_for_load_state("domcontentloaded")
        _no_horizontal_overflow(page, f"/review/{task_id}")

    def test_review_recommendation_section_visible_on_mobile(self, page: Page):
        """The structured Recommendation block must render even on mobile."""
        task_id = _find_reviewable_task(page)
        if task_id is None:
            pytest.skip("No reviewable task found")
        page.set_viewport_size(MOBILE_VIEWPORT)
        page.goto(_url(f"/review/{task_id}"))
        page.wait_for_load_state("domcontentloaded")
        # The block may legitimately not render for NO-REC tasks; but if the
        # page contains the structured class, the FIRST one should be visible.
        rec_block = page.locator('section.recommendation-block')
        if rec_block.count() == 0:
            pytest.skip("Task has no Recommendation block to check")
        assert rec_block.first.is_visible(), (
            "Recommendation block exists in DOM but is not visible at 375px — "
            "likely an unintended overflow:hidden or display:none from a "
            "media query."
        )
