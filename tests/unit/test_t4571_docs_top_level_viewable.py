"""T-4571: top-level docs/ files are served by /file/.

GET /file/docs/style-guide.md answered 404 "Not Served" although the file is
tracked and present: is_viewable_path only accepted listed docs/<subdir>/
prefixes, so no depth-1 docs file could ever match. These tests pin the
depth-1 allowance and that it does not widen to unlisted docs subdirs.
"""
from __future__ import annotations

import pytest

from web.app import app
from web.blueprints.docs import PROJECT_ROOT as ROUTE_ROOT
from web.shared import is_viewable_path


@pytest.fixture
def client():
    app.config["TESTING"] = True
    with app.test_client() as c:
        yield c


def test_top_level_docs_file_is_viewable():
    assert is_viewable_path("docs/style-guide.md")
    assert is_viewable_path("docs/context-compaction.md")


def test_depth_one_allowance_does_not_widen():
    assert not is_viewable_path("docs/archive/issues-archived.yaml")
    assert not is_viewable_path("docs/screenshot.png")      # extension still checked
    assert not is_viewable_path("docs/../etc/passwd.md")
    assert not is_viewable_path("docs/")


def test_route_serves_style_guide(client):
    if not (ROUTE_ROOT / "docs" / "style-guide.md").is_file():
        pytest.skip("docs/style-guide.md not in this checkout")
    resp = client.get("/file/docs/style-guide.md")
    body = resp.get_data(as_text=True)
    assert resp.status_code == 200
    assert "not served by the file viewer" not in body
    assert "Style Guide" in body
