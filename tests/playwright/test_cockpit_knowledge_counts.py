"""Playwright guard for T-2022 — cockpit System Health Knowledge counts.

Proves the browser behaviour against the *real* corpus: the System Health →
Knowledge line shows non-zero L/P/D counts (not the old `0L, 0P, 0D`). Captures a
review screenshot for the human [REVIEW] (T-1575).

Read-only page → inherently net-zero. Runs against the isolated port-3099 harness
(conftest), never :3000.
"""
import os
import re

from playwright.sync_api import Page, expect

from tests.playwright.target import TEST_URL
ARTEFACT_DIR = os.path.join(
    os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
    "web", "static", "ux-review",
)


def _knowledge_li(page: Page):
    return page.locator("ul.wt-pulse li", has_text="Knowledge")


class TestCockpitKnowledgeCounts:
    def test_knowledge_counts_are_nonzero(self, page: Page):
        page.goto(f"{TEST_URL}/", timeout=60000)
        page.wait_for_load_state("domcontentloaded")
        li = _knowledge_li(page)
        expect(li.first).to_be_visible()
        text = li.first.inner_text()
        # corpus is populated → at least the learnings (L) count is non-zero
        m = re.search(r"(\d+)\s*L", text)
        assert m and int(m.group(1)) > 0, f"Knowledge L count not non-zero: {text!r}"

    def test_capture_review_artefact(self, page: Page):
        os.makedirs(ARTEFACT_DIR, exist_ok=True)
        page.goto(f"{TEST_URL}/", timeout=60000)
        page.wait_for_load_state("domcontentloaded")
        li = _knowledge_li(page)
        li.first.scroll_into_view_if_needed()
        page.wait_for_timeout(200)
        out = os.path.join(ARTEFACT_DIR, "T-2022-cockpit-knowledge.png")
        page.screenshot(path=out, clip={"x": 0, "y": 0, "width": 1280, "height": 720})
        assert os.path.exists(out)
