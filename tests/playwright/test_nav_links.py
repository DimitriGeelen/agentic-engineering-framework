"""Playwright tests for navigation link validation (T-1057).

Verifies all navigation bar links point to valid pages (200 status).
Guards against broken nav links from route renames or removals.
"""


class TestNavLinks:
    """All navigation links should resolve to 200."""

    def test_nav_links_are_valid(self, page, base_url):
        """Every internal nav link returns 200."""
        page.goto(f"{base_url}/")
        page.wait_for_load_state("domcontentloaded")

        # Collect all nav links (typically in <nav> or header)
        nav_links = page.locator("nav a[href]")
        count = nav_links.count()
        assert count > 5, f"Expected nav to have 5+ links, found {count}"

        broken = []
        for i in range(count):
            href = nav_links.nth(i).get_attribute("href")
            if not href or href.startswith("#") or href.startswith("javascript:"):
                continue
            # Make absolute
            if href.startswith("/"):
                url = f"{base_url}{href}"
            elif href.startswith("http"):
                continue  # Skip external links
            else:
                url = f"{base_url}/{href}"

            resp = page.request.get(url)
            if resp.status not in (200, 308):
                broken.append(f"{href} -> {resp.status}")

        assert not broken, f"Broken nav links: {broken}"

    def test_nav_has_key_pages(self, page, base_url):
        """Nav bar includes links to key framework pages."""
        page.goto(f"{base_url}/")
        page.wait_for_load_state("domcontentloaded")

        nav_html = page.locator("nav").inner_html()
        key_pages = ["/tasks", "/fabric", "/timeline"]
        for path in key_pages:
            assert path in nav_html, f"Nav missing link to {path}"

    def test_footer_links_valid(self, page, base_url):
        """Footer links (if any) are valid."""
        page.goto(f"{base_url}/")
        page.wait_for_load_state("domcontentloaded")

        footer_links = page.locator("footer a[href]")
        count = footer_links.count()
        if count == 0:
            return  # No footer links

        broken = []
        for i in range(count):
            href = footer_links.nth(i).get_attribute("href")
            if not href or href.startswith("#") or href.startswith("http"):
                continue
            url = f"{base_url}{href}" if href.startswith("/") else f"{base_url}/{href}"
            resp = page.request.get(url)
            if resp.status not in (200, 308):
                broken.append(f"{href} -> {resp.status}")

        assert not broken, f"Broken footer links: {broken}"
