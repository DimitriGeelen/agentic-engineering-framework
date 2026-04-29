"""T-1600: Forced-500 htmx error toast test.

T-1582 shipped a `<div id="toast-container">` with a `htmx:responseError`
handler that surfaces failed mutations to the human. The closing of T-1582
was held up because Steps couldn't easily reproduce a 500 — the manual path
required injecting a server fault. This Playwright test fills that gap by
intercepting an htmx request and forcing a 500, then asserting the toast
renders with the expected text + class.

Strategy: load `/review/<id>` (template that wires the error handler),
intercept the next `/api/task/<id>/toggle-ac` POST and reply 500, click an
AC checkbox, wait for the toast.

Drift class: error-handling UX — silent toasts pass DOM-grep but leave the
human with no signal that their click failed.
"""
import re
from typing import Optional

import pytest
from playwright.sync_api import Page, Route


TEST_URL = "http://localhost:3099"


def _url(path: str) -> str:
    return f"{TEST_URL}{path}"


def _find_reviewable_task(page: Page) -> Optional[str]:
    """Any task with at least one Human AC checkbox renderable on /review."""
    page.goto(_url("/approvals"))
    page.wait_for_load_state("domcontentloaded")
    content = page.content()
    match = re.search(r'href="/review/(T-\d+)"', content)
    return match.group(1) if match else None


class TestHtmxErrorToast:
    """Forced-500 path on /review/<id> — pin the toast contract."""

    def test_force_500_on_toggle_ac_renders_error_toast(self, page: Page):
        """Click an AC checkbox with a forced 500 — toast appears with error class."""
        task_id = _find_reviewable_task(page)
        if task_id is None:
            pytest.skip("No reviewable task found in /approvals — fixture inapplicable")

        def _intercept(route: Route):
            req = route.request
            if "/toggle-ac" in req.url and req.method == "POST":
                route.fulfill(
                    status=500,
                    body="Internal Server Error — synthetic fault for test",
                    content_type="text/plain",
                )
            else:
                route.continue_()

        page.route("**/*", _intercept)
        page.goto(_url(f"/review/{task_id}"))
        page.wait_for_load_state("domcontentloaded")

        checkbox = page.locator('input[type="checkbox"]').first
        if checkbox.count() == 0:
            pytest.skip(f"Task {task_id} has no Human ACs to click")

        checkbox.click()
        # Wait for the htmx:responseError handler to run + DOM update
        toast = page.locator('.wt-toast.error')
        toast.first.wait_for(state="visible", timeout=3000)

        text = toast.first.text_content() or ""
        assert text.strip(), "Error toast should have text content"
        # Toast renders class 'wt-toast error' (T-1582 contract)
        cls = toast.first.get_attribute("class") or ""
        assert "wt-toast" in cls and "error" in cls, (
            f"Toast missing wt-toast.error class: {cls!r}"
        )

    def test_500_path_does_not_leave_silent_failure(self, page: Page):
        """Negative: no toast container update on 500 == silent failure → would regress."""
        task_id = _find_reviewable_task(page)
        if task_id is None:
            pytest.skip("No reviewable task found")

        def _intercept(route: Route):
            if "/toggle-ac" in route.request.url and route.request.method == "POST":
                route.fulfill(status=500, body="boom", content_type="text/plain")
            else:
                route.continue_()

        page.route("**/*", _intercept)
        page.goto(_url(f"/review/{task_id}"))
        page.wait_for_load_state("domcontentloaded")

        # Snapshot toast container before click
        toasts_before = page.locator('#toast-container .wt-toast').count()

        checkbox = page.locator('input[type="checkbox"]').first
        if checkbox.count() == 0:
            pytest.skip("No checkbox to click")

        checkbox.click()
        page.wait_for_timeout(1500)

        toasts_after = page.locator('#toast-container .wt-toast').count()
        assert toasts_after > toasts_before, (
            "Forced 500 produced no toast — htmx:responseError handler "
            "regression. Was the script removed from review.html?"
        )
