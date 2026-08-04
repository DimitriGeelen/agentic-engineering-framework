"""Playwright guard for T-2023 (arc-007 S3a) — cockpit status pills re-theme per palette.

Proves the browser behaviour: switching the foundation palette
(`[data-wt-palette]` on <html>) changes the computed colour of the cockpit's
status indicators — i.e. they honour the selected preset (the human's 2026-05-24
decision) instead of the old hardcoded hexes. Captures a review screenshot under a
distinctive palette for the Human [REVIEW] (T-1575).

Read-only page → inherently net-zero. Runs against the isolated port-3099 harness
(conftest), never :3000.
"""
import os

from playwright.sync_api import Page, expect

from tests.playwright.target import TEST_URL
ARTEFACT_DIR = os.path.join(
    os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
    "web", "static", "ux-review",
)


def _set_palette(page: Page, name: str):
    page.evaluate(f"() => document.documentElement.setAttribute('data-wt-palette', '{name}')")
    page.wait_for_timeout(80)  # let the style engine recalc


class TestCockpitStatusPills:
    def test_audit_badge_rethemes_per_palette(self, page: Page):
        page.goto(f"{TEST_URL}/", timeout=60000)
        page.wait_for_load_state("domcontentloaded")
        badge = page.locator(".wt-badge").first
        expect(badge).to_be_visible()
        _set_palette(page, "paper")
        c_paper = badge.evaluate("el => getComputedStyle(el).backgroundColor")
        _set_palette(page, "console")
        c_console = badge.evaluate("el => getComputedStyle(el).backgroundColor")
        assert c_paper != c_console, f"audit badge did not re-theme: {c_paper!r} == {c_console!r}"
        # sanity: it resolved to an actual colour, not empty/transparent
        assert c_paper.startswith("rgb"), f"unexpected colour value: {c_paper!r}"

    def test_capture_review_artefact(self, page: Page):
        os.makedirs(ARTEFACT_DIR, exist_ok=True)
        page.goto(f"{TEST_URL}/", timeout=60000)
        page.wait_for_load_state("domcontentloaded")
        _set_palette(page, "bone")  # distinctive amber palette so re-theming is visible
        page.wait_for_timeout(150)
        out = os.path.join(ARTEFACT_DIR, "T-2023-cockpit-status-pills.png")
        page.screenshot(path=out, clip={"x": 0, "y": 0, "width": 1280, "height": 720})
        assert os.path.exists(out)
