"""Playwright guard for T-2008 (arc-007 S2a) — Govern dropdown is subsectioned.

Opens the live-rendered Govern top-bar dropdown and asserts the four function
subsections are visible (not a flat 16-item list). Also drops a screenshot of the
opened dropdown to web/static/ux-review/ as the artefact the human [REVIEW] reads.

Pairs with tests/unit/test_nav_subsections.py (model + DOM-content). This is the
executed-browser half (T-1575: UI changes need a rendered check, not source grep;
T-971: every UI AC gets a Playwright guard).
"""
import os

from playwright.sync_api import Page, expect

TEST_URL = "http://localhost:3099"

GOVERN_SUBSECTIONS = ["Approvals & Decisions", "Enforcement", "Health", "Operations"]
ARTEFACT = os.path.join(
    os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
    "web", "static", "ux-review", "T-2008-govern-subsections.png",
)


def _open_govern(page: Page):
    page.goto(f"{TEST_URL}/", timeout=60000)
    page.wait_for_load_state("domcontentloaded")
    summary = page.locator("nav.site-nav details.dropdown > summary", has_text="Govern")
    summary.click()
    return summary


class TestGovernSubsections:
    def test_govern_dropdown_shows_four_subsections(self, page: Page):
        """The Govern dropdown renders the four labelled subsections, visible on open."""
        _open_govern(page)
        for label in GOVERN_SUBSECTIONS:
            loc = page.locator("nav.site-nav li.nav-subsection-label", has_text=label)
            expect(loc).to_be_visible()

    def test_arcs_lives_under_work(self, page: Page):
        """T-2034: Arcs is reachable from the Work group, not Architecture (human IA
        override of the T-2008 design-spec move)."""
        page.goto(f"{TEST_URL}/", timeout=60000)
        page.wait_for_load_state("domcontentloaded")
        work = page.locator("nav.site-nav details.dropdown > summary", has_text="Work")
        work.click()
        # the Work dropdown that is now open contains an Arcs link
        arcs = page.locator("nav.site-nav details.dropdown[open] ul li a", has_text="Arcs")
        expect(arcs.first).to_be_visible()

    def test_capture_review_artefact(self, page: Page):
        """Screenshot the opened Govern dropdown for the human [REVIEW] (best-effort)."""
        _open_govern(page)
        page.wait_for_timeout(150)
        os.makedirs(os.path.dirname(ARTEFACT), exist_ok=True)
        # viewport clip — the dropdown panel overflows the nav bar, so an element
        # screenshot of nav.site-nav would clip it; capture the top viewport region.
        page.screenshot(path=ARTEFACT, clip={"x": 0, "y": 0, "width": 1280, "height": 620})
        assert os.path.exists(ARTEFACT)
