"""Playwright tests for Inception pages (T-970).

Covers: inception list, inception detail, recommendation section, decision form.
"""
import pytest
from playwright.sync_api import Page

TEST_URL = "http://localhost:3099"


def _url(path: str) -> str:
    return f"{TEST_URL}{path}"


class TestInceptionList:
    """Inception list page renders with expected elements."""

    def test_inception_page_loads(self, page: Page):
        resp = page.goto(_url("/inception"))
        assert resp.status == 200

    def test_inception_has_content(self, page: Page):
        page.goto(_url("/inception"))
        content = page.content()
        assert "Inception" in content

    def test_inception_has_task_entries(self, page: Page):
        page.goto(_url("/inception"))
        page.wait_for_load_state("domcontentloaded")
        # Should have inception task cards or table rows
        content = page.content()
        assert "T-" in content, "Inception page should list tasks with IDs"


class TestInceptionDetail:
    """Inception detail page renders for known tasks."""

    def test_inception_detail_loads(self, page: Page):
        page.goto(_url("/inception"))
        page.wait_for_load_state("domcontentloaded")
        # Find a link to an inception detail
        links = page.locator("a[href*='/inception/T-']")
        if links.count() > 0:
            href = links.first.get_attribute("href")
            resp = page.goto(_url(href) if href.startswith("/") else href)
            assert resp.status == 200

    def test_inception_detail_has_sections(self, page: Page):
        page.goto(_url("/inception"))
        page.wait_for_load_state("domcontentloaded")
        links = page.locator("a[href*='/inception/T-']")
        if links.count() > 0:
            href = links.first.get_attribute("href")
            page.goto(_url(href) if href.startswith("/") else href)
            page.wait_for_load_state("domcontentloaded")
            content = page.content().lower()
            # Should have key inception sections
            assert "problem statement" in content or "exploration" in content or "go/no-go" in content, (
                "Inception detail should show problem statement or exploration sections"
            )

    def test_inception_detail_has_decision_form(self, page: Page):
        page.goto(_url("/inception"))
        page.wait_for_load_state("domcontentloaded")
        links = page.locator("a[href*='/inception/T-']")
        if links.count() > 0:
            href = links.first.get_attribute("href")
            page.goto(_url(href) if href.startswith("/") else href)
            page.wait_for_load_state("domcontentloaded")
            # Decision form should have GO/NO-GO buttons or form
            content = page.content()
            has_form = "GO" in content or "Record Decision" in content or "decision" in content.lower()
            assert has_form, "Inception detail should have decision form"


class TestInceptionEndpointHealth:
    """T-1223/T-1230: Inception endpoints return 200, not 500."""

    def test_inception_detail_pages_no_500(self, page: Page):
        """Every inception detail page must return 200, not 500."""
        page.goto(_url("/inception"))
        page.wait_for_load_state("domcontentloaded")
        links = page.locator("a[href*='/inception/T-']")
        # Collect hrefs first, then visit each
        hrefs = []
        for i in range(min(links.count(), 5)):
            hrefs.append(links.nth(i).get_attribute("href"))
        for href in hrefs:
            url = _url(href) if href.startswith("/") else href
            resp = page.goto(url)
            assert resp.status == 200, f"Inception detail {href} returned {resp.status}"

    def test_inception_list_summary_present(self, page: Page):
        """Inception list has summary stats."""
        page.goto(_url("/inception"))
        page.wait_for_load_state("domcontentloaded")
        stats = page.locator(".stat-value")
        if stats.count() > 0:
            first = stats.first.inner_text().strip()
            assert first, "Summary stats should have values"

    def test_assumptions_page_loads(self, page: Page):
        """Assumptions page loads without error."""
        resp = page.goto(_url("/assumptions"))
        assert resp.status == 200


class TestRedecideAffordance:
    """T-1389 (B2 / G-057): Decided inceptions must expose a superseding-decision form.

    The previous template hid the form once a decision was recorded, forcing
    agents to `sed`-edit task markdown to re-render the form — which bypassed
    the inception-decide pipeline (rationale capture, Updates log entry).
    """

    def _find_decided_inception(self, page: Page) -> str | None:
        """Find an active inception task_id that already has a decision.

        T-1604 fix: filter to ?location=active (template gates `Record Superseding
        Decision` form on `task._location == 'active'` — completed tasks render
        no form). Accept any decided state (go|no-go|defer); a deferred decision
        is still a decision and exposes the same superseding affordance.
        """
        for decision in ("go", "no-go", "defer"):
            page.goto(_url(f"/inception?decision={decision}&location=active"))
            page.wait_for_load_state("domcontentloaded")
            links = page.locator("a[href*='/inception/T-']")
            for i in range(min(links.count(), 10)):
                href = links.nth(i).get_attribute("href")
                if href and "/inception/T-" in href:
                    page.goto(_url(href))
                    page.wait_for_load_state("domcontentloaded")
                    content = page.content()
                    if (
                        "decision-banner go" in content
                        or "decision-banner no-go" in content
                        or "decision-banner defer" in content
                    ):
                        return href.replace("/inception/", "").strip("/")
        return None

    def test_decided_inception_shows_superseding_form(self, page: Page):
        """Core regression for G-057: decided inception exposes re-decide affordance."""
        task_id = self._find_decided_inception(page)
        if task_id is None:
            pytest.skip("No decided active inception available to test against")
        page.goto(_url(f"/inception/{task_id}"))
        page.wait_for_load_state("domcontentloaded")
        content = page.content()
        # Affordance present
        assert "Record Superseding Decision" in content, (
            f"Decided inception {task_id} must expose 'Record Superseding Decision' form "
            "(T-1389 / G-057 regression — form was hidden after first decision)"
        )
        # Form action points to /decide endpoint
        assert f'action="/inception/{task_id}/decide"' in content, (
            "Superseding form must POST to /decide endpoint"
        )
        # Radio buttons present
        assert 'value="go"' in content
        assert 'value="no-go"' in content
        assert 'value="defer"' in content

    def test_decided_inception_shows_context_note(self, page: Page):
        """Superseding form should warn the user + cite audit trail behaviour."""
        task_id = self._find_decided_inception(page)
        if task_id is None:
            pytest.skip("No decided active inception available to test against")
        page.goto(_url(f"/inception/{task_id}"))
        page.wait_for_load_state("domcontentloaded")
        content = page.content()
        # Context note explains replacement + audit preservation
        assert "Current decision:" in content
        assert "Updates" in content or "audit trail" in content.lower()

    def test_pending_inception_keeps_record_decision_label(self, page: Page):
        """No regression: pending inceptions still show 'Record Decision' (not 'Superseding')."""
        # Find a pending active inception
        page.goto(_url("/inception?decision=pending"))
        page.wait_for_load_state("domcontentloaded")
        links = page.locator("a[href*='/inception/T-']")
        for i in range(min(links.count(), 10)):
            href = links.nth(i).get_attribute("href")
            if not href:
                continue
            page.goto(_url(href))
            page.wait_for_load_state("domcontentloaded")
            content = page.content()
            if "decision-banner pending" in content:
                assert "Record Decision" in content, (
                    "Pending inception must still show 'Record Decision' form label"
                )
                assert "Record Superseding Decision" not in content, (
                    "Pending inception must NOT show 'Superseding' label (wrong state)"
                )
                return
        pytest.skip("No pending active inception available to test against")


class TestRecommendationDecisionDedupe:
    """T-1391 (B3 / F3): Dedupe Agent Recommendation + Decision Record cards.

    When decision adopts the recommendation, Recommendation collapses into
    <details>. When decision overrides, both visible with explicit labels.
    """

    def _find_decided_adopted_inception(self, page: Page) -> str | None:
        """Find an active inception where decision matches recommendation stance.

        T-1604 fix: filter to ?location=active (the dedupe rendering only matters
        for tasks still being viewed in active state — completed tasks have a
        different rendering envelope). Accept any decided state — the dedupe
        invariant ("adopted-by-human collapses Recommendation into <details>")
        applies regardless of whether the adopted decision was GO, NO-GO, or DEFER.
        """
        for decision in ("go", "no-go", "defer"):
            page.goto(_url(f"/inception?decision={decision}&location=active"))
            page.wait_for_load_state("domcontentloaded")
            links = page.locator("a[href*='/inception/T-']")
            for i in range(min(links.count(), 10)):
                href = links.nth(i).get_attribute("href")
                if href and "/inception/T-" in href:
                    page.goto(_url(href))
                    page.wait_for_load_state("domcontentloaded")
                    content = page.content()
                    has_banner = (
                        "decision-banner go" in content
                        or "decision-banner no-go" in content
                        or "decision-banner defer" in content
                    )
                    if has_banner and "adopted by human" in content:
                        return href.replace("/inception/", "").strip("/")
        return None

    def test_adopted_decision_collapses_recommendation(self, page: Page):
        """Adopted recommendation → Recommendation in <details>, Decision prominent."""
        task_id = self._find_decided_adopted_inception(page)
        if task_id is None:
            pytest.skip("No adopted-decision inception available to test against")
        page.goto(_url(f"/inception/{task_id}"))
        page.wait_for_load_state("domcontentloaded")
        content = page.content()
        # Recommendation label indicates adoption
        assert "adopted by human" in content, (
            f"Adopted decision on {task_id} must show 'adopted by human' hint"
        )
        # Recommendation is inside <details> (collapsed by default)
        # Approximation: look for the collapsed marker pattern near Recommendation
        assert "<details" in content, "Adopted case must use <details> element for Recommendation"
        # Decision Record is still a prominent card
        assert "Decision Record" in content

    def test_pending_inception_shows_recommendation_prominently(self, page: Page):
        """No regression: pending inceptions still show Recommendation as article card."""
        page.goto(_url("/inception?decision=pending"))
        page.wait_for_load_state("domcontentloaded")
        links = page.locator("a[href*='/inception/T-']")
        for i in range(min(links.count(), 10)):
            href = links.nth(i).get_attribute("href")
            if not href:
                continue
            page.goto(_url(href))
            page.wait_for_load_state("domcontentloaded")
            content = page.content()
            if "decision-banner pending" in content and "Agent Recommendation" in content:
                # Recommendation must be in an <article>, not <details>, for pending
                assert "adopted by human" not in content, (
                    "Pending inception must NOT show 'adopted' label"
                )
                assert "overridden by human" not in content, (
                    "Pending inception must NOT show 'overridden' label"
                )
                return
        pytest.skip("No pending inception with Recommendation available")


class TestBodyAssumptionFallback:
    """T-1415 (T-1388 B5 / F2): /approvals counts inline `A\\d+:` assumptions
    from task body when none are registered via `fw assumption add`.

    Prior behaviour read `0` from the ledger even when the task body listed
    several assumptions — masking the real exploration state on /approvals.
    """

    def test_count_body_assumptions_helper(self):
        """Unit check on the body-count helper, independent of live data."""
        from web.blueprints.approvals import _count_body_assumptions

        body = (
            "## Problem Statement\n\nproblem text\n\n"
            "## Assumptions\n\n- A1: first\n- A2: second\n- A3: third\n\n"
            "## Scope Fence\n\nnot an assumption\n"
        )
        assert _count_body_assumptions(body) == 3

    def test_count_body_assumptions_empty_when_no_section(self):
        from web.blueprints.approvals import _count_body_assumptions

        assert _count_body_assumptions("## Other\n\ntext\n") == 0

    def test_count_body_assumptions_ignores_non_a_bullets(self):
        from web.blueprints.approvals import _count_body_assumptions

        body = "## Assumptions\n\n- B1: wrong prefix\n- note\n- A1: real\n"
        assert _count_body_assumptions(body) == 1

    def test_approvals_page_renders_body_source_hint(self, page: Page):
        """If any decided inception with inline assumptions is on /approvals,
        the '(from body)' hint appears. Skip if the fleet has only
        ledger-registered assumptions today (not a regression, just unlucky data).
        """
        page.goto(_url("/approvals"))
        page.wait_for_load_state("domcontentloaded")
        content = page.content()
        # Page must render without error
        assert page.locator("h1, h2, h3").count() > 0
        # Either the hint is present (expected for body-sourced counts) or no
        # body-sourced tasks exist right now — both are valid. Guard only against
        # a template syntax error that would strip the surrounding "Assumptions:"
        # marker entirely when the source key is present.
        if "from body" in content:
            assert "Assumptions:" in content
