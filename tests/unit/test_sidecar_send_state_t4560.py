"""T-4560 — a direct send's delivery state reaches the caller, and a token
rotation under a live receiver does not turn every send into a 401.

055 sent fbed1313 to this project's receiver at 10:59Z 2026-10-21 and got
REJECTED (HTTP 401). At 10:52:15Z a restart had rewritten receiver.token and
then refused to start (T-4208 rival, exit 3), so the live receiver kept the
token it read at startup while every sender read the new one from the file.

No token value is printed by these tests; they compare tokens, never show them.
"""

from __future__ import annotations

import json
import os
import signal
import subprocess
import sys
import time
from pathlib import Path

import pytest

FW_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(FW_ROOT))

from lib.sidecar import adapter, direct, lifecycle  # noqa: E402

CLI = [sys.executable, str(FW_ROOT / "lib" / "sidecar_cli.py")]


def _project(tmp_path: Path, name: str) -> Path:
    root = tmp_path / name
    (root / ".context").mkdir(parents=True)
    (root / ".framework.yaml").write_text(f"project_name: {name}\n")
    return root


@pytest.fixture
def env(tmp_path, monkeypatch):
    monkeypatch.setenv("FW_SIDECAR_REGISTRY_DIR", str(tmp_path / "registry"))
    monkeypatch.delenv("FW_SIDECAR_AGENT_ID", raising=False)
    monkeypatch.delenv("FW_REVIEW_WORKER", raising=False)
    monkeypatch.setattr(adapter, "_claude_ancestor_pid", lambda *a, **k: None)
    started: list[Path] = []

    class Env:
        tmp = tmp_path

        def project(self, name):
            return _project(tmp_path, name)

        def use(self, root):
            monkeypatch.setenv("PROJECT_ROOT", str(root))

        def cli(self, root, *args):
            e = dict(os.environ, PROJECT_ROOT=str(root))
            e.pop("FW_SIDECAR_AGENT_ID", None)
            return subprocess.run(CLI + list(args), cwd=root, env=e,
                                  capture_output=True, text=True, timeout=60)

        def start(self, root):
            proc = self.cli(root, "receiver", "start", "--no-watcher", "--no-inject")
            assert proc.returncode == 0, proc.stdout + proc.stderr
            started.append(root)

        def registry(self, name):
            return Path(os.environ["FW_SIDECAR_REGISTRY_DIR"]) / f"{name}.json"

    yield Env()
    for root in started:
        Env().cli(root, "receiver", "stop", "--quiet")


def _point_registry_at_wrong_token(env, name):
    """The sender holds a token the receiver does not accept (055's 401)."""
    wrong = env.tmp / "wrong.token"
    wrong.write_text("0" * 64)
    reg = env.registry(name)
    entry = json.loads(reg.read_text())
    entry["token_file"] = str(wrong)
    reg.write_text(json.dumps(entry))


# ── part 2: the state reaches the caller, and the exit code says it ─────────

def test_received_exits_0_and_prints_state(env):
    a, b = env.project("t4560-a"), env.project("t4560-b")
    env.start(b)
    proc = env.cli(a, "send", "--to", "t4560-b", "--body", "hi")
    assert proc.returncode == 0, proc.stdout + proc.stderr
    assert "delivered: RECEIVED" in proc.stdout
    assert "client_msg_id:" in proc.stdout


@pytest.mark.parametrize("as_json", [False, True])
def test_rejected_exits_nonzero_and_prints_state(env, as_json):
    a, b = env.project("t4560-a"), env.project("t4560-b")
    env.start(b)
    _point_registry_at_wrong_token(env, "t4560-b")
    proc = env.cli(a, "send", "--to", "t4560-b", "--body", "hi", *(["--json"] if as_json else []))
    assert proc.returncode != 0, proc.stdout + proc.stderr
    if as_json:
        out = json.loads(proc.stdout)
        assert out["state"] == "REJECTED" and out["delivered"] is False
        assert "401" in out["reason"]
    else:
        assert "NOT delivered: REJECTED" in proc.stdout
        assert "401" in proc.stdout
    assert "0" * 64 not in proc.stdout + proc.stderr


@pytest.mark.parametrize("as_json", [False, True])
def test_undeliverable_exits_nonzero_and_prints_state(env, as_json):
    a, b = env.project("t4560-a"), env.project("t4560-b")
    env.start(b)
    os.kill(lifecycle_pid(env, "t4560-b"), signal.SIGKILL)   # registry entry survives
    time.sleep(0.2)
    proc = env.cli(a, "send", "--to", "t4560-b", "--body", "hi", "--retries", "1",
                   *(["--json"] if as_json else []))
    assert proc.returncode != 0, proc.stdout + proc.stderr
    if as_json:
        assert json.loads(proc.stdout)["state"] == "UNDELIVERABLE"
    else:
        assert "NOT delivered: UNDELIVERABLE" in proc.stdout


def lifecycle_pid(env, name) -> int:
    return int(json.loads(env.registry(name).read_text())["pid"])


@pytest.mark.parametrize("state,delivered,rc", [("HUB_ACCEPTED", True, 0),
                                                ("SENT", True, 0),
                                                ("REJECTED", False, 1)])
def test_hub_path_prints_state_and_exit_follows_delivery(env, monkeypatch, capsys,
                                                         state, delivered, rc):
    import lib.sidecar_cli as cli
    a = env.project("t4560-a")
    env.use(a)

    class Result:
        reason = None if delivered else "hub refused"

    def fake_deliver(cid, *_):
        r = Result()
        r.client_msg_id, r.state, r.delivered = cid, state, delivered
        return r
    monkeypatch.setattr(cli.delivery, "deliver", fake_deliver)
    monkeypatch.setattr(cli.addressing, "resolve", lambda to, hub=None, level="auto": {
        "circuit": f"hub/{to}", "topic": f"inbox:hub/{to}", "hub": None, "how": "test"})
    monkeypatch.setattr(cli.circuit, "topic_for_circuit", lambda c: f"inbox:{c}")
    assert cli.main(["send", "--to", "nobody-registered", "--body", "x"]) == rc
    assert f": {state}" in capsys.readouterr().out


# ── part 1: a token rewritten under a live receiver ─────────────────────────

def test_live_receiver_accepts_token_rewritten_after_it_started(env):
    """The 10:52Z sequence: a restart rewrites receiver.token, its new server
    refuses (rival), the old receiver stays live. Senders read the file."""
    a, b = env.project("t4560-a"), env.project("t4560-b")
    env.start(b)
    tok = b / ".context" / "sidecar" / "receiver.token"
    before = tok.read_text()
    env.use(b)
    lifecycle.write_token()                    # rotation without a successful restart
    assert tok.read_text() != before
    env.use(a)
    row = direct.send(lifecycle.lookup("t4560-b"), from_id="t4560-a", to="t4560-b",
                      body="after rotation", conversation_id="c", retries=1)
    assert row["state"] == direct.RECEIVED, row.get("error")


def test_wrong_token_still_rejected_after_rotation(env):
    a, b = env.project("t4560-a"), env.project("t4560-b")
    env.start(b)
    env.use(b)
    lifecycle.write_token()
    env.use(a)
    row = direct.send(lifecycle.lookup("t4560-b"), from_id="t4560-a", to="t4560-b",
                      body="x", conversation_id="c", token="1" * 64, retries=1)
    assert row["state"] == direct.REJECTED and "401" in row["error"]
