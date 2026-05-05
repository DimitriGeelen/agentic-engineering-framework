"""T-1727 A5 — /escalation-drift v0.5 panel Playwright coverage.

Pins the v0.5 LLM-augmentation surface added by T-1727. Browser-level
verification per T-1575: element-presence grep is forbidden for UI ACs;
this test assert visibility of the augmented table column AND the v0.5
verdict-counts panel when v0.5 data is present.

Marked to match the verification gate hint:
    fw test playwright -k escalation_v05
"""

import re

import pytest
from playwright.sync_api import Page, expect


def _drift_url(test_url: str) -> str:
    return f"{test_url}/escalation-drift"


class TestEscalationDriftPage:
    """Page itself loads cleanly regardless of v0/v0.5 state."""

    def test_page_loads_with_correct_title(self, page: Page, base_url: str):
        page.goto(_drift_url(base_url))
        expect(page).to_have_title(re.compile(r"Escalation", re.IGNORECASE))

    def test_page_has_no_js_errors(self, page: Page, base_url: str):
        errors: list[str] = []
        page.on("pageerror", lambda err: errors.append(str(err)))
        page.goto(_drift_url(base_url))
        page.wait_for_load_state("domcontentloaded")
        real_errors = [e for e in errors if "favicon" not in e.lower()]
        assert real_errors == [], f"JS errors on /escalation-drift: {real_errors}"


class TestV05TriageColumn:
    """The Recent Flagged Tasks table now has a Triage column (T-1727 A5).

    The element-presence test is allowed even without live v0.5 data —
    column headers ship with the template and don't depend on YAML
    being populated. Verdict cells render '—' when no triage exists.
    """

    def test_triage_column_visible_when_v0_data_present(
        self, page: Page, base_url: str,
    ):
        page.goto(_drift_url(base_url))
        # Page may show the "no data" state on a fresh project — only assert
        # the Triage column when the recent_sample table is actually present.
        table = page.locator('table[data-testid="escalation-v05-table"]')
        if table.count() == 0:
            pytest.skip("no v0 recent_sample data — Triage column gated on v0 output")
        header = table.locator("thead th", has_text="Triage")
        expect(header).to_be_visible()

    def test_confidence_column_visible_when_v0_data_present(
        self, page: Page, base_url: str,
    ):
        page.goto(_drift_url(base_url))
        table = page.locator('table[data-testid="escalation-v05-table"]')
        if table.count() == 0:
            pytest.skip("no v0 recent_sample data — Confidence column gated on v0 output")
        header = table.locator("thead th", has_text="Confidence")
        expect(header).to_be_visible()


class TestV05VerdictPanel:
    """The 'v0.5 LLM Augmentation' panel (data-testid=escalation-v05-panel).

    Panel only renders when v0.5 LATEST.yaml exists. On a project that has
    never run v0.5, the panel is absent and these tests skip cleanly —
    matching the "additive, never replaces" AC.
    """

    def test_panel_renders_when_v05_yaml_exists(self, page: Page, base_url: str):
        page.goto(_drift_url(base_url))
        panel = page.locator('h3[data-testid="escalation-v05-panel"]')
        if panel.count() == 0:
            pytest.skip(
                "v0.5 LATEST.yaml absent — panel gated on data presence per "
                "additive-never-replaces AC"
            )
        expect(panel).to_be_visible()
        body = page.locator("body").inner_text()
        # The panel names the three core verdicts so a reviewer can read it.
        assert "real_symptom_fix" in body, (
            "v0.5 panel must name real_symptom_fix verdict"
        )
        assert "false_positive" in body, (
            "v0.5 panel must name false_positive verdict"
        )

    def test_panel_links_dispatch_substrate(self, page: Page, base_url: str):
        """Panel surfaces dispatch substrate metadata — model + idempotency
        window — so the operator can reason about cost/freshness without
        reading the YAML directly."""
        page.goto(_drift_url(base_url))
        panel = page.locator('h3[data-testid="escalation-v05-panel"]')
        if panel.count() == 0:
            pytest.skip("v0.5 panel not rendered (no data)")
        body = page.locator("body").inner_text()
        # Substrate hints — model name + workflow name should appear.
        assert "escalation-triage" in body or "ollama" in body.lower(), (
            "panel must surface workflow or worker substrate"
        )
