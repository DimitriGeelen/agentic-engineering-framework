"""T-5145: picking a filter from the task-list selects filters the whole list.

Every filter control sent its siblings with hx-include="[name='status'],…", which also
matched each row's inline edit selects and the new-task form, so the first row's
status/type/owner/horizon rode along as filters: picking "work-completed" collapsed
the list to a handful of tasks with no pager (independent reviewer on T-5136).
"""
import re

from playwright.sync_api import Page

from tests.playwright.target import TEST_URL


def _wait_list(page: Page):
    page.locator("table [data-bulk-select]").first.wait_for(timeout=120000)


def _showing(page: Page):
    m = re.search(r"Showing (\d+)–(\d+) of (\d+)", page.content())
    return tuple(int(x) for x in m.groups()) if m else None


def _pick(page: Page, name: str, value: str, url_part: str):
    # the toolbar control (it carries hx-get; a row's edit select posts through its form),
    # chosen without relying on the T-5145 marker so the test reproduces the bug unfixed
    page.locator(f"select[name='{name}'][hx-get]").first.select_option(value)
    page.wait_for_function(f"location.search.includes('{url_part}')", timeout=120000)
    page.wait_for_timeout(1000)
    _wait_list(page)


def test_status_and_sort_selects_filter_the_whole_list(page: Page):
    page.goto(f"{TEST_URL}/tasks?view=list")
    _wait_list(page)
    _pick(page, "status", "work-completed", "status=work-completed")
    shown = _showing(page)
    # the whole corpus's completed tasks, paged, not the handful a row's values allow
    assert shown and shown[2] > 200, shown
    _pick(page, "sort", "name", "sort=name")
    shown = _showing(page)
    assert shown and shown[2] > 200, shown
    q = page.evaluate("location.search")
    assert "status=work-completed" in q and "sort=name" in q, q
    # nothing from a row select or the new-task form rode along
    from urllib.parse import parse_qs
    args = parse_qs(q.lstrip("?"), keep_blank_values=True)
    for leaked in ("type", "owner", "horizon"):
        assert all(v == "" for v in args.get(leaked, [""])), (leaked, args.get(leaked))


def test_no_filter_include_matches_a_row_select(page: Page):
    page.goto(f"{TEST_URL}/tasks?view=list")
    _wait_list(page)
    includes = page.evaluate(
        "[...document.querySelectorAll('[data-task-filter][hx-include]')].map(e => e.getAttribute('hx-include'))")
    assert includes and all(i == "[data-task-filter]" for i in includes), includes
    leaked = page.evaluate(
        "[...document.querySelectorAll('[data-task-filter]')].filter(e => e.closest('table, form')).length")
    assert leaked == 0
