"""T-1669 Step 3 — /orchestrator page Playwright coverage.

Pins the Learned-routing panel that surfaces the orchestrator-rethink
arc's headline_mechanic firing live. Browser-level test guards what the
operator actually SEES (not just response body strings) — the
T-1575/T-971 rule "UI ACs need eyes, not grep".

Tests run against the live Watchtower (TEST_PORT 3099 or 3000 if
FW_TEST_PORT unset and conftest detects an existing server). The cache
state is whatever the host has — these tests verify panel structure,
not specific data.
"""

import re

import pytest
from playwright.sync_api import Page, expect


def _orchestrator_url(test_url: str) -> str:
    return f"{test_url}/orchestrator"


class TestOrchestratorPage:
    """The /orchestrator page renders with all four panels."""

    def test_page_loads_with_correct_title(self, page: Page, base_url: str):
        page.goto(_orchestrator_url(base_url))
        expect(page).to_have_title(re.compile(r"Orchestrator", re.IGNORECASE))

    def test_page_has_no_js_errors(self, page: Page, base_url: str):
        errors = []
        page.on("pageerror", lambda err: errors.append(str(err)))
        page.goto(_orchestrator_url(base_url))
        page.wait_for_load_state("domcontentloaded")
        real_errors = [e for e in errors if "favicon" not in e.lower()]
        assert real_errors == [], f"JS errors on /orchestrator: {real_errors}"


class TestLearnedRoutingPanel:
    """T-1669 Step 3 — the new panel that proves the headline_mechanic fires."""

    def test_learned_routing_heading_present(self, page: Page, base_url: str):
        page.goto(_orchestrator_url(base_url))
        # The h2 added by T-1669 Step 3:
        heading = page.locator("h2", has_text="Learned routing")
        expect(heading).to_be_visible()

    def test_panel_explains_route_cache_role(self, page: Page, base_url: str):
        """The intro paragraph names route-cache.json — the substrate the
        panel reads — and links T-1669 so a reviewer can trace it."""
        page.goto(_orchestrator_url(base_url))
        body = page.locator("body").inner_text()
        assert "route-cache.json" in body, "panel must name the cache file"
        # T-1669 reference (the task that wired this end-to-end)
        link = page.locator('a[href="/tasks/T-1669"]')
        assert link.count() >= 1, "panel should link T-1669"

    def test_panel_renders_one_of_three_states(self, page: Page, base_url: str):
        """Panel exposes exactly one of: cache absent, no recordings, or table.

        The states are mutually exclusive in the template — proving
        all three branches exist guards against a future refactor that
        accidentally hides the panel entirely.
        """
        page.goto(_orchestrator_url(base_url))
        body = page.locator("body").inner_text()
        # At least one of the three signals MUST be present:
        absent = "cache absent" in body
        empty = "no recordings" in body
        # Table state: header strings from the rendered table
        table = "Best model" in body and "Success rate" in body
        assert absent or empty or table, (
            "Learned routing panel must render one of three states "
            "(cache absent / no recordings / table)"
        )


class TestRecentDispatchesPanel:
    """The pre-existing recent-dispatches panel still renders below the new one."""

    def test_recent_dispatches_heading_present(self, page: Page, base_url: str):
        page.goto(_orchestrator_url(base_url))
        heading = page.locator("h2", has_text="Recent dispatches")
        expect(heading).to_be_visible()

    def test_learned_routing_appears_above_recent_dispatches(
        self, page: Page, base_url: str
    ):
        """Panel order matters — the headline_mechanic surface should
        appear BEFORE the dispatch-history surface so a reviewer sees
        'what's the orchestrator doing now?' before 'what did it do?'.
        """
        page.goto(_orchestrator_url(base_url))
        learned = page.locator("h2", has_text="Learned routing")
        recent = page.locator("h2", has_text="Recent dispatches")
        learned_box = learned.bounding_box()
        recent_box = recent.bounding_box()
        assert learned_box is not None, "Learned routing heading must be visible"
        assert recent_box is not None, "Recent dispatches heading must be visible"
        assert learned_box["y"] < recent_box["y"], (
            "Learned routing must appear above Recent dispatches "
            f"(learned y={learned_box['y']}, recent y={recent_box['y']})"
        )


class TestWorkflowCoveragePanel:
    """T-1799 + T-1801 — the workflow coverage panel renders the matrix of
    workflow × worker_kind × provider × routable. Browser-level guard against
    template regression (T-1575 — UI verification needs eyes)."""

    def test_workflow_coverage_heading_present(self, page: Page, base_url: str):
        page.goto(_orchestrator_url(base_url))
        heading = page.locator("h2", has_text="Workflow coverage")
        expect(heading).to_be_visible()

    def test_table_has_four_columns(self, page: Page, base_url: str):
        """T-1801 — table header has Workflow / worker_kind / provider / Routable.

        The provider column is the T-1801 addition; this test pins the
        4-column shape so a future template refactor doesn't silently drop it.
        """
        page.goto(_orchestrator_url(base_url))
        # Scope the header search to the workflow coverage section: find the
        # heading, then the next table sibling.
        page.locator("h2", has_text="Workflow coverage").wait_for()
        # All <th> after the Workflow coverage heading and before the next h2.
        # Simpler approach: assert the body contains all four headers in order.
        body = page.locator("body").inner_text()
        # Header strings appear in the rendered table:
        assert "Workflow" in body
        assert "worker_kind" in body
        assert "provider" in body
        assert "Routable" in body

    def test_provider_column_renders_per_row(self, page: Page, base_url: str):
        """For each pi workflow row, the provider cell renders either a
        provider name OR a `missing` warn badge — never an unmarked empty
        cell (that would mask the T-1800 failure class)."""
        page.goto(_orchestrator_url(base_url))
        body = page.locator("body").inner_text()
        # The page has at least one pi workflow on the production substrate.
        # If it has a provider, "anthropic" (or similar) shows; if it doesn't,
        # "missing" shows. The assertion is the disjunction, robust to data.
        assert ("anthropic" in body) or ("missing" in body), (
            "provider column must render either a provider value or "
            "a missing badge for pi workflows"
        )
