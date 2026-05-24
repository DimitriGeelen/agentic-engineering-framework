"""Playwright guard for T-2021 — cockpit System Health traceability render.

Proves the browser behaviour against the *real* scan data (which carries the dict
shape `{score, total_tasks, completed, active}`): the System Health → Traceability
line shows a percentage, never the raw Python dict repr. Captures a review
screenshot for the human [REVIEW] (T-1575).

Read-only page → inherently net-zero. Runs against the isolated port-3099 harness
(conftest), never :3000.
"""
import os

from playwright.sync_api import Page, expect

TEST_URL = "http://localhost:3099"
ARTEFACT_DIR = os.path.join(
    os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
    "web", "static", "ux-review",
)


def _trace_li(page: Page):
    return page.locator("ul.wt-pulse li", has_text="Traceability")


class TestCockpitTraceability:
    def test_traceability_is_a_percentage_not_a_dict(self, page: Page):
        page.goto(f"{TEST_URL}/", timeout=60000)
        page.wait_for_load_state("domcontentloaded")
        li = _trace_li(page)
        expect(li.first).to_be_visible()
        text = li.first.inner_text()
        assert "%" in text, f"traceability not a percentage: {text!r}"
        assert "{'score'" not in text, f"raw dict leaked into render: {text!r}"

    def test_capture_review_artefact(self, page: Page):
        os.makedirs(ARTEFACT_DIR, exist_ok=True)
        page.goto(f"{TEST_URL}/", timeout=60000)
        page.wait_for_load_state("domcontentloaded")
        li = _trace_li(page)
        li.first.scroll_into_view_if_needed()
        page.wait_for_timeout(200)
        out = os.path.join(ARTEFACT_DIR, "T-2021-cockpit-traceability.png")
        page.screenshot(path=out, clip={"x": 0, "y": 0, "width": 1280, "height": 720})
        assert os.path.exists(out)
