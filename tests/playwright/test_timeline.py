"""Playwright tests for Timeline page (T-981).

Covers: page loads, session entries present, session cards have expected structure.
"""
from playwright.sync_api import Page

TEST_URL = "http://localhost:3099"


def _url(path: str) -> str:
    return f"{TEST_URL}{path}"


class TestTimelinePage:
    """Timeline page renders with session handover entries.

    Note: Timeline page is slow (parses many handover files), so we use
    a longer timeout than other pages.
    """

    TIMEOUT = 60000  # 60s — timeline parses ~100+ handover files

    def test_timeline_page_loads(self, page: Page):
        resp = page.goto(_url("/timeline"), timeout=self.TIMEOUT)
        assert resp.status == 200

    def test_timeline_has_content(self, page: Page):
        page.goto(_url("/timeline"), timeout=self.TIMEOUT)
        page.wait_for_load_state("domcontentloaded", timeout=self.TIMEOUT)
        content = page.content()
        assert len(content) > 1000, "Timeline page should have substantial content"

    def test_timeline_has_session_entries(self, page: Page):
        """Timeline should show at least one session handover."""
        page.goto(_url("/timeline"), timeout=self.TIMEOUT)
        page.wait_for_load_state("domcontentloaded", timeout=self.TIMEOUT)
        content = page.content()
        assert "S-20" in content, "Timeline should show session entries"

    def test_timeline_has_heading(self, page: Page):
        page.goto(_url("/timeline"), timeout=self.TIMEOUT)
        page.wait_for_load_state("domcontentloaded", timeout=self.TIMEOUT)
        heading = page.locator("h1, h2")
        assert heading.count() > 0, "Timeline page should have a heading"
