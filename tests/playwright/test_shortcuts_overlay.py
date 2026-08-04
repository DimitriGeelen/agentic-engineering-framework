"""Playwright guard for T-2013 (arc-007 S6b) — ? shortcuts overlay, end-to-end.

Proves the browser-only behaviours:
  - `?` opens the overlay and Esc closes it, fresh AND after an htmx #content swap
    (the listener lives in the shell → survives the swap);
  - `?` while a text input is focused does NOT open the overlay (types normally);
  - the overlay lists the live shortcuts;
  - opening the ⌘K palette while the overlay is open replaces it (no stacked modals).

Captures a review screenshot for the human [REVIEW] (T-1575). Runs against the
isolated port-3099 harness (conftest), never :3000. Each test gets a fresh page.
"""
import os

from playwright.sync_api import Page, expect

from tests.playwright.target import TEST_URL
ARTEFACT_DIR = os.path.join(
    os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
    "web", "static", "ux-review",
)

OVERLAY = "#wt-shortcuts-overlay"
PALETTE = "#wt-command-palette"
PALETTE_INPUT = "#wt-palette-input"


def _goto(page: Page, path: str):
    page.goto(f"{TEST_URL}{path}", timeout=60000)
    page.wait_for_load_state("domcontentloaded")


def _open_overlay(page: Page):
    page.keyboard.press("Shift+Slash")  # "?"
    expect(page.locator(OVERLAY)).to_be_visible()


class TestShortcutsOverlay:
    def test_open_close_fresh(self, page: Page):
        _goto(page, "/tasks")
        expect(page.locator(OVERLAY)).to_be_hidden()
        _open_overlay(page)
        page.keyboard.press("Escape")
        expect(page.locator(OVERLAY)).to_be_hidden()

    def test_open_close_after_htmx_swap(self, page: Page):
        _goto(page, "/tasks")
        page.locator("nav.site-nav .nav-docs a").click()
        page.wait_for_url("**/project", timeout=60000)
        _open_overlay(page)  # shell listener still live after the swap
        page.keyboard.press("Escape")
        expect(page.locator(OVERLAY)).to_be_hidden()

    def test_question_mark_in_input_does_not_open(self, page: Page):
        _goto(page, "/tasks")
        # focus a real text input (the ⌘K palette's input)
        page.keyboard.press("Control+k")
        expect(page.locator(PALETTE_INPUT)).to_be_focused()
        page.keyboard.press("Shift+Slash")  # "?" while typing
        # the overlay must NOT open, and the "?" types into the input
        expect(page.locator(OVERLAY)).to_be_hidden()
        assert "?" in page.locator(PALETTE_INPUT).input_value()

    def test_overlay_lists_live_shortcuts(self, page: Page):
        _goto(page, "/tasks")
        _open_overlay(page)
        box = page.locator(f"{OVERLAY} .wt-shortcuts-box")
        expect(box).to_contain_text("Open command palette")
        expect(box).to_contain_text("Close the palette or this overlay")
        # the ⌘K and Esc key chips are rendered as <kbd> (Esc appears in the row + the hint)
        expect(page.locator(f"{OVERLAY} kbd", has_text="Esc").first).to_be_visible()
        expect(page.locator(f"{OVERLAY} kbd", has_text="K").first).to_be_visible()

    def test_palette_and_overlay_do_not_stack(self, page: Page):
        _goto(page, "/tasks")
        _open_overlay(page)
        # opening the palette while the overlay is open replaces it (one modal)
        page.keyboard.press("Control+k")
        expect(page.locator(PALETTE)).to_be_visible()
        expect(page.locator(OVERLAY)).to_be_hidden()

    def test_capture_review_artefact(self, page: Page):
        os.makedirs(ARTEFACT_DIR, exist_ok=True)
        _goto(page, "/tasks")
        _open_overlay(page)
        page.wait_for_timeout(150)
        out = os.path.join(ARTEFACT_DIR, "T-2013-shortcuts-overlay.png")
        page.screenshot(path=out, clip={"x": 0, "y": 0, "width": 1280, "height": 600})
        assert os.path.exists(out)
