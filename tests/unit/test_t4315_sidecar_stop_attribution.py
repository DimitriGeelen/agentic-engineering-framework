"""T-4315: every sidecar stop request names its caller.

WATCHER_STOPPED is written by the watcher itself, which never learns who sent
the SIGTERM; three explicit stops of the real watcher on 2026-10-18 could not
be attributed until a bisect found the test responsible. stop_all() and
stop_processes() now record STOP_REQUESTED with the caller's pid, ppid, argv,
PROJECT_ROOT, cwd and (under a test runner) the test's name.
"""
import os
import sys
from pathlib import Path

import pytest

FW_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(FW_ROOT))

from lib.sidecar import watcher  # noqa: E402


@pytest.fixture
def proj(tmp_path, monkeypatch):
    root = tmp_path / "t4315"
    (root / ".context").mkdir(parents=True)
    (root / ".framework.yaml").write_text("project_name: t4315\n", encoding="utf-8")
    monkeypatch.setenv("PROJECT_ROOT", str(root))
    monkeypatch.setenv("FW_SIDECAR_ENABLED_DIR", str(tmp_path / "enabled"))
    monkeypatch.setenv("FW_SIDECAR_REGISTRY_DIR", str(tmp_path / "registry"))
    return root


def _requests():
    return [e for e in watcher.read_events() if e.get("event") == "STOP_REQUESTED"]


def test_explicit_stop_records_who_asked(proj):
    watcher.stop_all(timeout=1)
    rows = _requests()
    assert len(rows) == 1, rows
    row = rows[0]
    assert row["reason"] == "explicit stop"
    assert row["caller_pid"] == os.getpid()
    assert row["caller_ppid"] == os.getppid()
    assert row["caller_project_root"] == str(proj)
    assert row["caller_cwd"] == os.getcwd()
    assert row["caller_argv"] == " ".join(sys.argv)[:500]
    assert "test_explicit_stop_records_who_asked" in row["caller_test"]
    assert watcher.stopped_marker().exists()


def test_restart_is_recorded_as_a_restart_not_an_explicit_stop(proj):
    watcher.stop_processes(timeout=1)
    rows = _requests()
    assert [r["reason"] for r in rows] == ["restart"]
    assert not watcher.stopped_marker().exists()
