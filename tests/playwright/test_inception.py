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
