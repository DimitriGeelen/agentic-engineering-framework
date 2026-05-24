"""Playwright guard for T-2019 (arc-007 S4d) — drag-to-reorder kanban, end-to-end.

Proves the browser-only behaviours of cross-column drag:
  - dragging a card onto a DIFFERENT column fires a POST to /api/task/<id>/status with the
    target column's status, and the success toast appears;
  - dropping a card back on its OWN column is a no-op (no POST);
  - the drag listeners survive an htmx #content swap (board → list → board, then drag still
    fires) — they are document-delegated in base.html, attached once;
  - making the card draggable did not hijack its other interactions (bulk checkbox + the
    panel-open id link still work).

Net-zero: the status POST is intercepted with page.route and short-circuited with a synthetic
200, so NO real `fw task update` runs. Runs against the isolated port-3099 harness (conftest),
never :3000. Captures a review screenshot for the human [REVIEW] (T-1575).
"""
import os

from playwright.sync_api import Page, Route, expect

TEST_URL = "http://localhost:3099"
ARTEFACT_DIR = os.path.join(
    os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
    "web", "static", "ux-review",
)

CARD = "article.kanban-card"
COLUMN = ".kanban-column"


def _goto_board(page: Page):
    page.goto(f"{TEST_URL}/tasks", timeout=60000)
    page.wait_for_load_state("domcontentloaded")
    expect(page.locator(CARD).first).to_be_attached()


def _source_status(page: Page) -> str:
    return page.locator(CARD).first.evaluate(
        "el => el.closest('.kanban-column').getAttribute('data-status')"
    )


def _other_column(page: Page, source_status: str):
    cols = page.locator(COLUMN)
    for i in range(cols.count()):
        s = cols.nth(i).get_attribute("data-status")
        if s and s != source_status:
            return cols.nth(i), s
    return None, None


class TestKanbanDrag:
    def test_drag_to_other_column_posts_status_and_toasts(self, page: Page):
        captured = {"url": None, "body": None}

        def _intercept(route: Route):
            req = route.request
            if "/status" in req.url and req.method == "POST":
                captured["url"] = req.url
                captured["body"] = req.post_data
                route.fulfill(status=200, body="<p>ok</p>", content_type="text/html")
            else:
                route.continue_()

        page.route("**/*", _intercept)
        _goto_board(page)
        src_status = _source_status(page)
        target, target_status = _other_column(page, src_status)
        assert target is not None, "need at least two status columns"

        page.locator(CARD).first.drag_to(target)
        page.wait_for_timeout(700)

        assert captured["url"] is not None, "cross-column drag fired no status POST"
        assert "/api/task/" in captured["url"] and "/status" in captured["url"]
        assert f"status={target_status}" in (captured["body"] or "")
        expect(page.locator(".wt-toast")).to_contain_text("Moved")

    def test_same_column_drop_is_noop(self, page: Page):
        fired = {"n": 0}

        def _intercept(route: Route):
            req = route.request
            if "/status" in req.url and req.method == "POST":
                fired["n"] += 1
                route.fulfill(status=200, body="<p>ok</p>", content_type="text/html")
            else:
                route.continue_()

        page.route("**/*", _intercept)
        _goto_board(page)
        src_status = _source_status(page)
        # drop the card onto its OWN column → handler short-circuits, no POST
        own_col = page.locator(f"{COLUMN}[data-status='{src_status}']").first
        page.locator(CARD).first.drag_to(own_col)
        page.wait_for_timeout(500)
        assert fired["n"] == 0, "same-column drop must not POST a status change"

    def test_listeners_survive_content_swap(self, page: Page):
        captured = {"url": None}

        def _intercept(route: Route):
            req = route.request
            if "/status" in req.url and req.method == "POST":
                captured["url"] = req.url
                route.fulfill(status=200, body="<p>ok</p>", content_type="text/html")
            else:
                route.continue_()

        page.route("**/*", _intercept)
        _goto_board(page)
        # htmx #content swap away (list) and back (board) — the document-delegated drag
        # listeners are attached once in base.html, so they must survive the innerHTML swap.
        page.evaluate(
            "() => window.htmx.ajax('GET','/tasks?view=list',{target:'#content',swap:'innerHTML'})"
        )
        page.wait_for_timeout(500)
        page.evaluate(
            "() => window.htmx.ajax('GET','/tasks?view=board',{target:'#content',swap:'innerHTML'})"
        )
        page.wait_for_timeout(700)
        expect(page.locator(CARD).first).to_be_attached()
        src_status = _source_status(page)
        target, _ = _other_column(page, src_status)
        page.locator(CARD).first.drag_to(target)
        page.wait_for_timeout(700)
        assert captured["url"] is not None, "drag stopped firing after a #content swap"

    def test_drag_does_not_hijack_card_interactions(self, page: Page):
        _goto_board(page)
        # the bulk checkbox on a draggable card still toggles the bulk bar
        page.locator(f"{CARD} input.wt-bulk-select").first.check()
        expect(page.locator("#wt-bulk-bar")).to_be_visible()
        page.locator("#wt-bulk-bar [data-bulk-clear]").click()
        # the id link still opens the slide-in panel
        page.locator(f"{CARD} [data-task-panel]").first.click()
        expect(page.locator("#wt-task-panel-body .wt-task-panel-id")).to_be_visible()

    def test_capture_review_artefact(self, page: Page):
        os.makedirs(ARTEFACT_DIR, exist_ok=True)
        _goto_board(page)
        src_status = _source_status(page)
        target, _ = _other_column(page, src_status)
        # show the drop-target affordance + a dragging card for the review screenshot
        page.locator(CARD).first.evaluate("el => el.classList.add('kanban-dragging')")
        target.evaluate("el => el.classList.add('kanban-drop-target')")
        page.wait_for_timeout(200)
        out = os.path.join(ARTEFACT_DIR, "T-2019-kanban-drag.png")
        page.screenshot(path=out, clip={"x": 0, "y": 0, "width": 1280, "height": 720})
        assert os.path.exists(out)
