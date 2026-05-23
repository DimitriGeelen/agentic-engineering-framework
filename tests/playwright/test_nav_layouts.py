"""Playwright guard for T-2011 (arc-007 S2d) — nav layouts, end-to-end.

Proves the three layouts the unit tests can't reach through a real browser:
  - the layout selector on /settings/appearance switches data-wt-nav live, the
    choice persists server-side (per-browser prefs) across navigation + reload;
  - each layout reflows the SAME nav DOM to its distinguishing geometry
    (topbar = full-width bar; sidebar ≈ 232px left column; rail ≤ 72px);
  - the Govern group stays a collapsible <details> in sidebar/rail (the pain
    point), and breadcrumbs (S2b) + the pin star (S2c) survive in all three.

Captures a review screenshot per layout for the human [REVIEW] (T-1575). Runs
against the isolated port-3099 harness (conftest), never :3000. Each test gets a
fresh page → fresh cookie → fresh UID → clean (topbar) prefs.
"""
import os

from playwright.sync_api import Page, expect

TEST_URL = "http://localhost:3099"
ARTEFACT_DIR = os.path.join(
    os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
    "web", "static", "ux-review",
)

NAV = "nav.site-nav"
STAR = "#content nav.wt-breadcrumb button.wt-pin-toggle"
CRUMB = "#content nav.wt-breadcrumb"


def _set_layout(page: Page, value: str):
    """Pick a layout on /settings/appearance and wait for the server save."""
    page.goto(f"{TEST_URL}/settings/appearance", timeout=60000)
    page.wait_for_load_state("domcontentloaded")
    page.locator(f'#wt-nav button[data-value="{value}"]').click()
    # apply() sets the attribute synchronously; save() is async → wait for it
    expect(page.locator("html")).to_have_attribute("data-wt-nav", value)
    expect(page.locator("#wt-status")).to_contain_text("Saved")


def _nav_width(page: Page) -> float:
    box = page.locator(NAV).bounding_box()
    assert box is not None, "nav.site-nav has no bounding box"
    return box["width"]


class TestNavLayouts:
    def test_topbar_is_default(self, page: Page):
        page.goto(f"{TEST_URL}/tasks", timeout=60000)
        page.wait_for_load_state("domcontentloaded")
        expect(page.locator("html")).to_have_attribute("data-wt-nav", "topbar")
        # default = full-width horizontal bar
        assert _nav_width(page) > 400

    def test_switch_to_sidebar_persists(self, page: Page):
        _set_layout(page, "sidebar")
        # full reload from server prefs (new request, same cookie) → still sidebar
        page.goto(f"{TEST_URL}/tasks", timeout=60000)
        page.wait_for_load_state("domcontentloaded")
        expect(page.locator("html")).to_have_attribute("data-wt-nav", "sidebar")
        w = _nav_width(page)
        assert 180 <= w <= 280, f"sidebar nav width {w} not in [180,280]"

    def test_switch_to_rail_persists(self, page: Page):
        _set_layout(page, "rail")
        page.goto(f"{TEST_URL}/tasks", timeout=60000)
        page.wait_for_load_state("domcontentloaded")
        expect(page.locator("html")).to_have_attribute("data-wt-nav", "rail")
        w = _nav_width(page)
        assert w <= 72, f"rail nav width {w} should be a slim column (≤72)"

    def test_govern_collapsible_in_sidebar(self, page: Page):
        _set_layout(page, "sidebar")
        page.goto(f"{TEST_URL}/tasks", timeout=60000)
        page.wait_for_load_state("domcontentloaded")
        # the 16-item Govern group is a <details>, closed by default → not a flat list
        govern = page.locator("nav.site-nav details.dropdown", has_text="Govern")
        expect(govern).to_have_count(1)
        assert govern.evaluate("el => el.open") is False
        # a Govern leaf (e.g. Approvals) is hidden until the group is expanded
        approvals = page.locator("nav.site-nav details.dropdown a", has_text="Approvals")
        expect(approvals).to_be_hidden()

    def test_breadcrumb_and_pin_in_all_layouts(self, page: Page):
        for layout in ("topbar", "sidebar", "rail"):
            if layout != "topbar":
                _set_layout(page, layout)
            page.goto(f"{TEST_URL}/tasks", timeout=60000)
            page.wait_for_load_state("domcontentloaded")
            expect(page.locator("html")).to_have_attribute("data-wt-nav", layout)
            # S2b breadcrumb + S2c pin star survive the reflow
            expect(page.locator(CRUMB)).to_be_visible()
            expect(page.locator(STAR)).to_be_visible()

    def test_capture_review_artefacts(self, page: Page):
        """One screenshot per layout for the human [REVIEW]."""
        os.makedirs(ARTEFACT_DIR, exist_ok=True)
        for layout in ("topbar", "sidebar", "rail"):
            if layout != "topbar":
                _set_layout(page, layout)
            page.goto(f"{TEST_URL}/tasks", timeout=60000)
            page.wait_for_load_state("domcontentloaded")
            # open the Govern group so the reviewer sees grouping in each layout
            page.locator("nav.site-nav details.dropdown summary", has_text="Govern").click()
            page.wait_for_timeout(200)
            out = os.path.join(ARTEFACT_DIR, f"T-2011-nav-{layout}.png")
            page.screenshot(path=out, clip={"x": 0, "y": 0, "width": 1280, "height": 520})
            assert os.path.exists(out)
