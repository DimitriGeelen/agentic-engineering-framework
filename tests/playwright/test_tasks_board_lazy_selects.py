"""T-3575 - board cards render one <option> per select and fill the rest on interaction.

The change POST is intercepted with page.route (synthetic 200), so no real task is edited.
"""
from playwright.sync_api import Page, expect

from tests.playwright.target import TEST_URL

CARD = "article.kanban-card"


def _goto_board(page: Page):
    page.goto(f"{TEST_URL}/tasks", timeout=60000)
    page.wait_for_load_state("domcontentloaded")
    expect(page.locator(CARD).first).to_be_attached()


def test_select_starts_with_one_option_and_fills_on_focus(page: Page):
    _goto_board(page)
    sel = page.locator(CARD).first.locator("select[name=horizon]")
    assert sel.locator("option").count() == 1
    sel.focus()
    assert sel.locator("option").all_text_contents() == ["now", "next", "later"]


def test_change_posts_field_value_with_csrf_header(page: Page):
    seen = []

    def _fake(route, request):
        seen.append((request.method, request.url, request.post_data, request.headers.get("x-csrf-token")))
        route.fulfill(status=200, body="")

    page.route("**/api/task/**", _fake)
    _goto_board(page)
    card = page.locator(CARD).first
    tid = card.get_attribute("data-task-id")
    sel = card.locator("select[name=horizon]")
    sel.focus()  # a real user always focuses/mousedowns first, which fills the options
    sel.select_option("later")
    page.wait_for_timeout(500)
    assert len(seen) == 1
    method, url, body, csrf = seen[0]
    assert method == "POST" and url.endswith(f"/api/task/{tid}/horizon")
    assert body == "horizon=later" and csrf
