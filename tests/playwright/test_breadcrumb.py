"""Playwright guard for T-2009 (arc-007 S2b) — breadcrumb is htmx-fresh.

The breadcrumb renders inside #content precisely so it survives htmx navigation
(the chrome outside #content goes stale on htmx swap). This test proves it:
navigate via the top nav (htmx, no full reload) and confirm the trail updates,
using a window marker that a full reload would have wiped.

Also confirms the trail is inside #content and captures a nested-page screenshot
for the human [REVIEW]. (T-1575: rendered check, not source grep; T-971: UI AC → test.)
"""
import os

from playwright.sync_api import Page, expect

TEST_URL = "http://localhost:3099"
ARTEFACT = os.path.join(
    os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
    "web", "static", "ux-review", "T-2009-breadcrumb.png",
)


class TestBreadcrumb:
    def test_breadcrumb_present_and_inside_content(self, page: Page):
        page.goto(f"{TEST_URL}/tasks", timeout=60000)
        page.wait_for_load_state("domcontentloaded")
        bc = page.locator("#content nav.wt-breadcrumb")
        expect(bc).to_be_visible()
        expect(bc).to_contain_text("Work")
        expect(bc).to_contain_text("Tasks")

    def test_breadcrumb_updates_on_htmx_nav_without_reload(self, page: Page):
        page.goto(f"{TEST_URL}/tasks", timeout=60000)
        page.wait_for_load_state("domcontentloaded")
        expect(page.locator("#content nav.wt-breadcrumb")).to_contain_text("Tasks")
        # marker that only survives if there is NO full page reload
        page.evaluate("window.__wt_no_reload = true")
        # htmx-navigate to Work › Arcs (T-2034: Arcs moved Architecture → Work)
        page.locator("nav.site-nav details.dropdown > summary", has_text="Work").click()
        page.locator("nav.site-nav details.dropdown[open] ul li a", has_text="Arcs").click()
        page.wait_for_load_state("networkidle")
        # breadcrumb refreshed to the new section…
        expect(page.locator("#content nav.wt-breadcrumb")).to_contain_text("Work")
        expect(page.locator("#content nav.wt-breadcrumb")).to_contain_text("Arcs")
        # …and the marker survived → it was an htmx swap, not a full reload
        assert page.evaluate("window.__wt_no_reload") is True

    def test_home_has_no_breadcrumb(self, page: Page):
        page.goto(f"{TEST_URL}/", timeout=60000)
        page.wait_for_load_state("domcontentloaded")
        expect(page.locator("nav.wt-breadcrumb")).to_have_count(0)

    def test_capture_review_artefact(self, page: Page):
        """Screenshot a nested-page breadcrumb for the human [REVIEW] (best-effort)."""
        page.goto(f"{TEST_URL}/arcs/arc-007", timeout=60000)
        page.wait_for_load_state("domcontentloaded")
        page.wait_for_timeout(150)
        os.makedirs(os.path.dirname(ARTEFACT), exist_ok=True)
        page.screenshot(path=ARTEFACT, clip={"x": 0, "y": 0, "width": 1280, "height": 320})
        assert os.path.exists(ARTEFACT)
