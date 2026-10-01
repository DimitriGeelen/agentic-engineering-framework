"""T-3649 — render_markdown_safe(extras=...) and docs/arcs/ viewability.

Port of 055-agentic-fleet-cockpit's link fix (framework:pickup offset 236,
P-005 correction to 235; their T-344). A caller that needs tables must be able
to keep the link pipeline (T-XXX refs, T-1722 artefact paths) rather than
calling markdown2 directly, and the arc-dossier location must be servable.
"""

import os
from pathlib import Path

import pytest

_REPO = Path(__file__).resolve().parents[2]
os.environ.setdefault("PROJECT_ROOT", str(_REPO))

from web import shared as _shared  # noqa: E402


@pytest.fixture(autouse=True)
def _pin_project_root():
    # Same cross-file reload hazard as test_render_artefact_paths.py (T-1995).
    _shared.PROJECT_ROOT = _REPO
    yield


_EXISTING = "tests/unit/test_render_artefact_paths.py"
_TABLE = (
    "| Task | File |\n"
    "|------|------|\n"
    f"| T-3642 | {_EXISTING} |\n"
)


def test_extras_tables_renders_table_and_keeps_links():
    html = _shared.render_markdown_safe(_TABLE, extras=["tables"])
    assert "<table" in html
    assert 'href="/tasks/T-3642"' in html
    assert f'/file/{_EXISTING}' in html


def test_default_output_unchanged():
    assert _shared.render_markdown_safe(_TABLE) == _shared.render_markdown_safe(_TABLE, extras=None)
    assert "<table" not in _shared.render_markdown_safe(_TABLE)


def test_extras_still_escapes_raw_html():
    html = _shared.render_markdown_safe("<script>x</script>", extras=["tables"])
    assert "<script>" not in html


def test_docs_arcs_is_viewable():
    assert _shared.is_viewable_path("docs/arcs/arc-001/README.md")
    assert not _shared.is_viewable_path("docs/arcs/../../etc/passwd.md")
