"""Playwright guard for T-2015 (arc-007 S4a) — slide-in dockable task panel, end-to-end.

Proves the browser-only behaviours:
  - clicking a task card opens the slide-in panel (no full-page nav — URL stays /tasks)
    and the panel loads that task's detail; Esc closes it;
  - the open listener still works after an htmx #content board swap (the listener lives
    in the shell → survives the swap);
  - the dock controls switch right/left/bottom/full and the choice persists across a
    fresh page load (per-browser prefs);
  - opening the ⌘K palette closes the panel (no two shell modals stacked).

Captures a review screenshot for the human [REVIEW] (T-1575). Runs against the isolated
port-3099 harness (conftest), never :3000. Each test gets a fresh page (fresh UID cookie).
"""
import os

from playwright.sync_api import Page, expect

from tests.playwright.target import TEST_URL
ARTEFACT_DIR = os.path.join(
    os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
    "web", "static", "ux-review",
)

PANEL = "#wt-task-panel"
PANEL_BODY = "#wt-task-panel-body"
PALETTE = "#wt-command-palette"


def _goto_tasks(page: Page):
    page.goto(f"{TEST_URL}/tasks", timeout=60000)
    page.wait_for_load_state("domcontentloaded")
    expect(page.locator("[data-task-panel]").first).to_be_visible()


def _open_first_card(page: Page):
    page.locator("[data-task-panel]").first.click()
    expect(page.locator(PANEL)).to_be_visible()
    # the fragment loaded into the panel body (htmx swap replaced the "Loading…")
    expect(page.locator(f"{PANEL_BODY} .wt-task-panel-id")).to_be_visible()


class TestTaskPanel:
    def test_click_card_opens_panel_no_full_page_nav(self, page: Page):
        _goto_tasks(page)
        expect(page.locator(PANEL)).to_be_hidden()
        _open_first_card(page)
        # no full-page nav — the URL is still the board
        assert page.url.rstrip("/").endswith("/tasks")
        page.keyboard.press("Escape")
        expect(page.locator(PANEL)).to_be_hidden()

    def test_panel_opens_after_htmx_board_swap(self, page: Page):
        _goto_tasks(page)
        # swap #content to the list view (htmx hx-get) — the panel listener lives in
        # the shell, so it must still fire on the freshly-swapped rows
        page.locator("a[href='/tasks?view=list']").first.click()
        page.wait_for_timeout(400)
        expect(page.locator("table [data-task-panel]").first).to_be_visible()
        page.locator("table [data-task-panel]").first.click()
        expect(page.locator(PANEL)).to_be_visible()
        expect(page.locator(f"{PANEL_BODY} .wt-task-panel-id")).to_be_visible()

    def test_dock_controls_switch_and_persist(self, page: Page):
        _goto_tasks(page)
        _open_first_card(page)
        # switch to bottom dock
        page.locator(f"{PANEL} .wt-dock-btn[data-dock='bottom']").click()
        expect(page.locator(PANEL)).to_have_class(__import__("re").compile(r"\bdock-bottom\b"))
        # reload — the dock choice is server-persisted per browser, applied on render
        page.reload()
        page.wait_for_load_state("domcontentloaded")
        expect(page.locator(PANEL)).to_have_class(__import__("re").compile(r"\bdock-bottom\b"))

    def test_palette_closes_panel(self, page: Page):
        _goto_tasks(page)
        _open_first_card(page)
        page.keyboard.press("Control+k")
        expect(page.locator(PALETTE)).to_be_visible()
        expect(page.locator(PANEL)).to_be_hidden()

    def test_capture_review_artefact(self, page: Page):
        os.makedirs(ARTEFACT_DIR, exist_ok=True)
        _goto_tasks(page)
        _open_first_card(page)
        page.wait_for_timeout(250)
        out = os.path.join(ARTEFACT_DIR, "T-2015-task-panel.png")
        page.screenshot(path=out, clip={"x": 0, "y": 0, "width": 1280, "height": 700})
        assert os.path.exists(out)
