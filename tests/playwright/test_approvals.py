"""Playwright tests for Approvals page (T-981).

Covers: page loads, pending approvals listed, task references present.
"""
from playwright.sync_api import Page

TEST_URL = "http://localhost:3099"


def _url(path: str) -> str:
    return f"{TEST_URL}{path}"


class TestApprovalsPage:
    """Approvals page renders with pending human review items."""

    def test_approvals_page_loads(self, page: Page):
        resp = page.goto(_url("/approvals"))
        assert resp.status == 200

    def test_approvals_has_content(self, page: Page):
        page.goto(_url("/approvals"))
        page.wait_for_load_state("domcontentloaded")
        content = page.content()
        assert len(content) > 500, "Approvals page should have content"

    def test_approvals_has_task_references(self, page: Page):
        """Approvals page should show task references (T-XXX)."""
        page.goto(_url("/approvals"))
        page.wait_for_load_state("domcontentloaded")
        content = page.content()
        assert "T-" in content, "Approvals page should show task references"

    def test_approvals_has_heading(self, page: Page):
        page.goto(_url("/approvals"))
        page.wait_for_load_state("domcontentloaded")
        heading = page.locator("h1, h2")
        assert heading.count() > 0, "Approvals page should have a heading"

    def test_approvals_content_endpoint(self, page: Page):
        """Approvals content endpoint returns HTML fragment (T-1019)."""
        resp = page.goto(_url("/approvals/content"))
        assert resp.status == 200
        content = page.content()
        assert len(content) > 100

    def test_approvals_has_inception_section(self, page: Page):
        """Approvals should show inception decisions section (T-1019)."""
        page.goto(_url("/approvals"))
        page.wait_for_load_state("domcontentloaded")
        content = page.content().lower()
        assert "inception" in content

    def test_approvals_inception_cards_have_context(self, page: Page):
        """T-1214: Inception cards show recommendation OR fallback context — never bare."""
        page.goto(_url("/approvals"))
        page.wait_for_load_state("domcontentloaded")
        # Every go-decision card should have either recommendation or fallback
        cards = page.locator(".go-decision")
        if cards.count() > 0:
            for i in range(cards.count()):
                card = cards.nth(i)
                html = card.inner_html()
                has_recommendation = "Agent Recommendation" in html
                has_fallback = "No agent recommendation" in html
                assert has_recommendation or has_fallback, (
                    f"Inception card {i} has neither recommendation nor fallback context"
                )

    def test_approvals_content_returns_summary_bar(self, page: Page):
        """Content endpoint returns the summary counts bar for htmx polling."""
        resp = page.goto(_url("/approvals/content"))
        assert resp.status == 200
        content = page.content()
        assert "approvals-summary" in content or "stat-value" in content


class TestDecisionsVsVerificationsSplit:
    """T-1416 (T-1388 B6 / F5): /approvals groups strategic decisions
    separately from verification rubber-stamps so the former aren't
    buried under a long list of Human ACs."""

    def test_summary_bar_labels_decisions_and_verifications(self, page: Page):
        page.goto(_url("/approvals/content"))
        page.wait_for_load_state("domcontentloaded")
        content = page.content()
        assert 'class="stat-label">Decisions<' in content, (
            "Summary bar must group Tier 0 + GO counts under 'Decisions' (T-1416 B6)"
        )
        assert 'class="stat-label">Verifications<' in content, (
            "Summary bar must group Human ACs under 'Verifications' (T-1416 B6)"
        )

    def test_section_headings_present_when_items_exist(self, page: Page):
        """Group headings render anchor IDs (so summary bar cells can link).

        T-1604 fix: prior `if "<h2" in content and "Decisions" in content` guard
        was always true (summary-bar `<a>Decisions</a>` link contaminates substring
        matches; some other `<h2>` always exists). Use regex on the heading
        opening tag — the precise rendering envelope, not bare keywords.
        """
        import re

        page.goto(_url("/approvals/content"))
        page.wait_for_load_state("domcontentloaded")
        content = page.content()
        # Decisions group rendered → its <h2> heading must carry the anchor id
        if re.search(r"<h2[^>]*>\s*Decisions\s*</h2>", content):
            assert 'id="section-decisions"' in content
        # Verifications group rendered → its <h2> heading must carry the anchor id
        if re.search(r"<h2[^>]*>\s*Verifications\s*</h2>", content):
            assert 'id="section-verifications"' in content

    def test_summary_cells_are_anchor_links(self, page: Page):
        """Clicking a summary-bar cell jumps past the preceding section."""
        page.goto(_url("/approvals/content"))
        page.wait_for_load_state("domcontentloaded")
        content = page.content()
        # Anchors into page fragments exist
        assert 'href="#section-decisions"' in content
        assert 'href="#section-verifications"' in content
