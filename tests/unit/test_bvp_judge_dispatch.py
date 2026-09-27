"""Tests for lib/bvp_judge_dispatch_cli.py (T-3526, T-1951 shape reused).

Deliberate mirror of tests/unit/test_reviewer_dispatch.py's coverage — same
mechanism, different inline command. See that file's docstring for the
original rationale of each case.
"""

from __future__ import annotations

import io
import json
import sys
from pathlib import Path
from unittest.mock import MagicMock, patch

import pytest

ROOT = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(ROOT))

import lib.bvp_judge_dispatch_cli as dispatch_cli


def _fw_stub(tmp_path: Path) -> Path:
    fw_bin = tmp_path / "bin" / "fw"
    fw_bin.parent.mkdir(parents=True, exist_ok=True)
    fw_bin.write_text("#!/bin/bash\nexit 0\n")
    fw_bin.chmod(0o755)
    return fw_bin


def _mock_popen(rc: int = 0, stderr: str = "") -> MagicMock:
    proc = MagicMock()
    proc.wait.return_value = rc
    proc.stderr.read.return_value = stderr
    return proc


# ─── spawns worker, exits 0 without blocking parent ─────────────────────────


def test_dispatch_spawns_and_exits_zero(tmp_path, monkeypatch):
    monkeypatch.setenv("PROJECT_ROOT", str(tmp_path))
    _fw_stub(tmp_path)

    with patch("lib.bvp_judge_dispatch_cli.TermLinkWorker") as MockWorker, \
         patch("lib.bvp_judge_dispatch_cli.subprocess.Popen") as mock_popen:
        mock_worker = MockWorker.return_value
        mock_worker._build_dispatch_argv.return_value = ["echo", "dispatched"]
        mock_popen.return_value = _mock_popen(rc=0)

        rc = dispatch_cli.main(["T-9001"])

    assert rc == 0
    MockWorker.assert_called_once()
    mock_worker._build_dispatch_argv.assert_called_once()
    mock_popen.assert_called_once()


def test_dispatch_worker_name_encodes_task_id(tmp_path, monkeypatch):
    monkeypatch.setenv("PROJECT_ROOT", str(tmp_path))
    _fw_stub(tmp_path)

    captured_kwargs: dict = {}

    def capture_worker(*args, **kwargs):
        captured_kwargs.update(kwargs)
        w = MagicMock()
        w._build_dispatch_argv.return_value = ["echo", "ok"]
        return w

    with patch("lib.bvp_judge_dispatch_cli.TermLinkWorker", side_effect=capture_worker), \
         patch("lib.bvp_judge_dispatch_cli.subprocess.Popen") as mock_popen:
        mock_popen.return_value = _mock_popen(rc=0)
        dispatch_cli.main(["T-9002"])

    assert captured_kwargs["task_id"] == "T-9002"
    assert "t-9002" in captured_kwargs["name"]
    assert captured_kwargs["name"].startswith("bvp-judge-")


# ─── --json emits dispatch status ────────────────────────────────────────────


def test_dispatch_json_flag_emits_session_and_task_id(tmp_path, monkeypatch):
    monkeypatch.setenv("PROJECT_ROOT", str(tmp_path))
    _fw_stub(tmp_path)

    with patch("lib.bvp_judge_dispatch_cli.TermLinkWorker") as MockWorker, \
         patch("lib.bvp_judge_dispatch_cli.subprocess.Popen") as mock_popen, \
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
    assert "bus_channel" in data


# ─── recursive dispatch refused ──────────────────────────────────────────────


def test_recursive_dispatch_refused_exit_3(monkeypatch):
    monkeypatch.setenv(dispatch_cli.SENTINEL_ENV, "1")
    rc = dispatch_cli.main(["T-9001"])
    assert rc == 3


def test_recursive_dispatch_prints_error(monkeypatch, capsys):
    monkeypatch.setenv(dispatch_cli.SENTINEL_ENV, "1")
    dispatch_cli.main(["T-9001"])
    _, err = capsys.readouterr()
    assert dispatch_cli.SENTINEL_ENV in err
    assert "--dispatch" in err


# ─── distinct session names across repeated dispatches ──────────────────────


def test_three_dispatches_produce_distinct_session_names(tmp_path, monkeypatch):
    monkeypatch.setenv("PROJECT_ROOT", str(tmp_path))
    _fw_stub(tmp_path)

    session_names: list[str] = []

    def capture_worker(*args, **kwargs):
        session_names.append(kwargs["name"])
        w = MagicMock()
        w._build_dispatch_argv.return_value = ["echo", kwargs["name"]]
        return w

    with patch("lib.bvp_judge_dispatch_cli.TermLinkWorker", side_effect=capture_worker), \
         patch("lib.bvp_judge_dispatch_cli.subprocess.Popen") as mock_popen:
        mock_popen.return_value = _mock_popen(rc=0)
        for tid in ["T-9010", "T-9011", "T-9012"]:
            assert dispatch_cli.main([tid]) == 0

    assert len(set(session_names)) == 3


# ─── dispatch subprocess failure ─────────────────────────────────────────────


def test_dispatch_failure_returns_exit_1_not_crash(tmp_path, monkeypatch):
    monkeypatch.setenv("PROJECT_ROOT", str(tmp_path))
    _fw_stub(tmp_path)

    with patch("lib.bvp_judge_dispatch_cli.TermLinkWorker") as MockWorker, \
         patch("lib.bvp_judge_dispatch_cli.subprocess.Popen") as mock_popen:
        mock_worker = MockWorker.return_value
        mock_worker._build_dispatch_argv.return_value = ["false"]
        mock_popen.return_value = _mock_popen(rc=1, stderr="task T-MISSING not found")

        rc = dispatch_cli.main(["T-MISSING"])

    assert rc == 1


# ─── worker script shape ─────────────────────────────────────────────────────


def test_worker_script_never_adds_dispatch_flag_and_posts_to_bus(tmp_path, monkeypatch):
    monkeypatch.setenv("PROJECT_ROOT", str(tmp_path))
    _fw_stub(tmp_path)

    script_path = dispatch_cli._write_worker_script(
        fw=str(tmp_path / "bin" / "fw"),
        task_id="T-9030",
        session_name="bvp-judge-t-9030-abc123",
    )
    content = script_path.read_text()
    judge_calls = [l for l in content.splitlines()
                   if "bvp judge" in l and not l.strip().startswith("#")]
    assert judge_calls, "script must invoke `fw bvp judge`"
    for line in judge_calls:
        assert "--dispatch" not in line
    assert "bus post" in content
    assert "bvp-judge-dispatched" in content


def test_worker_script_uses_inline_json_path(tmp_path, monkeypatch):
    monkeypatch.setenv("PROJECT_ROOT", str(tmp_path))
    _fw_stub(tmp_path)

    script_path = dispatch_cli._write_worker_script(
        fw=str(tmp_path / "bin" / "fw"), task_id="T-9031", session_name="s1")
    content = script_path.read_text()
    assert "bvp judge \"$TASK\" --json" in content
