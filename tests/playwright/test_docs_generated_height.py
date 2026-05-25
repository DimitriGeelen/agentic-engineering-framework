"""Playwright regression test for /docs/generated rendered height (T-2047).

The component-reference index rendered ~34,671px tall: it loops over 31 subsystems, each
an `<details open>` wrapping a per-subsystem table (765 component rows total), so every
row rendered at once (9th instance of the unbounded-page class, surfaced by the T-2042
exhaustive probe). T-2047 collapses the subsystem sections by default (page = a scannable
index of 31 sections) and wraps each table in a max-height scroll container with a sticky
header, so the default page is short, every row stays in the DOM (reached by expanding a
section), and even the largest expanded section (246 rows) stays bounded. These tests guard
against the height bomb returning.
"""

# Mirror agents/ux-review/ux-review.py TALL_PAGE_CAP_PX.
HEIGHT_CAP_PX = 8000


class TestDocsGeneratedHeight:
    def test_docs_generated_height_bounded(self, page, base_url):
        """Default scrollHeight stays under the cap regardless of component count."""
        page.goto(f"{base_url}/docs/generated")
        page.wait_for_load_state("domcontentloaded")
        page.wait_for_timeout(500)
        height = page.evaluate("document.documentElement.scrollHeight")
        assert height < HEIGHT_CAP_PX, (
            f"/docs/generated scrollHeight {height}px exceeds {HEIGHT_CAP_PX}px cap — "
            "subsystem sections are expanded/unbounded again (T-2047 regression)"
        )

    def test_docs_generated_all_rows_in_dom(self, page, base_url):
        """Every component row stays in the DOM (collapsed, not removed)."""
        page.goto(f"{base_url}/docs/generated")
        page.wait_for_load_state("domcontentloaded")
        page.wait_for_timeout(500)
        rows = page.evaluate("document.querySelectorAll('table tbody tr').length")
        details = page.evaluate("document.querySelectorAll('details').length")
        assert details > 0, "no subsystem <details> sections found (T-2047 regression)"
        assert rows > details, (
            f"expected many component rows in DOM, found {rows} across {details} sections "
            "— rows were dropped, not collapsed (T-2047 regression)"
        )

    def test_docs_generated_sections_collapsed_with_scroll(self, page, base_url):
        """Sections are collapsed by default and wrapped in a scroll container."""
        page.goto(f"{base_url}/docs/generated")
        page.wait_for_load_state("domcontentloaded")
        page.wait_for_timeout(500)
        open_count = page.evaluate("document.querySelectorAll('details[open]').length")
        assert open_count == 0, (
            f"{open_count} subsystem sections are open by default — should be collapsed (T-2047 regression)"
        )
        containers = page.evaluate("document.querySelectorAll('.docs-subsystem-scroll').length")
        assert containers > 0, ".docs-subsystem-scroll container missing (T-2047 regression)"
