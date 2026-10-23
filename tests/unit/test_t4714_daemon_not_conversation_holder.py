"""T-4714 (055 T-582) — the claude daemon is never a conversation holder.

A Claude Code background session runs as comm '2.1.304' with argv[0]
rewritten to 'claude bg-spare', under 'claude bg-pty-host' and the
never-exiting 'claude daemon run'. The ancestor walk matched comm=='claude'
only, so it walked past the session and recorded the daemon's pid; the
T-3890 holder check then refused every resume of that conversation for as
long as the daemon lived.

Every process here is a fake /proc tree under tmp_path; no real process is
inspected or signalled.
"""

from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

import pytest

FW_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(FW_ROOT))

from lib.sidecar import adapter  # noqa: E402


def _proc(root: Path, pid: int, ppid: int, comm: str, argv: list[str]) -> None:
    d = root / str(pid)
    d.mkdir(parents=True)
    (d / "stat").write_text(f"{pid} ({comm}) S {ppid} {pid} {pid} 0 -1\n")
    (d / "cmdline").write_bytes(b"\0".join(a.encode() for a in argv) + b"\0")


@pytest.fixture
def proc(tmp_path, monkeypatch):
    root = tmp_path / "proc"
    root.mkdir()
    monkeypatch.setattr(adapter, "_PROC_ROOT", str(root))
    return root


def _bg_tree(root: Path) -> None:
    _proc(root, 100, 1, "claude", ["claude", "daemon", "run"])
    _proc(root, 200, 100, "claude", ["claude bg-pty-host"])
    _proc(root, 300, 200, "2.1.304", ["claude bg-spare"])
    _proc(root, 400, 300, "bash", ["/bin/bash", "-c", "hook"])
    _proc(root, 500, 400, "python3", ["python3", "hook.py"])


def test_bg_session_pid_returned_not_daemon(proc):
    _bg_tree(proc)
    assert adapter._claude_ancestor_pid(start=500) == 300


def test_walk_stops_at_daemon_and_pty_host(proc):
    _proc(proc, 100, 1, "claude", ["claude", "daemon", "run"])
    _proc(proc, 200, 100, "claude", ["claude bg-pty-host"])
    _proc(proc, 400, 200, "bash", ["/bin/bash"])
    assert adapter._claude_ancestor_pid(start=400) is None
    _proc(proc, 410, 100, "bash", ["/bin/bash"])
    assert adapter._claude_ancestor_pid(start=410) is None


def test_interactive_claude_still_recognised(proc):
    _proc(proc, 700, 1, "claude", ["claude", "--resume", "abc"])
    _proc(proc, 710, 700, "bash", ["/bin/bash"])
    assert adapter._claude_ancestor_pid(start=710) == 700


def test_argv0_path_basename_is_claude(proc):
    _proc(proc, 800, 1, "node", ["/usr/local/bin/claude", "-c"])
    _proc(proc, 810, 800, "bash", ["/bin/bash"])
    assert adapter._claude_ancestor_pid(start=810) == 800


def test_non_claude_chain_returns_none(proc):
    _proc(proc, 900, 1, "bash", ["/bin/bash", "claude-notes.txt"])
    _proc(proc, 910, 900, "python3", ["python3"])
    assert adapter._claude_ancestor_pid(start=910) is None


def _holder(tmp_path: Path, proc: Path, pid: int) -> str:
    proj = tmp_path / "proj"
    (proj / ".context/sidecar/sessions").mkdir(parents=True, exist_ok=True)
    (proj / ".context/sidecar/sessions/c1.json").write_text(
        f'{{"session_id":"c1","claude_pid":{pid}}}\n')
    out = subprocess.run(
        ["bash", "-c", 'source "$1/lib/conversation-holder.sh"; '
         'fw_conversation_holder "$2" c1', "_", str(FW_ROOT), str(proj)],
        env=dict(os.environ, FW_PROC_ROOT=str(proc)),
        capture_output=True, text=True, timeout=30)
    assert out.returncode == 0, out.stderr
    return out.stdout.strip()


def test_holder_naming_daemon_is_not_live(tmp_path, proc):
    _bg_tree(proc)
    assert _holder(tmp_path, proc, 100) == ""
    assert _holder(tmp_path, proc, 200) == ""


def test_holder_naming_bg_session_or_interactive_is_live(tmp_path, proc):
    _bg_tree(proc)
    assert _holder(tmp_path, proc, 300) == "300"
    _proc(proc, 700, 1, "claude", ["claude", "--resume", "abc"])
    assert _holder(tmp_path, proc, 700) == "700"


def test_holder_missing_pid_is_not_live(tmp_path, proc):
    assert _holder(tmp_path, proc, 4242) == ""
