"""Playwright regression for /review/<task_id> CSRF wiring (T-1453).

Guards against the T-1452 regression: review.html is a standalone template
that does NOT extend base.html. Without the htmx:configRequest listener
loaded via web/static/csrf-htmx.js, every htmx mutation on the page returns
403 silently (csrf_protect, T-1343 / G-048).

Test strategy:
- Open /review/<id> and confirm the csrf-htmx.js script is loaded
- Confirm the csrf-token meta tag is rendered
- Tick a Human AC checkbox and assert the toggle-ac request returned a
  non-403 status (200 expected; 4xx other than 403 acceptable for line-mismatch
  cases since this test only guards CSRF wiring, not toggle-ac semantics).
"""
import re

from playwright.sync_api import Page, Route

TEST_URL = "http://localhost:3099"


def _url(path: str) -> str:
    return f"{TEST_URL}{path}"


def _find_reviewable_task(page: Page) -> str:
    """Find a real task with at least one Human AC by walking /approvals."""
    page.goto(_url("/approvals"))
    page.wait_for_load_state("domcontentloaded")
    content = page.content()
    match = re.search(r'href="/review/(T-\d+)"', content)
    if match:
        return match.group(1)
    match = re.search(r"T-\d{3,}", content)
    return match.group(0) if match else "T-1452"


class TestReviewCsrf:
    """Standalone template /review/<id> must wire CSRF (regression guard for T-1452)."""

    def test_review_page_loads_csrf_script(self, page: Page):
        """The csrf-htmx.js script tag must be present in /review/<id>."""
        task_id = _find_reviewable_task(page)
        page.goto(_url(f"/review/{task_id}"))
        page.wait_for_load_state("domcontentloaded")
        content = page.content()
        assert "csrf-htmx.js" in content, (
            "review.html must load /static/csrf-htmx.js — without it, every "
            "htmx mutation returns 403 silently (T-1452 regression)"
        )

    def test_review_page_has_csrf_meta(self, page: Page):
        """The csrf-token meta tag must be present so the listener can read it."""
        task_id = _find_reviewable_task(page)
        page.goto(_url(f"/review/{task_id}"))
        page.wait_for_load_state("domcontentloaded")
        meta = page.locator('meta[name="csrf-token"]')
        assert meta.count() == 1
        token = meta.first.get_attribute("content")
        assert token and len(token) > 16

    def test_toggle_ac_not_403(self, page: Page):
        """Ticking a Human AC must not 403 — the CSRF header must be sent."""
        task_id = _find_reviewable_task(page)

        captured = {"status": None, "url": None}

        def _on_response(response):
            if "/api/task/" in response.url and "/toggle-ac" in response.url:
                captured["status"] = response.status
                captured["url"] = response.url

        page.on("response", _on_response)
        page.goto(_url(f"/review/{task_id}"))
        page.wait_for_load_state("domcontentloaded")

        checkbox = page.locator('input[type="checkbox"]').first
        if checkbox.count() == 0:
            return  # task has no Human ACs to toggle — test inapplicable, skip

        checkbox.click()
        # Wait for any in-flight toggle-ac request to complete
        page.wait_for_timeout(800)

        assert captured["status"] is not None, (
            "Expected at least one /api/task/<id>/toggle-ac request after click"
        )
        assert captured["status"] != 403, (
            f"toggle-ac returned 403 → CSRF token not sent. URL={captured['url']}. "
            "This is the T-1452 regression — review.html missing csrf-htmx.js."
        )
