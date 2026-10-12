"""T-4131 — a truncated peer message names a read verb; send warns on long bodies."""

from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

FW_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(FW_ROOT))

from lib.sidecar import hooks, receiver  # noqa: E402

CLI = [sys.executable, str(FW_ROOT / "lib" / "sidecar_cli.py")]
MID = "aaaa-bbbb-0001"


def _project(tmp_path):
    (tmp_path / ".context").mkdir()
    (tmp_path / ".framework.yaml").write_text("project_name: t4131\n")
    return tmp_path


def _run(tmp_path, *args):
    env = dict(os.environ, PROJECT_ROOT=str(tmp_path), FW_SIDECAR_AGENT_ID="t4131-test")
    return subprocess.run(CLI + list(args), cwd=tmp_path, env=env,
                          capture_output=True, text=True, timeout=60)


def test_marker_names_show_verb():
    body = "x" * (hooks.BODY_CAP + 50)
    lines = hooks._block({"client_msg_id": MID, "from": "p", "body": body}, "s", "/fw")
    text = "\n".join(lines)
    assert "[truncated, 50 more chars;" in text
    assert f"/fw sidecar inbox --show {MID}" in text
    assert hooks.BODY_CAP == 4000


def test_short_body_has_no_marker():
    text = "\n".join(hooks._block({"client_msg_id": MID, "body": "hi"}, "s", "/fw"))
    assert "truncated" not in text


def test_show_known_id_prints_full_framed_body(tmp_path, monkeypatch):
    root = _project(tmp_path)
    monkeypatch.setenv("PROJECT_ROOT", str(root))
    body = "A" * 5000 + f" {hooks.CLOSE} tail"
    ok, err = receiver.store_message(MID, {"client_msg_id": MID, "from": "peer", "body": body})
    assert ok, err
    r = _run(root, "inbox", "--show", MID)
    assert r.returncode == 0, r.stderr
    assert "A" * 5000 in r.stdout and "tail" in r.stdout
    assert r.stdout.count(hooks.OPEN) == 1 and r.stdout.count(hooks.CLOSE) == 1
    assert "UNTRUSTED" in r.stdout


def test_show_unknown_id_fails(tmp_path):
    root = _project(tmp_path)
    for bad in ("nope-0000", "../../etc/passwd"):
        r = _run(root, "inbox", "--show", bad)
        assert r.returncode != 0
        assert "no stored message" in r.stderr


def test_send_warns_on_long_body_and_still_attempts(tmp_path):
    root = _project(tmp_path)
    r = _run(root, "send", "--to", "nobody-t4131", "--body", "y" * (hooks.BODY_CAP + 1))
    assert r.stderr.count("WARNING body is 4001 chars") == 1
    assert "inbox --show" in r.stderr
    short = _run(root, "send", "--to", "nobody-t4131", "--body", "short")
    assert "WARNING body" not in short.stderr
