"""Playwright guard for T-2018 (arc-007 S4e/S6c) — bulk multi-select, end-to-end.

Proves the browser-only behaviours:
  - ticking task checkboxes reveals the floating bar with the correct count;
  - Clear deselects and hides the bar;
  - the bar's listeners survive an htmx #content swap (select on the board, swap to the
    list view, select again) — selection resets on swap, but selecting still works;
  - applying a horizon fans out to /api/task/<id>/horizon and shows the success toast
    (proven net-zero by applying the selected card's CURRENT horizon — no value changes,
    no T-1068 cascade).

Captures a review screenshot for the human [REVIEW] (T-1575). Runs against the isolated
port-3099 harness (conftest), never :3000.
"""
import os

from playwright.sync_api import Page, expect

from tests.playwright.target import TEST_URL
ARTEFACT_DIR = os.path.join(
    os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
    "web", "static", "ux-review",
)

BAR = "#wt-bulk-bar"
COUNT = "#wt-bulk-count"
CARD_CB = "article.kanban-card input.wt-bulk-select"


def _goto_tasks(page: Page):
    page.goto(f"{TEST_URL}/tasks", timeout=60000)
    page.wait_for_load_state("domcontentloaded")
    expect(page.locator(CARD_CB).first).to_be_attached()


class TestBulkActions:
    def test_select_cards_shows_bar_with_count(self, page: Page):
        _goto_tasks(page)
        expect(page.locator(BAR)).to_be_hidden()
        page.locator(CARD_CB).nth(0).check()
        page.locator(CARD_CB).nth(1).check()
        expect(page.locator(BAR)).to_be_visible()
        expect(page.locator(COUNT)).to_have_text("2 selected")

    def test_clear_hides_bar(self, page: Page):
        _goto_tasks(page)
        page.locator(CARD_CB).nth(0).check()
        expect(page.locator(BAR)).to_be_visible()
        page.locator(f"{BAR} [data-bulk-clear]").click()
        expect(page.locator(BAR)).to_be_hidden()
        expect(page.locator(CARD_CB).nth(0)).not_to_be_checked()

    def test_listeners_survive_content_swap(self, page: Page):
        _goto_tasks(page)
        page.locator(CARD_CB).nth(0).check()
        expect(page.locator(BAR)).to_be_visible()
        # htmx #content swap to the list view — selection resets, listeners must persist
        page.locator("a[href='/tasks?view=list']").first.click()
        page.wait_for_timeout(400)
        expect(page.locator(BAR)).to_be_hidden()
        # selecting a freshly-swapped row still drives the bar (delegated listener survived)
        page.locator("table input.wt-bulk-select").first.check()
        expect(page.locator(BAR)).to_be_visible()
        expect(page.locator(COUNT)).to_have_text("1 selected")

    def test_apply_horizon_fans_out_and_toasts(self, page: Page):
        _goto_tasks(page)
        first_card = page.locator("article.kanban-card").first
        current = first_card.locator("select[name='horizon']").input_value()
        first_card.locator("input.wt-bulk-select").check()
        expect(page.locator(BAR)).to_be_visible()
        # apply the card's CURRENT horizon → net-zero, but the fan-out + toast still fire
        page.locator(f"{BAR} [data-bulk-horizon='{current}']").click()
        expect(page.locator(".wt-toast")).to_contain_text("Set horizon=")
        # selection clears after apply
        expect(page.locator(BAR)).to_be_hidden()

    def test_capture_review_artefact(self, page: Page):
        os.makedirs(ARTEFACT_DIR, exist_ok=True)
        _goto_tasks(page)
        page.locator(CARD_CB).nth(0).check()
        page.locator(CARD_CB).nth(1).check()
        expect(page.locator(BAR)).to_be_visible()
        page.wait_for_timeout(250)
        out = os.path.join(ARTEFACT_DIR, "T-2018-bulk-actions.png")
        page.screenshot(path=out, clip={"x": 0, "y": 0, "width": 1280, "height": 720})
        assert os.path.exists(out)
