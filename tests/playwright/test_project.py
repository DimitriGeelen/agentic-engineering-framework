"""Playwright tests for Project Documentation page (T-1019).

Covers: page loads, heading, document categories, doc detail page.
"""
from playwright.sync_api import Page

TEST_URL = "http://localhost:3099"


def _url(path: str) -> str:
    return f"{TEST_URL}{path}"


class TestProjectPage:
    """Project documentation page renders with document categories."""

    def test_project_page_loads(self, page: Page):
        resp = page.goto(_url("/project"))
        assert resp.status == 200

    def test_project_has_heading(self, page: Page):
        page.goto(_url("/project"))
        page.wait_for_load_state("domcontentloaded")
        heading = page.locator("h1")
        assert heading.count() > 0
        assert "Project" in heading.first.text_content() or "Documentation" in heading.first.text_content()

    def test_project_has_categories(self, page: Page):
        """Project page should show document categories."""
        page.goto(_url("/project"))
        page.wait_for_load_state("domcontentloaded")
        content = page.content()
        assert "Governance" in content or "Design" in content or "Agents" in content

    def test_project_has_document_links(self, page: Page):
        """Project page should have clickable document links."""
        page.goto(_url("/project"))
        page.wait_for_load_state("domcontentloaded")
        links = page.locator("a[href*='/project/']")
        assert links.count() > 0, "Project page should have document links"

    def test_project_doc_detail_loads(self, page: Page):
        """A specific project document should load."""
        resp = page.goto(_url("/project/FRAMEWORK"))
        assert resp.status == 200
        content = page.content()
        assert len(content) > 500
