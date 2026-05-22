"""T-1764: Regression tests for the /file/<path> route.

Pre-T-1764 the route only served `.md` files under 4 directory prefixes,
while `_auto_link_files` (T-1722) auto-linked 7 extensions under 14
prefixes. Every non-md auto-linked path returned 404 — silently breaking
the T-1722 contract that "every Markdown surface gets one-click artefact
navigation."

Fix: single source of truth (`is_viewable_path` in web.shared) consulted
by both linker and route. These tests pin:
  - .md, .sh, .py, .yaml, .json, .toml, .bats all serve HTTP 200
  - path traversal still blocked (404)
  - directories outside the whitelist still 404
  - non-existent files still 404
  - linker-emitted anchors all resolve (no more drift)
"""
from __future__ import annotations

import re
import pytest

from web.app import app
from web.shared import _ARTEFACT_PATH_RE, is_viewable_path, VIEWABLE_DIR_PREFIXES, VIEWABLE_EXTENSIONS


@pytest.fixture
def client():
    app.config["TESTING"] = True
    with app.test_client() as c:
        yield c


# ---- Path predicate (unit) ------------------------------------------------

def test_is_viewable_path_accepts_md_under_tasks():
    assert is_viewable_path(".tasks/active/T-1762-foo.md")


def test_is_viewable_path_accepts_sh_under_lib():
    assert is_viewable_path("lib/task_pair_acd.sh")


def test_is_viewable_path_accepts_py_under_web():
    assert is_viewable_path("web/blueprints/tasks.py")


def test_is_viewable_path_accepts_yaml_under_fabric():
    assert is_viewable_path(".fabric/components/lib-task_pair_acd.yaml")


def test_is_viewable_path_rejects_traversal():
    assert not is_viewable_path("../../etc/passwd")
    assert not is_viewable_path("lib/../../../etc/passwd")
    assert not is_viewable_path("lib/..")


def test_is_viewable_path_rejects_unknown_dir():
    assert not is_viewable_path("etc/passwd")
    assert not is_viewable_path("/etc/passwd")
    assert not is_viewable_path("README.md")  # repo-root, not under any prefix


def test_is_viewable_path_rejects_unknown_extension():
    assert not is_viewable_path("lib/binary.exe")
    assert not is_viewable_path("lib/secrets.env")


def test_is_viewable_path_rejects_empty():
    assert not is_viewable_path("")


# ---- Live route (integration) --------------------------------------------

def test_route_serves_md_file(client):
    """The original capability — must still work post-T-1764.

    T-1997: glob an existing active task md instead of a hardcoded filename.
    Task files move active→completed, so a pinned path goes stale — the original
    T-1762-… file moved to completed/ and 404'd this test. Glob from the stable
    real-repo path (parents[2]) NOT web.shared.PROJECT_ROOT: the route serves via
    core.py's import-bound PROJECT_ROOT (= real repo, core isn't reloaded), while
    the live web.shared.PROJECT_ROOT can be left dangling at a tmp dir by prior
    reload-based tests (would make this glob find nothing → silent skip).
    """
    from pathlib import Path
    repo = Path(__file__).resolve().parents[2]
    md = next(iter(sorted((repo / ".tasks" / "active").glob("T-*.md"))), None)
    assert md is not None, "no active task md available to serve"
    rel = md.relative_to(repo)
    r = client.get(f"/file/{rel}")
    assert r.status_code == 200, f"Expected 200 for {rel}, got {r.status_code}"


def test_route_serves_shell_file(client):
    """T-1764 fix — shell scripts under lib/ now render."""
    r = client.get("/file/lib/task_pair_acd.sh")
    assert r.status_code == 200, f"Expected 200, got {r.status_code}"


def test_route_serves_python_file(client):
    """T-1764 fix — python sources under lib/ now render."""
    r = client.get("/file/lib/task_pair_acd.py")
    assert r.status_code == 200, f"Expected 200, got {r.status_code}"


def test_route_serves_bats_file(client):
    """T-1764 fix — bats tests under tests/ now render."""
    r = client.get("/file/tests/unit/test_task_pair_acd_gate.bats")
    assert r.status_code == 200, f"Expected 200, got {r.status_code}"


def test_route_serves_yaml_fabric_card(client):
    """T-1764 fix — fabric cards now render."""
    r = client.get("/file/.fabric/components/lib-task_pair_acd.yaml")
    assert r.status_code == 200, f"Expected 200, got {r.status_code}"


def test_route_blocks_traversal(client):
    r = client.get("/file/../../etc/passwd")
    assert r.status_code == 404


def test_route_blocks_outside_whitelist(client):
    r = client.get("/file/etc/passwd")
    assert r.status_code == 404


def test_route_blocks_unknown_extension(client):
    r = client.get("/file/lib/binary.exe")
    assert r.status_code == 404


def test_route_blocks_nonexistent_file(client):
    r = client.get("/file/lib/this_file_does_not_exist_anywhere.py")
    assert r.status_code == 404


# ---- Linker → route contract (the actual T-1764 prevention) --------------

def test_every_linker_dir_is_viewable():
    """Every directory the linker recognizes must pass `is_viewable_path`
    when paired with a viewable extension. If this drifts, T-1764 recurs."""
    for d in VIEWABLE_DIR_PREFIXES:
        for e in VIEWABLE_EXTENSIONS:
            sample = f"{d}sample.{e}"
            assert is_viewable_path(sample), (
                f"Linker dir {d!r} + ext {e!r} not viewable — drift"
            )


def test_artefact_path_re_matches_viewable_paths():
    """The auto-link regex must match exactly the paths the route serves.
    Same set membership in both directions."""
    samples = [
        "lib/task_pair_acd.sh",
        "lib/task_pair_acd.py",
        ".fabric/components/lib-task_pair_acd.yaml",
        "tests/unit/test_task_pair_acd_gate.bats",
        ".tasks/active/T-1762-foo.md",
    ]
    for s in samples:
        # Linker sees it
        assert _ARTEFACT_PATH_RE.search(s), f"Linker missed viewable path: {s}"
        # Route accepts it
        assert is_viewable_path(s), f"Route rejected linker-matched path: {s}"


def test_no_double_link_after_existing_anchor():
    """Idempotence guard from T-1722 still holds."""
    from web.shared import _auto_link_files

    already_linked = '<a href="/file/lib/task_pair_acd.sh">lib/task_pair_acd.sh</a>'
    out = _auto_link_files(already_linked)
    # Should be exactly one anchor — not nested
    assert out.count("<a ") == 1, f"Double-anchored: {out!r}"
