"""Playwright guard for T-2026 (arc-007 S3c2) — approvals content inline styles re-theme.

Proves the browser behaviour: the inline-styled verdict pills in _approvals_content.html
(e.g. a GO badge with `background:var(--wt-success)`) change their computed background
when the foundation palette (`[data-wt-palette]` on <html>) switches — i.e. they honour
the selected preset (the human's 2026-05-24 decision). Captures a review screenshot under
a distinctive palette for the Human [REVIEW] (T-1575).

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


class TestApprovalsContentTokens:
    def test_verdict_pill_rethemes_per_palette(self, page: Page):
        page.goto(f"{TEST_URL}/approvals", timeout=60000)
        page.wait_for_load_state("domcontentloaded")
        pill = page.locator(".verdict-badge").first
        assert pill.count() > 0, "no .verdict-badge on /approvals — expected GO/arc-closure pills"
        _set_palette(page, "paper")
        c_paper = pill.evaluate("e => getComputedStyle(e).backgroundColor")
        _set_palette(page, "console")
        c_console = pill.evaluate("e => getComputedStyle(e).backgroundColor")
        assert c_paper != c_console, (
            f"approvals verdict pill did not re-theme: {c_paper!r} == {c_console!r}"
        )
        assert c_paper.startswith("rgb"), f"unexpected colour value: {c_paper!r}"

    def test_capture_review_artefact(self, page: Page):
        os.makedirs(ARTEFACT_DIR, exist_ok=True)
        page.goto(f"{TEST_URL}/approvals", timeout=60000)
        page.wait_for_load_state("domcontentloaded")
        _set_palette(page, "bone")  # distinctive amber palette so re-theming is visible
        page.wait_for_timeout(150)
        out = os.path.join(ARTEFACT_DIR, "T-2026-approvals-content-tokens.png")
        page.screenshot(path=out, clip={"x": 0, "y": 0, "width": 1280, "height": 900})
        assert os.path.exists(out)
