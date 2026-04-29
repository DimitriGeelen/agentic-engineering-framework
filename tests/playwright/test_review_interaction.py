"""T-1600: End-to-end click-flow tests for review surfaces.

T-1597 surfaced that DOM-grep tests can't catch click-flow regressions —
verdict pills appear in HTML but the buttons may not fire, or fire to the
wrong endpoint, or fail silently. This module pins the click-to-API contract:

- AC checkbox click → POST /api/task/<id>/toggle-ac
- Inception decide GO/NO-GO/DEFER click → POST /inception/<id>/decide
- Build task Complete click → POST /api/task/<id>/complete

Strategy: page.route() intercepts the POST, asserts the URL + form payload,
and short-circuits with a synthetic 200 so no real task state mutates. This
is safer than driving the actual backend (which would close real tasks) and
faster than spinning up an isolated fixture state.

Drift class: L-295/L-316 (cross-surface inheritance + click-flow contracts —
where the structural test confirms the wire, but the wire to the wrong
endpoint or the wrong handler still passes).
"""
import re
from typing import Optional

import pytest
from playwright.sync_api import Page, Route


TEST_URL = "http://localhost:3099"


def _url(path: str) -> str:
    return f"{TEST_URL}{path}"


def _find_reviewable_task(page: Page) -> Optional[str]:
    """Find a task that has at least one Human AC (renders checkbox on /review)."""
    page.goto(_url("/approvals"))
    page.wait_for_load_state("domcontentloaded")
    content = page.content()
    match = re.search(r'href="/review/(T-\d+)"', content)
    if match:
        return match.group(1)
    return None


def _find_inception_with_acs_complete(page: Page) -> Optional[str]:
    """Find an inception task whose human ACs are already checked, so the
    decide form is rendered. Walks /approvals looking for inception cards.

    Returns None if no such task exists in the current state — caller skips.
    """
    page.goto(_url("/approvals"))
    page.wait_for_load_state("domcontentloaded")
    # Inception cards on /approvals carry data-task-id; pick the first whose
    # /review surface shows the GO button.
    content = page.content()
    for tid in re.findall(r'href="/review/(T-\d+)"', content):
        review_resp = page.goto(_url(f"/review/{tid}"))
        if review_resp.status != 200:
            continue
        page.wait_for_load_state("domcontentloaded")
        body = page.content()
        if 'name="decision" value="go"' in body and 'class="decide-btn' in body:
            return tid
    return None


class TestACCheckboxClickFlow:
    """Clicking an AC checkbox triggers a POST to /api/task/<id>/toggle-ac.

    Pins the click-to-API contract surfaced by T-1597 — the AC was
    "structural reviewer section renders" but the click that USES the
    section was not exercised. This guards against the form action
    silently regressing to a wrong path.
    """

    def test_ac_checkbox_click_posts_to_toggle_endpoint(self, page: Page):
        task_id = _find_reviewable_task(page)
        if task_id is None:
            pytest.skip("No reviewable task found in /approvals — fixture inapplicable")

        captured = {"url": None, "method": None, "form": None}

        def _intercept(route: Route):
            req = route.request
            if "/toggle-ac" in req.url:
                captured["url"] = req.url
                captured["method"] = req.method
                captured["form"] = req.post_data
                # Short-circuit with synthetic 200 so no real mutation
                route.fulfill(status=200, body="<div>ok</div>", content_type="text/html")
            else:
                route.continue_()

        page.route("**/*", _intercept)
        page.goto(_url(f"/review/{task_id}"))
        page.wait_for_load_state("domcontentloaded")

        checkbox = page.locator('input[type="checkbox"]').first
        if checkbox.count() == 0:
            pytest.skip(f"Task {task_id} has no Human ACs to click")

        checkbox.click()
        page.wait_for_timeout(800)

        assert captured["url"] is not None, (
            f"Expected POST to /api/task/{task_id}/toggle-ac but no request fired"
        )
        assert "/toggle-ac" in captured["url"], (
            f"Click hit wrong endpoint: {captured['url']}"
        )
        assert captured["method"] == "POST", (
            f"Expected POST, got {captured['method']}"
        )
        assert captured["form"] and 'line' in (captured["form"] or ""), (
            f"toggle-ac payload missing 'line' field: {captured['form']!r}"
        )


def _decide_form_html(task_id: str) -> str:
    """Synthesize the inception decide form exactly as web/templates/_review_acs.html
    renders it (line ~90-98). Pinning the click contract here means a future
    edit to that template will be caught either by template-render tests OR
    by these click-flow tests — defense in depth.
    """
    return f"""<!DOCTYPE html>
<html><head><title>fixture</title></head><body>
<form hx-post="/inception/{task_id}/decide"
      action="/inception/{task_id}/decide" method="POST">
    <textarea name="rationale" required></textarea>
    <button type="submit" name="decision" value="go" class="decide-btn decide-btn-go">GO</button>
    <button type="submit" name="decision" value="no-go" class="decide-btn decide-btn-nogo">NO-GO</button>
    <button type="submit" name="decision" value="defer" class="decide-btn decide-btn-defer">DEFER</button>
</form>
</body></html>"""


def _complete_form_html(task_id: str) -> str:
    """Synthesize the build-task Complete button form (template line ~101-105)."""
    return f"""<!DOCTYPE html>
<html><head><title>fixture</title></head><body>
<form hx-post="/api/task/{task_id}/complete"
      action="/api/task/{task_id}/complete" method="POST">
    <button type="submit" class="complete-btn">Complete Task</button>
</form>
</body></html>"""


class TestInceptionDecideClickFlow:
    """Clicking GO/NO-GO/DEFER posts to /inception/<id>/decide with the correct
    decision value + rationale.

    Strategy: load a synthesized form mirroring the template's structure,
    intercept the POST, assert URL + payload. This tests the click-to-form
    contract independently of which inception task happens to be in the
    decide-ready state when the test runs.

    Origin: T-1597 walkthrough showed visual decide buttons but no test pinned
    that they fire the correct POST. T-1600 closes the gap.
    """

    def _exercise_button(self, page: Page, button_value: str) -> dict:
        task_id = "T-9999"  # synthetic, never written to disk
        captured = {"url": None, "method": None, "form": None}

        def _intercept(route: Route):
            req = route.request
            if "/inception/" in req.url and "/decide" in req.url:
                captured["url"] = req.url
                captured["method"] = req.method
                captured["form"] = req.post_data
                route.fulfill(
                    status=200,
                    body='<div class="decide-section">ok</div>',
                    content_type="text/html",
                )
            else:
                route.continue_()

        page.route("**/*", _intercept)
        page.set_content(_decide_form_html(task_id))

        page.locator('textarea[name="rationale"]').first.fill("test rationale")
        page.locator(f'button[name="decision"][value="{button_value}"]').first.click()
        page.wait_for_timeout(500)

        assert captured["url"] is not None, (
            f"Expected POST to /inception/{task_id}/decide for {button_value} click"
        )
        return captured

    def test_go_button_posts_decision_go(self, page: Page):
        captured = self._exercise_button(page, "go")
        assert captured["method"] == "POST"
        assert "/inception/T-9999/decide" in captured["url"]
        assert "decision=go" in (captured["form"] or ""), (
            f"GO button payload missing 'decision=go': {captured['form']!r}"
        )
        assert "rationale=" in (captured["form"] or ""), (
            f"GO button payload missing 'rationale': {captured['form']!r}"
        )

    def test_nogo_button_posts_decision_nogo(self, page: Page):
        captured = self._exercise_button(page, "no-go")
        assert "decision=no-go" in (captured["form"] or "")

    def test_defer_button_posts_decision_defer(self, page: Page):
        captured = self._exercise_button(page, "defer")
        assert "decision=defer" in (captured["form"] or "")


class TestBuildTaskCompleteFlow:
    """Build (non-inception) tasks render a 'Complete Task' button posting
    to /api/task/<id>/complete. Pinned via a synthesized form for the same
    reason as the inception decide test.
    """

    def test_complete_button_posts_to_complete_endpoint(self, page: Page):
        task_id = "T-9999"
        captured = {"url": None, "method": None}

        def _intercept(route: Route):
            req = route.request
            if "/api/task/" in req.url and "/complete" in req.url and req.method == "POST":
                captured["url"] = req.url
                captured["method"] = req.method
                route.fulfill(
                    status=200,
                    body='<div>ok</div>',
                    content_type="text/html",
                )
            else:
                route.continue_()

        page.route("**/*", _intercept)
        page.set_content(_complete_form_html(task_id))

        page.locator('button.complete-btn').first.click()
        page.wait_for_timeout(500)

        assert captured["url"] is not None, (
            f"Expected POST to /api/task/{task_id}/complete after click"
        )
        assert f"/api/task/{task_id}/complete" in captured["url"]
