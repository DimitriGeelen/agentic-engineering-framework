"""T-4533 — direct-path sends to AEF around a session restart were 401.

832 (msg 197ddc3d): three direct sends to AEF at ~11:05Z 2026-10-21 were
REJECTED with HTTP 401; a later retry got through. Our receiver log puts that
inside the 10:52:15Z-11:15:06Z window T-4560 traced: a restart rewrote
receiver.token, its new server refused (T-4208 rival, exit 3), and the live
receiver kept checking only the token it read at startup, while every sender
read the new one from the file. The "later retry" succeeded after the 11:15Z
restart that finally loaded the new token.

This test replays 832's shape through the real `sidecar send` CLI: receiver
up, token rotated with no successful restart, three sends in a row. Before
T-4560 (ba9eaa5f9) all three were REJECTED/401; now all three are RECEIVED.
No token value is printed; tokens are compared, never shown.
"""

from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path

import pytest

FW_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(FW_ROOT))

from lib.sidecar import adapter, lifecycle  # noqa: E402

CLI = [sys.executable, str(FW_ROOT / "lib" / "sidecar_cli.py")]


@pytest.fixture
def env(tmp_path, monkeypatch):
    monkeypatch.setenv("FW_SIDECAR_REGISTRY_DIR", str(tmp_path / "registry"))
    monkeypatch.delenv("FW_SIDECAR_AGENT_ID", raising=False)
    monkeypatch.delenv("FW_REVIEW_WORKER", raising=False)
    monkeypatch.setattr(adapter, "_claude_ancestor_pid", lambda *a, **k: None)
    started: list[Path] = []

    def project(name):
        root = tmp_path / name
        (root / ".context").mkdir(parents=True)
        (root / ".framework.yaml").write_text(f"project_name: {name}\n")
        return root

    def cli(root, *args):
        e = dict(os.environ, PROJECT_ROOT=str(root))
        e.pop("FW_SIDECAR_AGENT_ID", None)
        return subprocess.run(CLI + list(args), cwd=root, env=e,
                              capture_output=True, text=True, timeout=60)

    def start(root):
        proc = cli(root, "receiver", "start", "--no-watcher", "--no-inject")
        assert proc.returncode == 0, proc.stdout + proc.stderr
        started.append(root)

    yield project, cli, start, monkeypatch
    for root in started:
        cli(root, "receiver", "stop", "--quiet")


def test_sends_after_failed_restart_rotation_are_received(env):
    project, cli, start, monkeypatch = env
    sender, aef = project("t4533-832"), project("t4533-aef")
    start(aef)
    reg = Path(os.environ["FW_SIDECAR_REGISTRY_DIR"]) / "t4533-aef.json"
    pid_before = json.loads(reg.read_text())["pid"]
    tok = aef / ".context" / "sidecar" / "receiver.token"
    before = tok.read_text()

    # The 10:52:15Z restart: token rewritten, new server never binds, the old
    # receiver (same pid, same port) stays live.
    monkeypatch.setenv("PROJECT_ROOT", str(aef))
    lifecycle.write_token()
    assert tok.read_text() != before
    assert json.loads(reg.read_text())["pid"] == pid_before

    for i in range(3):                      # 832's three sends at ~11:05Z
        proc = cli(sender, "send", "--to", "t4533-aef", "--body", f"send {i}",
                   "--json", "--retries", "1")
        out = json.loads(proc.stdout)
        assert out["state"] == "RECEIVED", out
        assert proc.returncode == 0
        assert before not in proc.stdout + proc.stderr
        assert tok.read_text() not in proc.stdout + proc.stderr
