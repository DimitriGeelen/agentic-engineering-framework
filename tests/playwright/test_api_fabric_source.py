"""Playwright tests for fabric file APIs (T-1025).

Tests /api/fabric/source and /api/fabric/report endpoints
from web/blueprints/fabric.py.
"""
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
SOURCE_LIMIT = 500_000   # web/blueprints/fabric.py: larger files answer 413


class TestFabricSource:
    """Tests for /api/fabric/source/<path> endpoint."""

    def test_fabric_source_returns_content(self, page, base_url):
        """Source endpoint returns file content for a valid path.

        T-5164: was bin/fw, which grew past the 500 KB limit (639,645 bytes) and so answered
        413. A small script keeps this test about serving content, not about bin/fw's size."""
        assert (ROOT / "bin/watchtower.sh").stat().st_size < SOURCE_LIMIT
        resp = page.request.get(f"{base_url}/api/fabric/source/bin/watchtower.sh")
        assert resp.status == 200
        body = resp.text()
        assert body.startswith("#!")

    def test_fabric_source_refuses_a_file_over_the_limit(self, page, base_url):
        """T-5164: the size limit itself answers 413."""
        big = next((p for p in [ROOT / "bin/fw", *sorted((ROOT / "web/static").rglob("*.png"))]
                    if p.is_file() and p.stat().st_size > SOURCE_LIMIT), None)
        if big is None:
            pytest.skip("no file over 500,000 bytes in bin/fw or web/static to ask for")
        resp = page.request.get(f"{base_url}/api/fabric/source/{big.relative_to(ROOT)}")
        assert resp.status == 413

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
