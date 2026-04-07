"""Playwright tests for /docs/generated/<card_name> detail page (T-1026).

Covers: detail loads, has content, nonexistent returns 404, invalid chars return 404.
Route: web/blueprints/docs.py:106
"""
import os

from playwright.sync_api import Page

TEST_URL = "http://localhost:3099"
DOCS_DIR = "/opt/999-Agentic-Engineering-Framework/docs/generated/components"


def _url(path: str) -> str:
    return f"{TEST_URL}{path}"


def _real_card_name() -> str:
    """Pick a real card name from the generated docs directory."""
    cards = [f[:-3] for f in os.listdir(DOCS_DIR) if f.endswith(".md")]
    return cards[0] if cards else "add-learning"


class TestDocsDetail:
    """Detail page for a single generated component doc."""

    def test_docs_detail_loads(self, page: Page):
        card = _real_card_name()
        resp = page.goto(_url(f"/docs/generated/{card}"))
        assert resp.status == 200

    def test_docs_detail_has_content(self, page: Page):
        card = _real_card_name()
        page.goto(_url(f"/docs/generated/{card}"))
        page.wait_for_load_state("domcontentloaded")
        heading = page.locator("h1, h2, h3")
        assert heading.count() > 0, "Detail page should have rendered HTML headings"

    def test_docs_detail_nonexistent(self, page: Page):
        resp = page.goto(_url("/docs/generated/nonexistent-xyz"))
        assert resp.status == 404

    def test_docs_detail_invalid_chars(self, page: Page):
        resp = page.goto(_url("/docs/generated/../../etc"))
        assert resp.status == 404
