"""Playwright guard for T-2024 (arc-007 S3a2) — cockpit inline-style colours re-theme.

Proves the browser behaviour: the cockpit elements that used hardcoded inline
hexes (verdict pills, action-summary counts, concerns counts, card accents, the
Strength line) now reference foundation tokens, so switching the palette
(`[data-wt-palette]` on <html>) changes their computed colour — i.e. they honour
the selected preset (the human's 2026-05-24 decision). Captures a review screenshot
under a distinctive palette for the Human [REVIEW] (T-1575).

Read-only page → inherently net-zero. Runs against the isolated port-3099 harness
(conftest), never :3000.
"""
import os

from playwright.sync_api import Page

TEST_URL = "http://localhost:3099"
ARTEFACT_DIR = os.path.join(
    os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
    "web", "static", "ux-review",
)


def _set_palette(page: Page, name: str):
    page.evaluate(f"() => document.documentElement.setAttribute('data-wt-palette', '{name}')")
    page.wait_for_timeout(80)  # let the style engine recalc


class TestCockpitInlineTokens:
    def test_inline_token_element_rethemes_per_palette(self, page: Page):
        page.goto(f"{TEST_URL}/", timeout=60000)
        page.wait_for_load_state("domcontentloaded")

        # An inline style that *colours* via a foundation token (the S3a2 conversions).
        sel = '[style*="color:var(--wt-"], [style*="color: var(--wt-"]'
        count = page.locator(sel).count()
        assert count > 0, (
            "no cockpit element uses an inline color:var(--wt-*) — S3a2 conversions "
            "should produce at least one (action-summary counts / concerns / Strength)"
        )
        el = page.locator(sel).first
        _set_palette(page, "paper")
        c_paper = el.evaluate("e => getComputedStyle(e).color")
        _set_palette(page, "console")
        c_console = el.evaluate("e => getComputedStyle(e).color")
        assert c_paper != c_console, (
            f"inline-token cockpit element did not re-theme: {c_paper!r} == {c_console!r}"
        )
        assert c_paper.startswith("rgb"), f"unexpected colour value: {c_paper!r}"

    def test_capture_review_artefact(self, page: Page):
        os.makedirs(ARTEFACT_DIR, exist_ok=True)
        page.goto(f"{TEST_URL}/", timeout=60000)
        page.wait_for_load_state("domcontentloaded")
        _set_palette(page, "bone")  # distinctive amber palette so re-theming is visible
        page.wait_for_timeout(150)
        out = os.path.join(ARTEFACT_DIR, "T-2024-cockpit-inline-tokens.png")
        page.screenshot(path=out, clip={"x": 0, "y": 0, "width": 1280, "height": 900})
        assert os.path.exists(out)
