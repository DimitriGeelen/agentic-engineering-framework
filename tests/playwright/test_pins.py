"""Playwright guard for T-2010 (arc-007 S2c) — pinned-pages model, end-to-end.

Proves the behaviours the unit tests can't reach through a real browser:
  - clicking the breadcrumb-bar star pins the page and the top-bar #wt-pins strip
    updates WITHOUT a full reload (oob swap; a window marker survives the swap);
  - the pin persists across htmx navigation AND a hard reload (server-side prefs);
  - unpinning removes it from the strip;
  - the real csrf-htmx.js path supplies the CSRF token (the unit test stubs it).

Captures a review screenshot for the human [REVIEW] (T-1575 rendered check; T-971
UI AC → test). Runs against the isolated port-3099 harness (conftest), never :3000.
"""
import os

from playwright.sync_api import Page, expect

TEST_URL = "http://localhost:3099"
ARTEFACT = os.path.join(
    os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
    "web", "static", "ux-review", "T-2010-pins.png",
)

STAR = "#content nav.wt-breadcrumb button.wt-pin-toggle"
PINS = "#wt-pins a.nav-pin"


class TestPins:
    def test_star_present_on_nav_page_absent_on_home(self, page: Page):
        page.goto(f"{TEST_URL}/tasks", timeout=60000)
        page.wait_for_load_state("domcontentloaded")
        expect(page.locator(STAR)).to_be_visible()
        page.goto(f"{TEST_URL}/", timeout=60000)
        page.wait_for_load_state("domcontentloaded")
        expect(page.locator("nav.wt-breadcrumb button.wt-pin-toggle")).to_have_count(0)

    def test_pin_updates_nav_without_reload(self, page: Page):
        page.goto(f"{TEST_URL}/tasks", timeout=60000)
        page.wait_for_load_state("domcontentloaded")
        # start from a clean (unpinned) state for this fresh browser context
        expect(page.locator(PINS)).to_have_count(0)
        # marker that only survives if there is NO full page reload
        page.evaluate("window.__wt_no_reload = true")
        page.locator(STAR).click()
        # the top-bar strip gains the pin via oob swap…
        expect(page.locator(PINS)).to_have_count(1)
        expect(page.locator("#wt-pins")).to_contain_text("Tasks")
        # …the toggle flipped to the pinned state…
        expect(page.locator(STAR)).to_contain_text("Pinned")
        # …and the marker survived → oob swap, not a full reload
        assert page.evaluate("window.__wt_no_reload") is True

    def test_pin_persists_across_nav_and_reload(self, page: Page):
        page.goto(f"{TEST_URL}/tasks", timeout=60000)
        page.wait_for_load_state("domcontentloaded")
        if page.locator(PINS).count() == 0:
            page.locator(STAR).click()
            expect(page.locator(PINS)).to_have_count(1)
        # htmx-navigate elsewhere — the pin stays in the nav
        # (T-2034: Arcs is under Work now, not Architecture)
        page.locator("nav.site-nav details.dropdown > summary", has_text="Work").click()
        page.locator("nav.site-nav details.dropdown[open] ul li a", has_text="Arcs").click()
        page.wait_for_load_state("networkidle")
        expect(page.locator(PINS)).to_have_count(1)
        # hard reload — server re-renders the pin from the per-browser prefs file
        page.reload()
        page.wait_for_load_state("domcontentloaded")
        expect(page.locator(PINS)).to_have_count(1)
        expect(page.locator("#wt-pins")).to_contain_text("Tasks")

    def test_unpin_removes_from_strip(self, page: Page):
        page.goto(f"{TEST_URL}/tasks", timeout=60000)
        page.wait_for_load_state("domcontentloaded")
        if page.locator(PINS).count() == 0:
            page.locator(STAR).click()
            expect(page.locator(PINS)).to_have_count(1)
        # the star on /tasks now reads "Pinned"; clicking unpins
        expect(page.locator(STAR)).to_contain_text("Pinned")
        page.locator(STAR).click()
        expect(page.locator(PINS)).to_have_count(0)

    def test_capture_review_artefact(self, page: Page):
        """Screenshot a page with a pinned nav strip for the human [REVIEW]."""
        page.goto(f"{TEST_URL}/tasks", timeout=60000)
        page.wait_for_load_state("domcontentloaded")
        if page.locator(PINS).count() == 0:
            page.locator(STAR).click()
            expect(page.locator(PINS)).to_have_count(1)
        page.wait_for_timeout(150)
        os.makedirs(os.path.dirname(ARTEFACT), exist_ok=True)
        page.screenshot(path=ARTEFACT, clip={"x": 0, "y": 0, "width": 1280, "height": 360})
        assert os.path.exists(ARTEFACT)
