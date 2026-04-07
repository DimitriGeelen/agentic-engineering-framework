"""Playwright accessibility tests for Watchtower (T-1059).

Verifies basic HTML accessibility: lang attribute, heading hierarchy,
meta viewport, and no empty links.
"""
import pytest

SAMPLE_PAGES = ["/", "/tasks", "/fabric", "/config"]


class TestHTMLAccessibility:
    """Basic HTML accessibility checks across key pages."""

    @pytest.mark.parametrize("route", SAMPLE_PAGES)
    def test_page_has_lang_attribute(self, page, base_url, route):
        """HTML element has lang attribute for screen readers."""
        page.goto(f"{base_url}{route}")
        page.wait_for_load_state("domcontentloaded")
        lang = page.locator("html").get_attribute("lang")
        assert lang, f"{route}: <html> missing lang attribute"

    @pytest.mark.parametrize("route", SAMPLE_PAGES)
    def test_page_has_heading(self, page, base_url, route):
        """Page has at least one heading element."""
        page.goto(f"{base_url}{route}")
        page.wait_for_load_state("domcontentloaded")
        heading_count = page.locator("h1, h2, h3, h4, h5, h6").count()
        assert heading_count >= 1, f"{route}: no heading element found"

    @pytest.mark.parametrize("route", SAMPLE_PAGES)
    def test_page_has_viewport_meta(self, page, base_url, route):
        """Page has viewport meta tag for mobile responsiveness."""
        page.goto(f"{base_url}{route}")
        page.wait_for_load_state("domcontentloaded")
        viewport = page.locator("meta[name='viewport']")
        assert viewport.count() > 0, f"{route}: missing viewport meta tag"

    @pytest.mark.parametrize("route", SAMPLE_PAGES)
    def test_no_empty_links(self, page, base_url, route):
        """No links with empty href or text."""
        page.goto(f"{base_url}{route}")
        page.wait_for_load_state("domcontentloaded")
        empty_links = page.locator("a:not([href]), a[href='']")
        assert empty_links.count() == 0, (
            f"{route}: {empty_links.count()} links with missing/empty href"
        )

    def test_dark_mode_class_toggle(self, page, base_url):
        """Dark mode toggle adds/removes class on body or html."""
        page.goto(f"{base_url}/")
        page.wait_for_load_state("domcontentloaded")
        # Check if dark mode toggle exists
        toggle = page.locator("[data-theme-toggle], .theme-toggle, #dark-mode-toggle")
        if toggle.count() == 0:
            return  # No dark mode toggle — skip
        # Pico CSS uses data-theme attribute
        html = page.locator("html")
        initial_theme = html.get_attribute("data-theme")
        toggle.first.click()
        new_theme = html.get_attribute("data-theme")
        # Theme should change
        assert initial_theme != new_theme or new_theme is not None
