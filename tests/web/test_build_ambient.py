"""Regression: build_ambient must read focus.yaml::current_task (T-1308)."""

import sys
from pathlib import Path

import pytest

FRAMEWORK_ROOT = Path(__file__).resolve().parents[2]
if str(FRAMEWORK_ROOT) not in sys.path:
    sys.path.insert(0, str(FRAMEWORK_ROOT))


def _prepare_project(tmp_path: Path, focus_task: str | None) -> Path:
    """Scaffold minimal project layout with two active tasks and optional focus.yaml."""
    active = tmp_path / ".tasks" / "active"
    active.mkdir(parents=True)
    # T-0100 sorts first alphabetically; T-0999 would not.
    (active / "T-0100-first-alpha.md").write_text("---\nid: T-0100\n---\n")
    (active / "T-0999-real-focus.md").write_text("---\nid: T-0999\n---\n")
    working = tmp_path / ".context" / "working"
    working.mkdir(parents=True)
    if focus_task is not None:
        (working / "focus.yaml").write_text(f"current_task: {focus_task}\n")
    return tmp_path


def _reimport_shared(project_root: Path, monkeypatch):
    import importlib
    monkeypatch.setenv("PROJECT_ROOT", str(project_root))
    import web.shared as s  # noqa: E402
    importlib.reload(s)
    return s


def test_focus_yaml_wins_over_alphabetical_first(tmp_path, monkeypatch):
    project = _prepare_project(tmp_path, focus_task="T-0999")
    shared = _reimport_shared(project, monkeypatch)
    ambient = shared.build_ambient()
    assert ambient["focus_task"] == "T-0999"
    assert ambient["attention_count"] == 2


def test_null_focus_falls_back_to_first_alphabetical(tmp_path, monkeypatch):
    project = _prepare_project(tmp_path, focus_task="null")  # YAML literal null
    shared = _reimport_shared(project, monkeypatch)
    ambient = shared.build_ambient()
    assert ambient["focus_task"] == "T-0100"


def test_missing_focus_yaml_falls_back(tmp_path, monkeypatch):
    project = _prepare_project(tmp_path, focus_task=None)  # no file
    shared = _reimport_shared(project, monkeypatch)
    ambient = shared.build_ambient()
    assert ambient["focus_task"] == "T-0100"


def test_malformed_focus_value_is_ignored(tmp_path, monkeypatch):
    project = _prepare_project(tmp_path, focus_task="not-a-task-id")
    shared = _reimport_shared(project, monkeypatch)
    ambient = shared.build_ambient()
    # malformed current_task → fall back
    assert ambient["focus_task"] == "T-0100"
