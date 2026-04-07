"""Playwright tests for Discovery pages — learnings, decisions, gaps (T-986).

Covers: learnings page, decisions page, gaps page, each loads with content.
"""
from playwright.sync_api import Page

TEST_URL = "http://localhost:3099"


def _url(path: str) -> str:
    return f"{TEST_URL}{path}"


class TestLearningsPage:
    """Learnings page renders with content."""

    def test_learnings_page_loads(self, page: Page):
        resp = page.goto(_url("/learnings"))
        assert resp.status == 200

    def test_learnings_has_heading(self, page: Page):
        page.goto(_url("/learnings"))
        page.wait_for_load_state("domcontentloaded")
        heading = page.locator("h1")
        assert heading.count() > 0
        assert "Learnings" in heading.first.text_content()

    def test_learnings_has_content(self, page: Page):
        """Learnings page should display learning entries."""
        page.goto(_url("/learnings"))
        page.wait_for_load_state("domcontentloaded")
        content = page.content().lower()
        # Should have at least some learning references (L-XXX or task refs)
        assert "l-" in content or "learning" in content


class TestDecisionsPage:
    """Decisions page renders with content."""

    def test_decisions_page_loads(self, page: Page):
        resp = page.goto(_url("/decisions"))
        assert resp.status == 200

    def test_decisions_has_heading(self, page: Page):
        page.goto(_url("/decisions"))
        page.wait_for_load_state("domcontentloaded")
        heading = page.locator("h1")
        assert heading.count() > 0
        assert "Decisions" in heading.first.text_content()

    def test_decisions_has_content(self, page: Page):
        """Decisions page should display decision entries."""
        page.goto(_url("/decisions"))
        page.wait_for_load_state("domcontentloaded")
        content = page.content().lower()
        assert "decision" in content


class TestGapsPage:
    """Gaps page renders with content."""

    def test_gaps_page_loads(self, page: Page):
        resp = page.goto(_url("/gaps"))
        assert resp.status == 200

    def test_gaps_has_heading(self, page: Page):
        page.goto(_url("/gaps"))
        page.wait_for_load_state("domcontentloaded")
        heading = page.locator("h1")
        assert heading.count() > 0
        assert "Gaps" in heading.first.text_content()

    def test_gaps_has_content(self, page: Page):
        """Gaps page should display gap/concern entries."""
        page.goto(_url("/gaps"))
        page.wait_for_load_state("domcontentloaded")
        content = page.content().lower()
        assert "gap" in content or "concern" in content


class TestLearningsAPI:
    """Learnings API returns structured data (T-1023)."""

    def test_learnings_api_returns_json(self, page: Page):
        import json
        page.goto(_url("/api/learnings"))
        text = page.locator("body").text_content()
        data = json.loads(text)
        assert "learnings" in data
        assert "total" in data

    def test_learnings_api_has_items(self, page: Page):
        import json
        page.goto(_url("/api/learnings"))
        text = page.locator("body").text_content()
        data = json.loads(text)
        assert data["total"] > 0


class TestDecisionsAPI:
    """Decisions API returns structured data (T-1023)."""

    def test_decisions_api_returns_json(self, page: Page):
        import json
        page.goto(_url("/api/decisions"))
        text = page.locator("body").text_content()
        data = json.loads(text)
        assert "decisions" in data
        assert "total" in data

    def test_decisions_api_has_items(self, page: Page):
        import json
        page.goto(_url("/api/decisions"))
        text = page.locator("body").text_content()
        data = json.loads(text)
        assert data["total"] > 0
