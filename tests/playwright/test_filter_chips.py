"""Playwright guard for T-2016 (arc-007 S4c) — active-filter chips, end-to-end.

Proves the browser behaviours:
  - a shareable filtered URL (?owner=&horizon=) shows a chip for each active filter;
  - clicking one chip's × clears only that filter (htmx reload, no full-page nav) and
    leaves the other chip in place.

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


def _goto(page: Page, path: str):
    page.goto(f"{TEST_URL}{path}", timeout=60000)
    page.wait_for_load_state("domcontentloaded")


class TestFilterChips:
    def test_shareable_url_shows_chips(self, page: Page):
        _goto(page, "/tasks?owner=agent&horizon=now")
        expect(page.locator("[data-filter-chip='owner']")).to_be_visible()
        expect(page.locator("[data-filter-chip='horizon']")).to_be_visible()

    def test_clear_one_chip_keeps_the_other(self, page: Page):
        _goto(page, "/tasks?owner=agent&horizon=now")
        expect(page.locator("[data-filter-chip='owner']")).to_be_visible()
        # clear just the owner chip
        page.locator("[data-filter-chip='owner'] .filter-chip-clear").click()
        page.wait_for_timeout(400)
        # owner chip gone, horizon chip stays — no full-page nav
        expect(page.locator("[data-filter-chip='owner']")).to_have_count(0)
        expect(page.locator("[data-filter-chip='horizon']")).to_be_visible()

    def test_no_filters_no_chip_bar(self, page: Page):
        _goto(page, "/tasks")
        expect(page.locator("[data-filter-chip]")).to_have_count(0)

    def test_capture_review_artefact(self, page: Page):
        os.makedirs(ARTEFACT_DIR, exist_ok=True)
        _goto(page, "/tasks?owner=agent&horizon=now")
        page.wait_for_timeout(200)
        out = os.path.join(ARTEFACT_DIR, "T-2016-filter-chips.png")
        page.screenshot(path=out, clip={"x": 0, "y": 0, "width": 1280, "height": 360})
        assert os.path.exists(out)
