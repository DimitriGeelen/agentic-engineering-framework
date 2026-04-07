"""Playwright tests for docs generated page coverage (T-1054).

Verifies the /docs/generated page lists all expected component docs,
including all Playwright test file documentation.
"""


class TestDocsGenerated:
    """Tests for /docs/generated page content."""

    def test_docs_page_has_minimum_entries(self, page, base_url):
        """Docs page lists at least 60 Playwright test docs."""
        page.goto(f"{base_url}/docs/generated")
        page.wait_for_load_state("domcontentloaded")
        body = page.content()
        # Count links to tests-playwright docs
        import re
        pw_links = re.findall(r"tests-playwright-test_", body)
        assert len(pw_links) >= 60, (
            f"Expected 60+ Playwright test doc links, found {len(pw_links)}"
        )

    def test_docs_page_has_total_components(self, page, base_url):
        """Docs page lists substantial component docs (not just tests)."""
        page.goto(f"{base_url}/docs/generated")
        page.wait_for_load_state("domcontentloaded")
        # Should have links to component docs
        links = page.locator("a[href*='/docs/generated/']")
        count = links.count()
        assert count >= 80, f"Expected 80+ component doc links, found {count}"
