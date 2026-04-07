"""Playwright smoke tests — all major routes render (T-969).

Verifies that key Watchtower pages load with HTTP 200 and contain
expected content markers. This is the Tier 3 equivalent of
web/smoke_test.py (which uses Flask test client).
"""
import re

import pytest
from playwright.sync_api import Page, expect

# Populated from conftest.py base_url fixture
TEST_URL = "http://localhost:3099"


def _url(path: str) -> str:
    return f"{TEST_URL}{path}"


class TestHomepage:
    """Landing page renders with core elements."""

    def test_homepage_loads(self, page: Page):
        page.goto(_url("/"))
        expect(page).to_have_title(re.compile("Watchtower", re.IGNORECASE))

    def test_homepage_has_nav(self, page: Page):
        page.goto(_url("/"))
        nav = page.locator("nav, .nav, .sidebar, aside")
        assert nav.count() > 0, "Navigation element should exist"

    def test_homepage_no_errors(self, page: Page):
        errors = []
        page.on("pageerror", lambda err: errors.append(str(err)))
        page.goto(_url("/"))
        page.wait_for_load_state("domcontentloaded")
        # Filter out favicon 404 — cosmetic, not a real error
        real_errors = [e for e in errors if "favicon" not in e.lower()]
        assert len(real_errors) == 0, f"JS errors on homepage: {real_errors}"


class TestCorePages:
    """Core Watchtower pages load successfully."""

    @pytest.mark.parametrize(
        "path,content_marker",
        [
            ("/tasks", "Tasks"),
            ("/fabric", "Fabric"),
            ("/inception", "Inception"),
            ("/timeline", "Timeline"),
            ("/config", "Config"),
            ("/health", "ok"),
        ],
    )
    def test_page_loads(self, page: Page, path: str, content_marker: str):
        resp = page.goto(_url(path))
        assert resp.status == 200, f"{path} returned {resp.status}"
        content = page.content()
        assert content_marker.lower() in content.lower(), (
            f"{path} missing content marker '{content_marker}'"
        )


class TestNavigation:
    """Direct URL navigation works for key pages."""

    def test_navigate_to_tasks(self, page: Page):
        page.goto(_url("/tasks"))
        page.wait_for_load_state("domcontentloaded")
        assert "Tasks" in page.content()

    def test_navigate_to_fabric(self, page: Page):
        page.goto(_url("/fabric"))
        page.wait_for_load_state("domcontentloaded")
        assert "Fabric" in page.content()

    def test_navigate_to_inception(self, page: Page):
        page.goto(_url("/inception"))
        page.wait_for_load_state("domcontentloaded")
        assert "Inception" in page.content()
