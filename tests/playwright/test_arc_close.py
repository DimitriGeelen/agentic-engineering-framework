"""Playwright tests for T-1911 — Watchtower /arcs/<slug>/close build.

The close-review surface that lets the human submit an arc close via Watchtower
(invokes `fw arc close --from-watchtower` on the human's behalf — exempt from
the T-1671 §ACD agent gate by design).
"""
import re
import pytest
from playwright.sync_api import Page

from tests.playwright.target import TEST_URL


def _url(path: str) -> str:
    return f"{TEST_URL}{path}"


class TestArcCloseSurface:
    """GET /arcs/<slug>/close renders the full close-review form."""

    def test_page_loads(self, page: Page):
        resp = page.goto(_url("/arcs/arc-grooming/close"))
        assert resp.status == 200

    def test_unknown_arc_404s(self, page: Page):
        resp = page.goto(_url("/arcs/no-such-arc-xyz/close"))
        assert resp.status == 404

    def test_form_has_demo_mode_radios(self, page: Page):
        page.goto(_url("/arcs/arc-grooming/close"))
        page.wait_for_load_state("domcontentloaded")
        radios = page.locator('input[name="demo_mode"]')
        assert radios.count() == 3, "Form must have 3 demo mode radios (path/url/none)"
        values = sorted([radios.nth(i).get_attribute("value") for i in range(3)])
        assert values == ["none", "path", "url"]

    def test_form_has_required_fields(self, page: Page):
        page.goto(_url("/arcs/arc-grooming/close"))
        page.wait_for_load_state("domcontentloaded")
        assert page.locator('[name="demo_value"]').count() == 1
        assert page.locator('[name="decision"]').count() == 1
        assert page.locator('[name="justification"]').count() == 1
        assert page.locator('button[type="submit"]').count() == 1

    def test_headline_mechanic_visible(self, page: Page):
        page.goto(_url("/arcs/arc-grooming/close"))
        page.wait_for_load_state("domcontentloaded")
        content = page.content()
        assert "headline-mechanic-box" in content or "headline_mechanic" in content.lower(), (
            "Close page must surface the arc's headline_mechanic"
        )

    def test_acd_three_question_check_visible(self, page: Page):
        page.goto(_url("/arcs/arc-grooming/close"))
        page.wait_for_load_state("domcontentloaded")
        content = page.content().lower()
        assert "three-question check" in content, "§ACD three-question prompt must be visible"
        assert "fresh substrate" in content
        assert "silently-defaulted" in content


class TestArcClosePost:
    """POST /arcs/<slug>/close submits via shell to fw arc close --from-watchtower."""

    def test_invalid_demo_path_shows_error_in_form(self, page: Page):
        page.goto(_url("/arcs/arc-grooming/close"))
        page.wait_for_load_state("domcontentloaded")
        page.locator('input[name="demo_mode"][value="path"]').check()
        page.fill('[name="demo_value"]', '/tmp/does-not-exist-xyz-playwright.md')
        page.fill('[name="decision"]', 'test decision')
        page.click('button[type="submit"]')
        page.wait_for_load_state("domcontentloaded")
        # Should re-render the same form (not redirect) with an error visible.
        content = page.content()
        assert "Submit rejected" in content or "form-error" in content, (
            "Invalid demo path must surface a visible error on the form"
        )
        # URL should still be the close page (no redirect on error).
        assert "/close" in page.url

    def test_demo_none_without_justification_rejected(self, page: Page):
        page.goto(_url("/arcs/arc-grooming/close"))
        page.wait_for_load_state("domcontentloaded")
        page.locator('input[name="demo_mode"][value="none"]').check()
        # short justification (<30 chars)
        page.fill('[name="justification"]', 'short')
        page.fill('[name="decision"]', 'no')
        # Submit button should be disabled by JS gate
        page.wait_for_timeout(200)
        is_disabled = page.locator('button[type="submit"]').is_disabled()
        # Even if JS didn't disable it (e.g. headless quirks), server must reject.
        if not is_disabled:
            page.click('button[type="submit"]')
            page.wait_for_load_state("domcontentloaded")
            assert "form-error" in page.content() or "Submit rejected" in page.content()


class TestArcCloseFromDetailLinkage:
    """The close surface should be reachable from /arcs and /arcs/<slug>."""

    def test_back_link_to_detail(self, page: Page):
        page.goto(_url("/arcs/arc-grooming/close"))
        page.wait_for_load_state("domcontentloaded")
        back = page.locator('a[href="/arcs/arc-grooming"]')
        assert back.count() >= 1, "Close page must have a back-link to the arc detail"
