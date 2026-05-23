"""Playwright guard for T-2012 (arc-007 S6a) — ⌘K command palette, end-to-end.

Proves the behaviours the unit tests can't reach through a real browser:
  - ⌘K / Ctrl-K opens the palette and Esc closes it, on a fresh load AND after an
    htmx #content swap (the listener lives in the shell → survives the swap);
  - clicking the nav-search magnifier opens the palette (not a /search navigation);
  - typing fuzzy-matches the nav whitelist; ArrowDown/Up move the highlight; Enter
    jumps (SPA swap, URL updates);
  - a no-match query collapses to the "Search …" row that routes to discovery.search.

Captures a review screenshot for the human [REVIEW] (T-1575). Runs against the
isolated port-3099 harness (conftest), never :3000. Each test gets a fresh page.
"""
import os

from playwright.sync_api import Page, expect

TEST_URL = "http://localhost:3099"
ARTEFACT_DIR = os.path.join(
    os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
    "web", "static", "ux-review",
)

PALETTE = "#wt-command-palette"
INPUT = "#wt-palette-input"
RESULTS = "#wt-palette-results"
SELECTED = "#wt-palette-results li[aria-selected='true']"


def _goto(page: Page, path: str):
    page.goto(f"{TEST_URL}{path}", timeout=60000)
    page.wait_for_load_state("domcontentloaded")


def _open(page: Page):
    page.keyboard.press("Control+k")
    expect(page.locator(PALETTE)).to_be_visible()
    expect(page.locator(INPUT)).to_be_focused()


class TestCommandPalette:
    def test_open_close_fresh(self, page: Page):
        _goto(page, "/tasks")
        expect(page.locator(PALETTE)).to_be_hidden()
        _open(page)
        page.keyboard.press("Escape")
        expect(page.locator(PALETTE)).to_be_hidden()

    def test_open_close_after_htmx_swap(self, page: Page):
        _goto(page, "/tasks")
        # navigate via the always-visible Docs nav link → htmx swaps #content
        # (the palette lives outside #content, so its listener must survive the swap)
        page.locator("nav.site-nav .nav-docs a").click()
        page.wait_for_url("**/project", timeout=60000)
        # the shell listener must still be live after the swap
        _open(page)
        page.keyboard.press("Escape")
        expect(page.locator(PALETTE)).to_be_hidden()

    def test_nav_search_click_opens_palette(self, page: Page):
        _goto(page, "/tasks")
        page.locator("nav.site-nav .nav-search a[data-palette-open]").click()
        # opens the palette in place — does NOT navigate to /search
        expect(page.locator(PALETTE)).to_be_visible()
        expect(page).to_have_url(f"{TEST_URL}/tasks")

    def test_fuzzy_jump_arrow_enter(self, page: Page):
        _goto(page, "/tasks")
        _open(page)
        page.locator(INPUT).fill("arc")
        # at least one nav hit + a search row
        expect(page.locator(f"{RESULTS} li")).not_to_have_count(0)
        first_url = page.locator(SELECTED).get_attribute("data-url")
        # ArrowDown then ArrowUp returns to the first row (selection wraps/moves)
        page.keyboard.press("ArrowDown")
        moved_url = page.locator(SELECTED).get_attribute("data-url")
        assert moved_url != first_url, "ArrowDown did not move the highlight"
        page.keyboard.press("ArrowUp")
        assert page.locator(SELECTED).get_attribute("data-url") == first_url
        # Enter jumps to the highlighted destination (SPA swap, URL updates)
        page.keyboard.press("Enter")
        expect(page.locator(PALETTE)).to_be_hidden()
        page.wait_for_url(f"{TEST_URL}{first_url}", timeout=60000)

    def test_jump_targets_are_whitelisted_nav_destinations(self, page: Page):
        _goto(page, "/tasks")
        _open(page)
        page.locator(INPUT).fill("a")
        # every jump row's url is app-relative (from the NAV_ITEMS whitelist)
        jump_urls = page.locator(f"{RESULTS} li[data-kind='jump']").evaluate_all(
            "els => els.map(e => e.dataset.url)"
        )
        assert jump_urls, "no jump rows rendered"
        for u in jump_urls:
            assert u.startswith("/"), f"jump url not app-relative: {u}"

    def test_search_fallthrough_routes_to_discovery(self, page: Page):
        _goto(page, "/tasks")
        _open(page)
        # a query that matches no nav label collapses to just the search row
        page.locator(INPUT).fill("zzqqxx")
        search_row = page.locator(f"{RESULTS} li[data-kind='search']")
        expect(search_row).to_have_count(1)
        assert search_row.get_attribute("data-url") == "/search?q=zzqqxx"
        page.keyboard.press("Enter")
        page.wait_for_url("**/search?q=zzqqxx", timeout=60000)

    def test_capture_review_artefact(self, page: Page):
        """Screenshot the open palette for the human [REVIEW]."""
        os.makedirs(ARTEFACT_DIR, exist_ok=True)
        _goto(page, "/tasks")
        _open(page)
        page.locator(INPUT).fill("lear")
        page.wait_for_timeout(150)
        out = os.path.join(ARTEFACT_DIR, "T-2012-palette-open.png")
        page.screenshot(path=out, clip={"x": 0, "y": 0, "width": 1280, "height": 600})
        assert os.path.exists(out)
