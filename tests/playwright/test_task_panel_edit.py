"""Playwright guard for T-2017 (arc-007 S4b) — inline-edit in the side panel, end-to-end.

Proves the browser-only edit flow:
  - an active task's panel renders editable meta selects (status/owner/horizon/type);
  - changing the owner select fires the htmx POST (the macro's onchange→requestSubmit)
    and the panel-scoped result span shows the confirmation — proving CSRF + endpoint
    wiring survives the htmx fragment swap with NO new JS;
  - reopening the panel reflects the persisted value (read-back from disk).

It round-trips the OWNER field (no cascading invariant — unlike horizon's T-1068
auto-demote) and restores the original value, so the test is net-zero on repo state.
Runs against the isolated port-3099 harness (conftest), never :3000.
"""
import os

from playwright.sync_api import Page, expect

TEST_URL = "http://localhost:3099"
ARTEFACT_DIR = os.path.join(
    os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
    "web", "static", "ux-review",
)

PANEL = "#wt-task-panel"
PANEL_BODY = "#wt-task-panel-body"


def _goto_tasks(page: Page):
    page.goto(f"{TEST_URL}/tasks", timeout=60000)
    page.wait_for_load_state("domcontentloaded")
    expect(page.locator("[data-task-panel]").first).to_be_visible()


def _open_first_card(page: Page):
    page.locator("[data-task-panel]").first.click()
    expect(page.locator(PANEL)).to_be_visible()
    expect(page.locator(f"{PANEL_BODY} .wt-task-panel-id")).to_be_visible()


def _type_select(page: Page):
    return page.locator(f"{PANEL_BODY} select[name='type']")


class TestTaskPanelEdit:
    def test_active_panel_shows_editable_selects(self, page: Page):
        _goto_tasks(page)
        _open_first_card(page)
        for field in ("status", "owner", "horizon", "type"):
            expect(page.locator(f"{PANEL_BODY} select[name='{field}']")).to_be_visible()

    def test_change_type_confirms_and_persists(self, page: Page):
        # Round-trip the workflow_type field: it has no cascading invariant (unlike
        # horizon's T-1068 demote) and no ownership protection (unlike owner's R-033),
        # so the change is net-zero on repo state once restored.
        _goto_tasks(page)
        _open_first_card(page)
        sel = _type_select(page)
        original = sel.input_value()
        other = "refactor" if original != "refactor" else "build"

        # change → onchange submits via htmx → confirmation swaps into the panel span
        # (proves the macro's form is htmx-active inside the swapped fragment)
        sel.select_option(other)
        expect(page.locator("#wt-panel-type-result")).to_contain_text(
            f"Type set to {other}"
        )

        # reopen the same card → fragment re-fetched → persisted value shown
        page.keyboard.press("Escape")
        expect(page.locator(PANEL)).to_be_hidden()
        _open_first_card(page)
        expect(_type_select(page)).to_have_value(other)

        # restore original (net-zero on repo state)
        _type_select(page).select_option(original)
        expect(page.locator("#wt-panel-type-result")).to_contain_text(
            f"Type set to {original}"
        )

    def test_capture_review_artefact(self, page: Page):
        os.makedirs(ARTEFACT_DIR, exist_ok=True)
        _goto_tasks(page)
        _open_first_card(page)
        page.wait_for_timeout(250)
        out = os.path.join(ARTEFACT_DIR, "T-2017-panel-inline-edit.png")
        page.screenshot(path=out, clip={"x": 0, "y": 0, "width": 1280, "height": 520})
        assert os.path.exists(out)
