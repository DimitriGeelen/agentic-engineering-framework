"""Playwright guard for T-2020 (arc-007 S6d) — cockpit live activity feed.

Proves the browser behaviour:
  - the cockpit's "Recent activity" card loads the htmx fragment on page load and shows
    commit entries (task link + message + relative time);
  - the card is wired to POLL (hx-trigger includes "every …s") so it refreshes without a reload.

Read-only feature → inherently net-zero (no mutation). Captures a review screenshot for the
human [REVIEW] (T-1575). Runs against the isolated port-3099 harness (conftest), never :3000.
"""
import os

from playwright.sync_api import Page, expect

from tests.playwright.target import TEST_URL
ARTEFACT_DIR = os.path.join(
    os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
    "web", "static", "ux-review",
)

CARD = "#wt-activity"


def _goto_cockpit(page: Page):
    page.goto(f"{TEST_URL}/", timeout=60000)
    page.wait_for_load_state("domcontentloaded")
    expect(page.locator(CARD)).to_be_attached()


class TestCockpitActivity:
    def test_card_loads_activity_entries(self, page: Page):
        _goto_cockpit(page)
        # htmx 'load' trigger fetches the fragment → entries (or the empty-state) appear
        page.wait_for_timeout(800)
        items = page.locator(f"{CARD} .wt-activity-item")
        # the repo always has recent commits, so at least one entry renders with a task link
        expect(items.first).to_be_visible()
        expect(page.locator(f"{CARD} a.wt-activity-task").first).to_be_visible()

    def test_card_is_wired_to_poll(self, page: Page):
        _goto_cockpit(page)
        trigger = page.locator(CARD).get_attribute("hx-trigger")
        assert trigger and "every" in trigger, f"activity card not polling: hx-trigger={trigger!r}"
        assert page.locator(CARD).get_attribute("hx-get") == "/cockpit/activity"

    def test_capture_review_artefact(self, page: Page):
        os.makedirs(ARTEFACT_DIR, exist_ok=True)
        _goto_cockpit(page)
        page.wait_for_timeout(800)
        # scroll the activity card into view for the screenshot
        page.locator(CARD).scroll_into_view_if_needed()
        page.wait_for_timeout(200)
        out = os.path.join(ARTEFACT_DIR, "T-2020-cockpit-activity.png")
        page.screenshot(path=out, clip={"x": 0, "y": 0, "width": 1280, "height": 720})
        assert os.path.exists(out)
