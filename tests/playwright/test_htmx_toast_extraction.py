"""T-2120: structural pin for T-2074 + T-2119 htmx-toast.js extraction.

T-2074 extracted htmx error listeners from base.html (and review.html, after
the T-2119 follow-up) to web/static/htmx-toast.js. The existing
test_htmx_error_toast.py (T-1600) is broken for unrelated reasons (the
/toggle-ac route shape changed) and didn't catch the double-listener bug
that T-2119 had to fix. This test pins the extraction contract structurally:

  1. /review/<id> loads /static/htmx-toast.js (extraction is wired)
  2. /review/<id> has zero inline addEventListener('htmx:…' calls
     (no duplicate-listener regression — origin: T-2119)
  3. window.showToast is defined on the loaded page (delegation contract)
  4. The served htmx-toast.js body contains both 'htmx:responseError'
     and 'htmx:sendError' (the listeners actually moved into the module)

Why DOM-level structural and not a forced-fault click test:
  - Forced-fault click tests (T-1600) are fragile — they depend on the
    server's route shape and which specific htmx-triggered POST fires.
  - The structural contract is what regressions actually break: a future
    template edit re-adding inline listeners, or a module rewrite that
    drops one of the two event types.
"""
import os
import re
from typing import Optional

import pytest
from playwright.sync_api import Page


TEST_PORT = int(os.environ.get("FW_TEST_PORT", "3099"))
TEST_URL = f"http://localhost:{TEST_PORT}"


def _url(path: str) -> str:
    return f"{TEST_URL}{path}"


def _find_reviewable_task(page: Page) -> Optional[str]:
    """Any task with at least one Human AC checkbox renderable on /review."""
    page.goto(_url("/approvals"))
    page.wait_for_load_state("domcontentloaded")
    content = page.content()
    match = re.search(r'href="/review/(T-\d+)"', content)
    return match.group(1) if match else None


class TestHtmxToastExtraction:
    """Pin T-2074 + T-2119: htmx-toast.js extraction structural contract."""

    def test_review_html_loads_htmx_toast_script(self, page: Page):
        """/review/<id> must include <script src=…htmx-toast.js…>."""
        task_id = _find_reviewable_task(page)
        if task_id is None:
            pytest.skip("No reviewable task in /approvals — fixture inapplicable")

        page.goto(_url(f"/review/{task_id}"))
        page.wait_for_load_state("domcontentloaded")
        html = page.content()

        assert "static/htmx-toast.js" in html, (
            "/review/<id> missing htmx-toast.js script tag — T-2074 extraction "
            "regressed; standalone review.html will silently swallow htmx errors."
        )

    def test_review_html_has_no_inline_htmx_error_listeners(self, page: Page):
        """T-2119: no inline addEventListener('htmx:…') in served review HTML.

        Re-adding the inline pair while htmx-toast.js is also loaded produces
        a double-toast on every error. Either listener path may exist, but
        not both — htmx-toast.js owns wiring.
        """
        task_id = _find_reviewable_task(page)
        if task_id is None:
            pytest.skip("No reviewable task in /approvals")

        page.goto(_url(f"/review/{task_id}"))
        page.wait_for_load_state("domcontentloaded")
        html = page.content()

        offenders = re.findall(r"addEventListener\(['\"]htmx:(responseError|sendError)['\"]", html)
        assert not offenders, (
            f"/review/<id> contains inline htmx error listeners ({offenders}) "
            f"alongside the htmx-toast.js script load — T-2119 double-listener "
            f"regression. Remove the inline addEventListener block, keep showToast."
        )

    def test_window_showtoast_is_defined(self, page: Page):
        """Delegation contract: htmx-toast.js defers to window.showToast.

        Either review.html's inline showToast OR htmx-toast.js's fallback
        must publish `window.showToast` for the listener path to actually
        render a toast on error.
        """
        task_id = _find_reviewable_task(page)
        if task_id is None:
            pytest.skip("No reviewable task in /approvals")

        page.goto(_url(f"/review/{task_id}"))
        page.wait_for_load_state("domcontentloaded")
        # htmx-toast.js init() runs on DOMContentLoaded or sooner; give it a tick.
        page.wait_for_function("typeof window.showToast === 'function'", timeout=3000)

        defined = page.evaluate("typeof window.showToast")
        assert defined == "function", (
            f"window.showToast not a function (got {defined!r}) — neither "
            f"review.html nor htmx-toast.js published it."
        )

    def test_served_htmx_toast_js_wires_both_events(self, page: Page):
        """The module must address both responseError + sendError.

        Origin: dropping one of the two from htmx-toast.js while keeping the
        script load would silently regress one half of the error UX.
        """
        # Fetch the JS directly via the page's network layer.
        resp = page.request.get(_url("/static/htmx-toast.js"))
        assert resp.ok, f"GET /static/htmx-toast.js → {resp.status}"
        body = resp.text()

        assert "htmx:responseError" in body, (
            "htmx-toast.js does not handle htmx:responseError — half of "
            "the error UX is missing."
        )
        assert "htmx:sendError" in body, (
            "htmx-toast.js does not handle htmx:sendError — network-failure "
            "toast will not fire."
        )
