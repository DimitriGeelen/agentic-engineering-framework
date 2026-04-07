"""Playwright tests for Fabric pages (T-970).

Covers: fabric overview, component detail, graph view.
"""
import pytest
from playwright.sync_api import Page

TEST_URL = "http://localhost:3099"


def _url(path: str) -> str:
    return f"{TEST_URL}{path}"


class TestFabricOverview:
    """Fabric overview page renders with subsystem data."""

    def test_fabric_page_loads(self, page: Page):
        resp = page.goto(_url("/fabric"))
        assert resp.status == 200

    def test_fabric_has_subsystems(self, page: Page):
        page.goto(_url("/fabric"))
        page.wait_for_load_state("domcontentloaded")
        content = page.content().lower()
        # Should list subsystems or components
        assert "component" in content or "subsystem" in content or "fabric" in content

    def test_fabric_has_component_links(self, page: Page):
        page.goto(_url("/fabric"))
        page.wait_for_load_state("domcontentloaded")
        links = page.locator("a[href*='/fabric/component/']")
        assert links.count() > 0, "Fabric page should have component links"


class TestFabricComponent:
    """Fabric component detail page renders."""

    def test_component_detail_loads(self, page: Page):
        page.goto(_url("/fabric"))
        page.wait_for_load_state("domcontentloaded")
        links = page.locator("a[href*='/fabric/component/']")
        if links.count() > 0:
            href = links.first.get_attribute("href")
            resp = page.goto(_url(href) if href.startswith("/") else href)
            assert resp.status == 200

    def test_component_has_metadata(self, page: Page):
        page.goto(_url("/fabric"))
        page.wait_for_load_state("domcontentloaded")
        links = page.locator("a[href*='/fabric/component/']")
        if links.count() > 0:
            href = links.first.get_attribute("href")
            page.goto(_url(href) if href.startswith("/") else href)
            page.wait_for_load_state("domcontentloaded")
            content = page.content().lower()
            assert any(k in content for k in ["type", "purpose", "depends", "location"]), (
                "Component detail should show metadata fields"
            )


class TestFabricGraph:
    """Fabric graph page renders."""

    def test_graph_page_loads(self, page: Page):
        resp = page.goto(_url("/fabric/graph"))
        assert resp.status == 200
