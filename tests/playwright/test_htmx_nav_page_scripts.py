"""T-5130 (found under T-5129, 1409): base.html boosts every link, and htmx runs a swapped page's
inline scripts before that page's own <script src> libraries have loaded. /bvp ("d3 is not
defined") and /terminal ("io is not defined") broke when reached through in-app navigation.
A GET navigation into #content that brings a not-yet-loaded external script is now a full load;
every other navigation stays a swap."""
from playwright.sync_api import Page

from tests.playwright.target import TEST_URL


def _navigate(page: Page, path: str, wait_ms: int = 25000):
    errors, loads = [], []
    page.on("pageerror", lambda e: errors.append(str(e)))
    page.goto(f"{TEST_URL}/fabric")
    page.wait_for_load_state("domcontentloaded")
    page.on("load", lambda *_: loads.append(1))
    # a real boosted navigation: a plain link inside the hx-boost body, clicked
    page.evaluate(
        """p => { const a = document.createElement('a'); a.href = p; a.textContent = 'go';
                  document.getElementById('content').appendChild(a); htmx.process(a); a.click(); }""",
        path)
    page.wait_for_function(f"() => location.pathname === '{path}'", timeout=wait_ms)
    page.wait_for_timeout(3000)
    return errors, bool(loads)


class TestBoostedNavigationRunsPageScriptsInOrder:
    def test_bvp_has_d3_when_reached_through_the_nav(self, page: Page):
        errors, full = _navigate(page, "/bvp")
        assert not [e for e in errors if "is not defined" in e], errors
        assert full, "a page that brings its own library should be a full load"

    def test_terminal_has_socketio_when_reached_through_the_nav(self, page: Page):
        errors, full = _navigate(page, "/terminal")
        assert not [e for e in errors if "is not defined" in e], errors

    def test_an_ordinary_page_stays_a_swap(self, page: Page):
        errors, full = _navigate(page, "/tasks")
        assert not full, "a page without its own external scripts must stay an htmx swap"
