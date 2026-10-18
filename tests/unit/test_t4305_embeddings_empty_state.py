"""T-4305: GET /embeddings on a freshly initialised project must render an
empty state, not HTTP 500.

Field report (greenfield container run, dimitri-mint-dev T-126): the page
returned 500. Root cause: when `web.embeddings` will not import, the
blueprint's `_index_state()` returned a partial dict with no `chunks` key.
The template's `index.chunks is not none` guard is true for Jinja's
Undefined, so `"{:,}".format(index.chunks)` raised
`TypeError: unsupported format string passed to Undefined.__format__`.

Pinned here:
  1. the import-failure path renders 200 (the field failure, reproduced by
     forcing the import to fail via sys.modules);
  2. the stack-present, no-index path renders 200 (control: it passed before
     the fix too, so the bug is the missing-stack shape, not the empty index);
  3. the unavailable state carries every key the template reads, as None,
     so "unknown" is an explicit None and never an Undefined.

Uses a synthetic PROJECT_ROOT with no vector index, like test_arc_membership_web_surfaces.py.
"""

import sys
import tempfile
from pathlib import Path

import pytest


@pytest.fixture
def empty_project(monkeypatch):
    """A fresh PROJECT_ROOT with the .context/working dir and no vector index."""
    root = Path(tempfile.mkdtemp(prefix="t4305-"))
    (root / ".context" / "working").mkdir(parents=True)
    (root / ".framework.yaml").write_text("project_name: t4305\n")
    monkeypatch.setenv("PROJECT_ROOT", str(root))
    monkeypatch.setenv("FW_SECRET_KEY", "t4305-test-key")
    return root


def _client():
    from web.app import create_app

    app = create_app()
    app.config["TESTING"] = True
    app.config["PROPAGATE_EXCEPTIONS"] = False
    return app.test_client()


def test_empty_state_renders_when_embeddings_stack_missing(empty_project, monkeypatch):
    """The field failure: web.embeddings not importable must not 500 the page."""
    # A None entry in sys.modules makes `from web.embeddings import ...` raise
    # ImportError — the same verdict a container without the stack gets.
    monkeypatch.setitem(sys.modules, "web.embeddings", None)

    resp = _client().get("/embeddings")

    assert resp.status_code == 200, resp.get_data(as_text=True)[:500]
    body = resp.get_data(as_text=True)
    assert "unknown" in body


def test_empty_state_renders_with_stack_present_and_no_index(empty_project):
    """Control: stack importable, no DB file. Renders 200 before and after the fix."""
    resp = _client().get("/embeddings")

    assert resp.status_code == 200, resp.get_data(as_text=True)[:500]


def test_unavailable_index_state_has_explicit_none_for_every_template_key(
    empty_project, monkeypatch
):
    """The template reads these keys; absent keys become Undefined, not None."""
    monkeypatch.setitem(sys.modules, "web.embeddings", None)
    from web.blueprints.embeddings import _index_state

    state = _index_state()

    assert state["available"] is False
    for key in ("chunks", "age_days", "age_seconds", "built_at", "freshness_source"):
        assert key in state, f"unavailable index state is missing {key!r}"
        assert state[key] is None, f"{key!r} must be an explicit None, not {state[key]!r}"
