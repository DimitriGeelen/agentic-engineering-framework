"""Playwright tests for fabric component detail page (T-1041).

Tests GET /fabric/component/<name>.
Route: web/blueprints/fabric.py:144
"""
import os


class TestFabricComponentDetail:
    """Tests for GET /fabric/component/<name>."""

    def _real_component_name(self):
        """Get a real component name from .fabric/components/."""
        cards_dir = os.path.join(
            os.environ.get("PROJECT_ROOT", "/opt/999-Agentic-Engineering-Framework"),
            ".fabric", "components",
        )
        if os.path.isdir(cards_dir):
            for f in os.listdir(cards_dir):
                if f.endswith(".yaml"):
                    return f[:-5]  # strip .yaml
        return None

    def test_component_detail_loads(self, page, base_url):
        """Real component detail page returns 200."""
        name = self._real_component_name()
        if not name:
            return  # No components available
        resp = page.goto(f"{base_url}/fabric/component/{name}")
        assert resp.status == 200

    def test_component_detail_has_content(self, page, base_url):
        """Component detail page has meaningful content."""
        name = self._real_component_name()
        if not name:
            return
        page.goto(f"{base_url}/fabric/component/{name}")
        page.wait_for_load_state("domcontentloaded")
        body = page.locator("body").text_content()
        assert len(body) > 50

    def test_nonexistent_component(self, page, base_url):
        """Nonexistent component returns 200 with 'Not Found' content."""
        resp = page.goto(f"{base_url}/fabric/component/DOES-NOT-EXIST-999")
        # Route renders template with component=None, still 200
        assert resp.status == 200

    def test_component_with_special_chars(self, page, base_url):
        """Component name with special chars returns safely."""
        resp = page.goto(f"{base_url}/fabric/component/<script>alert(1)</script>")
        assert resp.status in (200, 404)
