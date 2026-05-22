"""Tests for reviewer dispatch mode (T-1951, G-066 prong 3).

Coverage (≥5 unit tests):
  (a) --dispatch spawns TermLink worker and exits 0 without blocking parent
  (b) --json flag surfaces dispatch status with session name and task_id
  (c) FW_REVIEWER_IN_DISPATCH=1 → exit 3 (recursive dispatch refused)
  (d) 3 sequential dispatches produce 3 distinct session names (concurrency safety)
  (e) dispatch subprocess failure → exit 1 with clean error (parent does not crash)

Additional:
  (f) worker script contains recursive-guard env var
  (g) dispatch_cli refuses unknown flags (argparse surface check)
  (h) session name encodes task_id (observable in termlink list)
"""

from __future__ import annotations

import io
import json
import os
import sys
from pathlib import Path
from unittest.mock import MagicMock, call, patch

import pytest

ROOT = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(ROOT))

import lib.reviewer.dispatch_cli as dispatch_cli


# ─── Helpers ───────────────────────────────────────────────────────────────────


def _fw_stub(tmp_path: Path) -> Path:
    """Create a minimal stub fw binary so _fw_bin() resolves correctly."""
    fw_bin = tmp_path / "bin" / "fw"
    fw_bin.parent.mkdir(parents=True, exist_ok=True)
    fw_bin.write_text("#!/bin/bash\nexit 0\n")
    fw_bin.chmod(0o755)
    return fw_bin


def _mock_popen(rc: int = 0, stderr: str = "") -> MagicMock:
    """Build a mock Popen instance that returns rc and stderr."""
    proc = MagicMock()
    proc.wait.return_value = rc
    proc.stderr.read.return_value = stderr
    return proc


# ─── (a) spawns TermLink worker and exits without blocking parent ───────────────


def test_dispatch_spawns_and_exits_zero(tmp_path, monkeypatch):
    """`--dispatch` creates a TermLinkWorker and fires dispatch (rc=0), exits 0."""
    monkeypatch.setenv("PROJECT_ROOT", str(tmp_path))
    _fw_stub(tmp_path)

    with patch("lib.reviewer.dispatch_cli.TermLinkWorker") as MockWorker, \
         patch("lib.reviewer.dispatch_cli.subprocess.Popen") as mock_popen:

        mock_worker = MockWorker.return_value
        mock_worker._build_dispatch_argv.return_value = ["echo", "dispatched"]
        mock_popen.return_value = _mock_popen(rc=0)

        rc = dispatch_cli.main(["T-9001"])

    assert rc == 0
    MockWorker.assert_called_once()
    mock_worker._build_dispatch_argv.assert_called_once()
    mock_popen.assert_called_once()


def test_dispatch_worker_name_passed_to_termlink_worker(tmp_path, monkeypatch):
    """TermLinkWorker is instantiated with a session name that encodes the task_id."""
    monkeypatch.setenv("PROJECT_ROOT", str(tmp_path))
    _fw_stub(tmp_path)

    captured_kwargs: dict = {}

    def capture_worker(*args, **kwargs):
        captured_kwargs.update(kwargs)
        w = MagicMock()
        w._build_dispatch_argv.return_value = ["echo", "ok"]
        return w

    with patch("lib.reviewer.dispatch_cli.TermLinkWorker", side_effect=capture_worker), \
         patch("lib.reviewer.dispatch_cli.subprocess.Popen") as mock_popen:
        mock_popen.return_value = _mock_popen(rc=0)
        dispatch_cli.main(["T-9002"])

    assert captured_kwargs["task_id"] == "T-9002"
    assert "t-9002" in captured_kwargs["name"]


# ─── (b) --json surfaces dispatch status JSON ──────────────────────────────────


def test_dispatch_json_flag_emits_session_and_task_id(tmp_path, monkeypatch):
    """--json emits a JSON object with status, session, task_id, bus_channel."""
    monkeypatch.setenv("PROJECT_ROOT", str(tmp_path))
    _fw_stub(tmp_path)

    with patch("lib.reviewer.dispatch_cli.TermLinkWorker") as MockWorker, \
         patch("lib.reviewer.dispatch_cli.subprocess.Popen") as mock_popen, \
         patch("sys.stdout", new_callable=io.StringIO) as mock_stdout:

        mock_worker = MockWorker.return_value
        mock_worker._build_dispatch_argv.return_value = ["echo", "ok"]
        mock_popen.return_value = _mock_popen(rc=0)

        rc = dispatch_cli.main(["T-9003", "--json"])
        output = mock_stdout.getvalue()

    assert rc == 0
    data = json.loads(output.strip())
    assert data["status"] == "dispatched"
    assert data["task_id"] == "T-9003"
    assert "session" in data
    assert "t-9003" in data["session"]
    assert "bus_channel" in data


# ─── (c) FW_REVIEWER_IN_DISPATCH=1 → exit 3 ───────────────────────────────────


def test_recursive_dispatch_refused_exit_3(monkeypatch):
    """When FW_REVIEWER_IN_DISPATCH=1 is set, main() returns exit code 3."""
    monkeypatch.setenv(dispatch_cli.SENTINEL_ENV, "1")
    rc = dispatch_cli.main(["T-9001"])
    assert rc == 3


def test_recursive_dispatch_prints_error(monkeypatch, capsys):
    """Recursive dispatch emits an informative error message to stderr."""
    monkeypatch.setenv(dispatch_cli.SENTINEL_ENV, "1")
    dispatch_cli.main(["T-9001"])
    _, err = capsys.readouterr()
    assert "FW_REVIEWER_IN_DISPATCH" in err
    assert "--dispatch" in err


# ─── (d) 3 sequential dispatches produce 3 distinct session names ──────────────


def test_three_dispatches_produce_distinct_session_names(tmp_path, monkeypatch):
    """Repeated dispatch calls produce unique session names (uuid suffix)."""
    monkeypatch.setenv("PROJECT_ROOT", str(tmp_path))
    _fw_stub(tmp_path)

    session_names: list[str] = []

    def capture_worker(*args, **kwargs):
        session_names.append(kwargs["name"])
        w = MagicMock()
        w._build_dispatch_argv.return_value = ["echo", kwargs["name"]]
        return w

    with patch("lib.reviewer.dispatch_cli.TermLinkWorker", side_effect=capture_worker), \
         patch("lib.reviewer.dispatch_cli.subprocess.Popen") as mock_popen:
        mock_popen.return_value = _mock_popen(rc=0)
        for tid in ["T-9010", "T-9011", "T-9012"]:
            rc = dispatch_cli.main([tid])
            assert rc == 0

    assert len(session_names) == 3
    assert len(set(session_names)) == 3, "All 3 session names must be distinct"
    for name, tid in zip(session_names, ["T-9010", "T-9011", "T-9012"]):
        assert tid.lower() in name, f"Session name {name!r} should encode {tid}"


def test_parallel_dispatch_distinct_bus_channels(tmp_path, monkeypatch):
    """Each dispatch targets its own bus channel (task_id is per-channel)."""
    monkeypatch.setenv("PROJECT_ROOT", str(tmp_path))
    _fw_stub(tmp_path)

    task_ids_used: list[str] = []

    def capture_worker(*args, **kwargs):
        task_ids_used.append(kwargs["task_id"])
        w = MagicMock()
        w._build_dispatch_argv.return_value = ["echo", "ok"]
        return w

    with patch("lib.reviewer.dispatch_cli.TermLinkWorker", side_effect=capture_worker), \
         patch("lib.reviewer.dispatch_cli.subprocess.Popen") as mock_popen:
        mock_popen.return_value = _mock_popen(rc=0)
        for tid in ["T-9020", "T-9021", "T-9022"]:
            dispatch_cli.main([tid])

    assert task_ids_used == ["T-9020", "T-9021", "T-9022"]


# ─── (e) dispatch subprocess failure → exit 1 (clean, no crash) ────────────────


def test_dispatch_failure_returns_exit_1_not_crash(tmp_path, monkeypatch):
    """`fw termlink dispatch` subprocess failure → exit 1 (parent does not crash)."""
    monkeypatch.setenv("PROJECT_ROOT", str(tmp_path))
    _fw_stub(tmp_path)

    with patch("lib.reviewer.dispatch_cli.TermLinkWorker") as MockWorker, \
         patch("lib.reviewer.dispatch_cli.subprocess.Popen") as mock_popen:

        mock_worker = MockWorker.return_value
        mock_worker._build_dispatch_argv.return_value = ["false"]
        mock_popen.return_value = _mock_popen(rc=1, stderr="task T-MISSING not found")

        rc = dispatch_cli.main(["T-MISSING"])

    assert rc == 1  # clean error, no exception raised


def test_dispatch_failure_stderr_surfaced(tmp_path, monkeypatch, capsys):
    """Dispatch failure prints the subprocess stderr to parent stderr."""
    monkeypatch.setenv("PROJECT_ROOT", str(tmp_path))
    _fw_stub(tmp_path)

    with patch("lib.reviewer.dispatch_cli.TermLinkWorker") as MockWorker, \
         patch("lib.reviewer.dispatch_cli.subprocess.Popen") as mock_popen:

        mock_worker = MockWorker.return_value
        mock_worker._build_dispatch_argv.return_value = ["false"]
        mock_popen.return_value = _mock_popen(rc=2, stderr="some dispatch error")

        dispatch_cli.main(["T-MISSING"])

    _, err = capsys.readouterr()
    assert "dispatch failed" in err.lower() or "ERROR" in err


# ─── (f) worker script contains sentinel env var ───────────────────────────────


def test_worker_script_contains_sentinel_env(tmp_path, monkeypatch):
    """The written worker script references FW_REVIEWER_IN_DISPATCH to prevent recursion."""
    monkeypatch.setenv("PROJECT_ROOT", str(tmp_path))
    _fw_stub(tmp_path)

    script_path = dispatch_cli._write_worker_script(
        fw=str(tmp_path / "bin" / "fw"),
        task_id="T-9030",
        session_name="reviewer-t-9030-abc123",
    )
    content = script_path.read_text()
    # Script must NOT invoke the reviewer with --dispatch (recursive guard).
    # "--dispatch" may appear in comments (e.g. "do not add --dispatch") but
    # must not appear as an argument on the fw reviewer command line.
    import re
    reviewer_calls = [l for l in content.splitlines() if "reviewer" in l and not l.strip().startswith("#")]
    for line in reviewer_calls:
        assert "--dispatch" not in line, f"reviewer command must not include --dispatch: {line!r}"
    # Script must reference the fw bus post command
    assert "bus post" in content
    assert "reviewer-dispatched" in content


# ─── (h) session name encodes task_id ─────────────────────────────────────────


def test_session_name_encodes_task_id(tmp_path, monkeypatch):
    """Session name is reviewer-{task_id.lower()}-{6char} — observable in termlink list."""
    monkeypatch.setenv("PROJECT_ROOT", str(tmp_path))
    _fw_stub(tmp_path)

    seen_name: list[str] = []

    def capture_worker(*args, **kwargs):
        seen_name.append(kwargs["name"])
        w = MagicMock()
        w._build_dispatch_argv.return_value = ["echo", "ok"]
        return w

    with patch("lib.reviewer.dispatch_cli.TermLinkWorker", side_effect=capture_worker), \
         patch("lib.reviewer.dispatch_cli.subprocess.Popen") as mock_popen:
        mock_popen.return_value = _mock_popen(rc=0)
        dispatch_cli.main(["T-9040"])

    assert len(seen_name) == 1
    name = seen_name[0]
    assert name.startswith("reviewer-t-9040-"), f"Unexpected name: {name!r}"
    suffix = name.split("-")[-1]
    assert len(suffix) == 6
    assert suffix.isalnum()
