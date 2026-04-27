"""T-1535: Playwright tests for the agent recommendation verdict UI.

Covers the surfaces shipped in T-1530 → T-1534:
- /approvals card verdict badges (T-1531)
- /approvals filter buttons GO/DEFER (T-1532)
- Landing-page Action Required verdict pills (T-1533)

These tests guard the human review-workflow improvements: if the verdict
extraction or the template rendering regresses, the human will lose the
at-a-glance triage signal — these assertions fail-fast.
"""
from playwright.sync_api import Page

TEST_URL = "http://localhost:3099"


def _url(path: str) -> str:
    return f"{TEST_URL}{path}"


class TestApprovalsVerdictBadges:
    """Each pending-AC card renders a coloured verdict badge."""

    def test_approvals_page_loads(self, page: Page):
        resp = page.goto(_url("/approvals"))
        assert resp.status == 200

    def test_verdict_badges_render(self, page: Page):
        """At least one card carries a data-verdict attribute (badge or wrapper)."""
        page.goto(_url("/approvals"))
        page.wait_for_load_state("domcontentloaded")
        content = page.content()
        # data-verdict appears on both the wrapper div and the badge span
        assert 'data-verdict="GO"' in content or \
               'data-verdict="DEFER"' in content or \
               'data-verdict="NO-GO"' in content or \
               'data-verdict="?"' in content, \
               "Approvals cards should carry data-verdict attributes"

    def test_verdict_badge_class_present(self, page: Page):
        """If pending_acs has any tasks, verdict-badge spans must render."""
        page.goto(_url("/approvals"))
        page.wait_for_load_state("domcontentloaded")
        cards = page.locator(".human-ac-group")
        if cards.count() > 0:
            badges = page.locator(".verdict-badge")
            assert badges.count() > 0, \
                "Cards exist but no .verdict-badge spans rendered"


class TestApprovalsFilterButtons:
    """T-1532: GO/DEFER/NO-GO filter buttons render alongside existing filters."""

    def test_all_filter_button_present(self, page: Page):
        page.goto(_url("/approvals"))
        page.wait_for_load_state("domcontentloaded")
        all_btn = page.locator('[data-filter="all"]')
        # 'All' button is unconditional
        assert all_btn.count() >= 1

    def test_verdict_filter_buttons_render_when_data_exists(self, page: Page):
        """GO/DEFER buttons render iff at least one task carries that verdict."""
        page.goto(_url("/approvals"))
        page.wait_for_load_state("domcontentloaded")
        content = page.content()
        # If any GO card exists, GO filter button MUST render.
        if 'data-verdict="GO"' in content:
            assert 'data-filter="go"' in content, \
                "GO cards present but GO filter button missing"
        if 'data-verdict="DEFER"' in content:
            assert 'data-filter="defer"' in content, \
                "DEFER cards present but DEFER filter button missing"

    def test_filter_js_handles_verdict_values(self, page: Page):
        """The filterACs() JS must include the GO/DEFER/NO-GO branches."""
        page.goto(_url("/approvals"))
        page.wait_for_load_state("domcontentloaded")
        content = page.content()
        assert "filter === 'go'" in content
        assert "filter === 'defer'" in content


class TestLandingPageVerdictPills:
    """T-1533: Action Required widget shows per-verdict count pills."""

    def test_landing_page_loads(self, page: Page):
        resp = page.goto(_url("/"))
        assert resp.status == 200

    def test_verdict_pills_render_when_data_exists(self, page: Page):
        """If there are GO or DEFER tasks, the corresponding pill must render."""
        page.goto(_url("/"))
        page.wait_for_load_state("domcontentloaded")
        content = page.content()
        # Cross-check: if /approvals has GO cards, the landing pill should too
        approvals = page.context.new_page()
        approvals.goto(_url("/approvals"))
        approvals.wait_for_load_state("domcontentloaded")
        approvals_html = approvals.content()
        if 'data-verdict="GO"' in approvals_html:
            assert 'data-verdict-pill="GO"' in content, \
                "GO tasks exist on /approvals but no GO pill on landing page"
        if 'data-verdict="DEFER"' in approvals_html:
            assert 'data-verdict-pill="DEFER"' in content, \
                "DEFER tasks exist on /approvals but no DEFER pill on landing page"
        approvals.close()

    def test_verdict_pill_has_count_text(self, page: Page):
        """If any verdict pill renders, it carries a numeric count + label."""
        page.goto(_url("/"))
        page.wait_for_load_state("domcontentloaded")
        pills = page.locator(".verdict-pill")
        if pills.count() > 0:
            first = pills.first.inner_text().strip()
            # Format: "<N> GO" / "<N> DEFER" / "<N> NO-GO"
            parts = first.split()
            assert len(parts) >= 2, f"Unexpected pill text: {first!r}"
            assert parts[0].isdigit(), f"First token should be a count: {first!r}"
            assert parts[1] in ("GO", "DEFER", "NO-GO"), \
                f"Second token should be a verdict label: {first!r}"
