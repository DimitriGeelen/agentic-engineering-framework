"""T-2228 (T-2225 Slice 3): production-tool skip-list for T-Test-NNN sentinels.

Tests the `is_test_sentinel()` helper and its application at the `web/shared.py`
glob sites. Defense-in-depth verification: if a real `.tasks/active/T-Test-001.md`
ever leaks into PROJECT_ROOT (Slice 1 `tmp_project_root` helper bypassed), the
production scanners must filter it out instead of presenting it as a real task.

Layer-3 invariants exercised:
  - `is_test_sentinel("T-Test-001")` → True
  - `is_test_sentinel("T-Test-foo.md")` → True
  - `is_test_sentinel("T-Test-bar.yaml")` → True
  - `is_test_sentinel("T-2228")` → False (real task id)
  - `is_test_sentinel("T-2228-some-slug.md")` → False (real task file)
  - `is_test_sentinel(Path("/abs/path/.tasks/active/T-Test-001.md"))` → True
  - `get_all_task_metadata()` skips a leaked `T-Test-001.md` in active/
  - `get_episodic_tags()` skips a leaked `T-Test-001.yaml` in .context/episodic/
"""
from __future__ import annotations

from pathlib import Path

import pytest


def test_helper_matches_string_sentinel():
    """`is_test_sentinel` recognises bare T-Test- strings."""
    from web.shared import is_test_sentinel
    assert is_test_sentinel("T-Test-001") is True
    assert is_test_sentinel("T-Test-foo.md") is True
    assert is_test_sentinel("T-Test-bar.yaml") is True
    assert is_test_sentinel("T-Test-001-some-slug.md") is True


def test_helper_rejects_real_task_id():
    """`is_test_sentinel` does NOT match numeric T-NNNN ids."""
    from web.shared import is_test_sentinel
    assert is_test_sentinel("T-2228") is False
    assert is_test_sentinel("T-2228-some-slug.md") is False
    assert is_test_sentinel("T-001") is False
    assert is_test_sentinel("T-9999.yaml") is False
    # Edge: numeric id with letter 'T' continuation in slug — still not sentinel
    assert is_test_sentinel("T-2228-test-something.md") is False


def test_helper_handles_path_inputs():
    """`is_test_sentinel` accepts Path / PosixPath inputs."""
    from web.shared import is_test_sentinel
    assert is_test_sentinel(Path(".tasks/active/T-Test-001.md")) is True
    assert is_test_sentinel(Path("/abs/path/to/.tasks/active/T-Test-001.md")) is True
    assert is_test_sentinel(Path(".tasks/active/T-2228.md")) is False


def test_helper_handles_non_string_gracefully():
    """`is_test_sentinel` returns False on weird inputs, doesn't crash."""
    from web.shared import is_test_sentinel
    assert is_test_sentinel("") is False
    assert is_test_sentinel("not-a-task-id") is False


def test_get_all_task_metadata_skips_leaked_sentinel(tmp_path, monkeypatch):
    """T-2228 AC: a leaked `.tasks/active/T-Test-001.md` is invisible to
    `web/shared.get_all_task_metadata()`.

    Uses the T-2226 tmp_project_root pattern: monkeypatch PROJECT_ROOT in BOTH
    web.shared and web.blueprints.tasks, invalidate the cache, then create a
    leaked sentinel + one real task, then verify only the real task is returned.
    """
    # Setup tmp tasks dir
    active = tmp_path / ".tasks" / "active"
    active.mkdir(parents=True)

    # Real task
    (active / "T-2228-real.md").write_text(
        "---\nid: T-2228\nname: Real task\nstatus: started-work\nworkflow_type: build\n---\nbody\n"
    )
    # Leaked test sentinel
    (active / "T-Test-001-leaked.md").write_text(
        "---\nid: T-Test-001\nname: Leaked sentinel\nstatus: started-work\nworkflow_type: build\n---\nbody\n"
    )

    # Patch PROJECT_ROOT + invalidate cache (T-1239 dual-patch + T-2226 pattern)
    monkeypatch.setattr("web.shared.PROJECT_ROOT", tmp_path)
    from web.shared import _task_cache, get_all_task_metadata
    _task_cache["data"] = None
    _task_cache["ts"] = 0

    tasks = get_all_task_metadata()
    ids = {t.get("id") for t in tasks}
    assert "T-2228" in ids, "Real task must be included"
    assert "T-Test-001" not in ids, "Leaked sentinel must be filtered"


def test_get_episodic_tags_skips_leaked_sentinel(tmp_path, monkeypatch):
    """T-2228 AC: a leaked `.context/episodic/T-Test-001.yaml` is invisible to
    `web/shared.get_episodic_tags()`.
    """
    episodic = tmp_path / ".context" / "episodic"
    episodic.mkdir(parents=True)

    # Real episodic
    (episodic / "T-2228.yaml").write_text(
        "task_id: T-2228\ntags:\n  - real\n"
    )
    # Leaked sentinel
    (episodic / "T-Test-001.yaml").write_text(
        "task_id: T-Test-001\ntags:\n  - leaked\n"
    )

    monkeypatch.setattr("web.shared.PROJECT_ROOT", tmp_path)
    from web.shared import _task_cache, get_episodic_tags
    _task_cache["tags"] = None
    _task_cache["ts"] = 0

    tags = get_episodic_tags()
    assert "T-2228" in tags, "Real episodic must be included"
    assert "T-Test-001" not in tags, "Leaked sentinel episodic must be filtered"
