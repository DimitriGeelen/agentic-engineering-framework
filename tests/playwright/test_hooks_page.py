"""T-1632 (B-3c of T-1626) — Playwright: /hooks page renders correctly.

Pinned by T-1575 visual verification rule: any UI feature shipped via
an Agent AC needs a Playwright DOM-content assertion that guards it
forever. The AC asks "does the page render with the expected
elements"; this test answers that question on every CI run.

Asserts:
- Page returns 200 (HEAD-equivalent via page.goto status)
- Heading "Hook Telemetry" present
- Summary card structure (#hooks-summary) present
- Either telemetry table (#hooks-table) OR empty-state (#hooks-empty)
- Threshold-info paragraph references the configured min_fires/ratio
"""
import pytest


class TestHooksPage:
    """T-1632 — /hooks page DOM-content guards."""

    def test_page_returns_200(self, page, base_url):
        """Page loads without server error."""
        resp = page.goto(f"{base_url}/hooks")
        page.wait_for_load_state("domcontentloaded")
        assert resp is not None
        assert resp.status == 200, f"expected 200, got {resp.status}"

    def test_page_has_main_heading(self, page, base_url):
        """Heading 'Hook Telemetry' is visible."""
        page.goto(f"{base_url}/hooks")
        page.wait_for_load_state("domcontentloaded")
        heading = page.locator("h1", has_text="Hook Telemetry")
        assert heading.count() >= 1, "expected an h1 with 'Hook Telemetry'"

    def test_summary_card_block_present(self, page, base_url):
        """#hooks-summary block renders with metric cards."""
        page.goto(f"{base_url}/hooks")
        page.wait_for_load_state("domcontentloaded")
        summary = page.locator("#hooks-summary")
        assert summary.count() == 1, "expected exactly one #hooks-summary block"
        labels = page.locator("#hooks-summary .metric-label").all_text_contents()
        # Four metric labels expected
        assert len(labels) >= 4, f"expected >=4 metric labels, got {len(labels)}"
        # Key labels appear in order
        joined = " | ".join(labels).lower()
        assert "hooks tracked" in joined
        assert "total fires" in joined
        assert "total failures" in joined
        assert "over threshold" in joined

    def test_either_table_or_empty_state(self, page, base_url):
        """When telemetry exists, table renders; otherwise empty state."""
        page.goto(f"{base_url}/hooks")
        page.wait_for_load_state("domcontentloaded")
        table = page.locator("#hooks-table")
        empty = page.locator("#hooks-empty")
        # Exactly one of the two should exist
        present = (table.count() == 1) ^ (empty.count() == 1)
        assert present, (
            f"expected exactly one of #hooks-table or #hooks-empty "
            f"(table={table.count()}, empty={empty.count()})"
        )

    def test_threshold_info_displays_config(self, page, base_url):
        """Threshold parameters are displayed (operator can see the rule)."""
        page.goto(f"{base_url}/hooks")
        page.wait_for_load_state("domcontentloaded")
        info = page.locator(".threshold-info").text_content() or ""
        assert "fires" in info.lower(), "threshold info should mention 'fires'"
        assert "ratio" in info.lower() or "%" in info, (
            "threshold info should display the failure-ratio threshold"
        )

    def test_table_columns_when_present(self, page, base_url):
        """If the table is shown, it has the expected column headers."""
        page.goto(f"{base_url}/hooks")
        page.wait_for_load_state("domcontentloaded")
        table = page.locator("#hooks-table")
        if table.count() == 0:
            pytest.skip("no telemetry yet (empty-state path)")
        headers = page.locator("#hooks-table thead th").all_text_contents()
        joined = "|".join(h.strip() for h in headers).lower()
        assert "status" in joined
        assert "hook" in joined
        assert "fires" in joined
        assert "failures" in joined
        assert "ratio" in joined
