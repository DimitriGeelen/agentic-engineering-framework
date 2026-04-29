"""T-1600: End-to-end inception decide journey from /approvals.

Tests the navigation chain /approvals → /review/<id> for an inception task,
verifying that the inception card on /approvals points at the right review
page, that the review page renders the decide form, and that the form's
rationale + decision wiring matches what the backend expects.

Distinct from `test_review_interaction.py` (which pins the click-to-form
contract via synthesized HTML): this file walks the real navigation chain
and asserts the cross-surface integration. If /approvals starts emitting
malformed review links, this test catches it; the synthetic-HTML test
wouldn't.

Drift class: cross-surface navigation — clicking through /approvals to
/review must land on a renderable surface with the right form shape.
"""
import re
from typing import Optional

import pytest
from playwright.sync_api import Page, Route


TEST_URL = "http://localhost:3099"


def _url(path: str) -> str:
    return f"{TEST_URL}{path}"


def _find_first_inception_review_link(page: Page) -> Optional[str]:
    """Walk /approvals for the first inception task with a /review/<id> link."""
    page.goto(_url("/approvals"))
    page.wait_for_load_state("domcontentloaded")
    content = page.content()
    # Inception tasks are flagged on /approvals via either a workflow_type
    # marker or by being the first href to a task with workflow_type=inception
    # in its body. Walk all review links and pick the first whose body shows
    # the inception decide form (textarea[name="rationale"] + decide-btn).
    for tid in re.findall(r'href="/review/(T-\d+)"', content):
        resp = page.goto(_url(f"/review/{tid}"))
        if resp.status != 200:
            continue
        page.wait_for_load_state("domcontentloaded")
        body = page.content()
        if "decide-btn" in body and 'name="rationale"' in body:
            return tid
    return None


class TestInceptionDecideJourney:
    def test_approvals_links_to_review_page(self, page: Page):
        """/approvals must contain at least one /review/<id> link OR be
        legitimately empty. If links exist, navigating one returns 200."""
        page.goto(_url("/approvals"))
        page.wait_for_load_state("domcontentloaded")
        content = page.content()
        match = re.search(r'href="/review/(T-\d+)"', content)
        if match is None:
            pytest.skip("/approvals has no review links — empty queue")
        tid = match.group(1)
        resp = page.goto(_url(f"/review/{tid}"))
        assert resp.status == 200, (
            f"/approvals linked to /review/{tid} but the surface returned "
            f"{resp.status} — navigation regression."
        )

    def test_inception_review_renders_decide_form_with_rationale(self, page: Page):
        """For an inception task in decide-ready state, /review/<id> renders
        a form with textarea[name=rationale] + GO/NO-GO/DEFER buttons."""
        tid = _find_first_inception_review_link(page)
        if tid is None:
            pytest.skip("No inception task in decide-ready state currently")

        textarea = page.locator('textarea[name="rationale"]')
        assert textarea.count() > 0, "Decide form rationale textarea missing"

        for value in ("go", "no-go", "defer"):
            btn = page.locator(f'button[name="decision"][value="{value}"]')
            assert btn.count() > 0, f"{value} button missing on /review/{tid}"

    def test_full_decide_journey_posts_to_correct_endpoint(self, page: Page):
        """Walk /approvals → /review/<id>, fill rationale, click GO, assert
        the POST went to /inception/<id>/decide. Intercepted (no mutation)."""
        tid = _find_first_inception_review_link(page)
        if tid is None:
            pytest.skip("No inception task in decide-ready state currently")

        captured = {"url": None, "form": None}

        def _intercept(route: Route):
            req = route.request
            if "/inception/" in req.url and "/decide" in req.url and req.method == "POST":
                captured["url"] = req.url
                captured["form"] = req.post_data
                route.fulfill(
                    status=200,
                    body='<div class="decide-section">ok</div>',
                    content_type="text/html",
                )
            else:
                route.continue_()

        page.route("**/*", _intercept)

        # Walk /approvals → click first review link for the inception task
        page.goto(_url("/approvals"))
        page.wait_for_load_state("domcontentloaded")
        link = page.locator(f'a[href="/review/{tid}"]')
        assert link.count() > 0, f"Could not find /approvals link to /review/{tid}"
        link.first.click()
        page.wait_for_load_state("domcontentloaded")

        page.locator('textarea[name="rationale"]').first.fill("e2e test rationale")
        page.locator('button[name="decision"][value="go"]').first.click()
        page.wait_for_timeout(800)

        assert captured["url"] is not None, (
            f"Decide POST did not fire — form wiring may be broken on /review/{tid}"
        )
        assert f"/inception/{tid}/decide" in captured["url"], (
            f"Decide POST went to wrong URL: {captured['url']}"
        )
        assert "decision=go" in (captured["form"] or "")
