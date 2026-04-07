"""Playwright tests for /file/<path> viewer endpoint (T-1025).

Covers: markdown rendering, path traversal blocking, non-markdown blocking,
nonexistent file handling.
"""
from playwright.sync_api import Page

TEST_URL = "http://localhost:3099"


def _url(path: str) -> str:
    return f"{TEST_URL}{path}"


class TestFileViewer:
    """The /file/<path> endpoint serves markdown from safe directories."""

    def test_file_viewer_loads_markdown(self, page: Page):
        """A valid markdown file under docs/ should render with 200."""
        resp = page.goto(_url("/file/docs/style-guide.md"))
        assert resp.status == 200

    def test_file_viewer_blocks_traversal(self, page: Page):
        """Path traversal with .. should be blocked with 404."""
        resp = page.goto(_url("/file/../../../etc/passwd"))
        assert resp.status == 404

    def test_file_viewer_blocks_non_markdown(self, page: Page):
        """Non-markdown files should be blocked with 404."""
        resp = page.goto(_url("/file/bin/fw"))
        assert resp.status == 404

    def test_file_viewer_nonexistent(self, page: Page):
        """A nonexistent markdown file should return 404."""
        resp = page.goto(_url("/file/docs/nonexistent-xyz.md"))
        assert resp.status == 404
