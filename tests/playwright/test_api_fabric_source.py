"""Playwright tests for fabric file APIs (T-1025).

Tests /api/fabric/source and /api/fabric/report endpoints
from web/blueprints/fabric.py.
"""


class TestFabricSource:
    """Tests for /api/fabric/source/<path> endpoint."""

    def test_fabric_source_returns_content(self, page, base_url):
        """Source endpoint returns file content for a valid path."""
        resp = page.request.get(f"{base_url}/api/fabric/source/bin/fw")
        assert resp.status == 200
        body = resp.text()
        assert body.startswith("#!")

    def test_fabric_source_blocks_traversal(self, page, base_url):
        """Source endpoint blocks path traversal attempts."""
        resp = page.request.get(
            f"{base_url}/api/fabric/source/../../../etc/passwd"
        )
        # Flask URL normalization may return 404 before handler runs
        assert resp.status in (403, 404)

    def test_fabric_source_nonexistent(self, page, base_url):
        """Source endpoint returns 404 for missing files."""
        resp = page.request.get(
            f"{base_url}/api/fabric/source/nonexistent.xyz"
        )
        assert resp.status == 404


class TestFabricReport:
    """Tests for /api/fabric/report/<filename> endpoint."""

    def test_fabric_report_blocks_non_md(self, page, base_url):
        """Report endpoint rejects non-.md filenames."""
        resp = page.request.get(f"{base_url}/api/fabric/report/foo.txt")
        assert resp.status == 404
