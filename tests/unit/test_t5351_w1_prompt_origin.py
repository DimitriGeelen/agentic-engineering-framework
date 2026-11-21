"""T-5351 — W1-hook projects send one adapter/2 prompt_submit for a checked main-claim origin.

010-termlink T-3694 (operator ruling A): where TermLink's own W1 sidecar hooks run, adapter/2
stays off (w1-guard), so prompt() claimed main with no origin — ignored once origin reporting
is on (FCW-53). Behind SIDECAR_W1_PROMPT_ORIGIN=1 the prompt hook now sends exactly ONE
prompt_submit and claims with the receiver's origin_checked/basis_checked. Hermetic: a stub
UNIX socket stands in for the sidecar; main_session.claim is captured, never run.
"""

from __future__ import annotations

import json
import os
import shutil
import socket
import tempfile
import threading
import time

import pytest

from lib.sidecar import adapter, adapter2, hooks, main_session

SID = "5351aaaa-4f50-6172-8394-a5b6c7d8e9f0"
W1_SETTINGS = {"hooks": {"UserPromptSubmit": [{"hooks": [
    {"type": "command", "command": "termlink sidecar hook prompt"}]}]}}


class Stub:
    """Fake sidecar send socket. ``mode``: answer | silent | garbage."""

    def __init__(self, path, mode="answer", check=None):
        self.path, self.mode, self.seen = path, mode, []
        self.check = check or (lambda o: {"origin_checked": "human", "basis_checked": "pty-input"})
        self.srv = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self.srv.bind(path)
        self.srv.listen(8)
        threading.Thread(target=self._serve, daemon=True).start()

    def _serve(self):
        while True:
            try:
                conn, _ = self.srv.accept()
            except OSError:
                return
            with conn:
                buf = b""
                while not buf.endswith(b"\n"):
                    c = conn.recv(4096)
                    if not c:
                        break
                    buf += c
                self.seen.append(json.loads(buf))
                if self.mode == "silent":
                    time.sleep(1.0)
                    continue
                if self.mode == "garbage":
                    conn.sendall(b"not json at all\n")
                    continue
                ans: dict = {"ok": True}
                ans.update(self.check(self.seen[-1]))
                conn.sendall(json.dumps(ans).encode() + b"\n")

    def close(self):
        self.srv.close()


@pytest.fixture
def env(tmp_path, monkeypatch):
    root = tmp_path / "t5351"
    (root / ".context" / "sidecar").mkdir(parents=True)
    (root / ".claude").mkdir()
    (root / ".framework.yaml").write_text("project_name: t5351\n")
    home = tmp_path / "home"
    home.mkdir()
    monkeypatch.setenv("HOME", str(home))
    monkeypatch.setenv("PROJECT_ROOT", str(root))
    monkeypatch.setenv("CLAUDE_PROJECT_DIR", str(root))
    monkeypatch.setenv("FW_SIDECAR_REGISTRY_DIR", str(tmp_path / "registry"))
    for v in ("FW_REVIEW_WORKER", "FW_DISPATCHED_WORKER", "FW_REVIEWER_IN_DISPATCH", "TERMLINK_SESSION_ID",
              "TERMLINK_AGENT_ID", "FW_TERMLINK_ADAPTER2"):
        monkeypatch.delenv(v, raising=False)
    monkeypatch.setattr(adapter, "_claude_ancestor_pid", lambda *a, **k: 4242)
    monkeypatch.setattr(adapter, "_is_headless", lambda pid: False)
    d = tempfile.mkdtemp(prefix="t5351-")
    sock = os.path.join(d, "agent-w.send.sock")
    monkeypatch.setenv("TERMLINK_SIDECAR_SOCKET", sock)
    monkeypatch.setenv("FW_TERMLINK_ADAPTER2", "1")          # on, but the w1-guard keeps it off
    monkeypatch.setenv("FW_SIDECAR_W1_PROMPT_ORIGIN", "1")
    (root / ".claude" / "settings.json").write_text(json.dumps(W1_SETTINGS))
    claims: list[dict] = []

    def fake_claim(session_id, force=False, **kw):
        claims.append({"session_id": session_id, "force": force, **kw})
        return main_session.CLAIMED
    monkeypatch.setattr(main_session, "claim", fake_claim)
    monkeypatch.setattr(main_session, "ask", lambda sid, **k: (main_session.MAIN, "", False))
    yield {"root": root, "sock": sock, "claims": claims}
    shutil.rmtree(d, ignore_errors=True)


def _prompt(text="please continue"):
    hooks.prompt({"session_id": SID, "prompt": text, "transcript_path": None}, out=open(os.devnull, "w"))


# 1 ─ W1 present, stub answers human → one claim with the checked origin ──────────

def test_w1_present_claims_with_receiver_checked_origin(env):
    srv = Stub(env["sock"])
    try:
        _prompt()
    finally:
        srv.close()
    assert [o["event"] for o in srv.seen] == ["prompt_submit"]          # exactly one report, no BUSY
    assert srv.seen[0]["schema"] == adapter2.SCHEMA and srv.seen[0]["agent_id"] == "agent-w"
    assert srv.seen[0]["session_id"] == SID
    (c,) = env["claims"]
    assert (c["origin"], c["basis"], c["kind"]) == ("human", "pty-input", "prompt")
    assert main_session.origin_args(c["origin"], c["basis"], c["kind"]) == \
        ["--origin", "human", "--basis", "pty-input", "--kind", "prompt"]


def test_receiver_downgrade_is_what_the_claim_carries(env):
    srv = Stub(env["sock"], check=lambda o: {"origin_checked": "automated", "basis_checked": "doorbell"})
    try:
        _prompt()
    finally:
        srv.close()
    (c,) = env["claims"]
    assert (c["origin"], c["basis"]) == ("automated", "doorbell")


# 2 ─ guard pin ─────────────────────────────────────────────────────────────────

def test_adapter2_stays_off_with_w1_present(env):
    assert adapter2.w1_hook_files()
    assert adapter2.enabled() is False
    assert adapter2.hook_reports("prompt", {"session_id": SID}) is None


# 3 ─ failures → origin unknown, basis naming it, one error line ──────────────────

@pytest.mark.parametrize("mode,why", [(None, "no-socket"), ("silent", "timeout"),
                                      ("garbage", "malformed-reply")])
def test_failure_claims_unknown_with_one_error_line(env, capsys, mode, why):
    srv = Stub(env["sock"], mode=mode) if mode else None
    t0 = time.monotonic()
    try:
        _prompt()
    finally:
        if srv:
            srv.close()
    assert time.monotonic() - t0 < 0.9                   # bounded by the ~250 ms timeout
    (c,) = env["claims"]
    assert (c["origin"], c["basis"], c["kind"]) == ("unknown", f"w1-origin: {why}", "prompt")
    err = [ln for ln in capsys.readouterr().err.splitlines() if "w1-origin" in ln]
    assert len(err) == 1 and why in err[0]


def test_reply_without_valid_origin_is_malformed_never_human(env, capsys):
    srv = Stub(env["sock"], check=lambda o: {"origin_checked": "operator"})
    try:
        _prompt()
    finally:
        srv.close()
    (c,) = env["claims"]
    assert c["origin"] == "unknown" and c["basis"] == "w1-origin: malformed-reply"


# 4 ─ no W1 hooks, or flag off → claim byte-identical to today ─────────────────────

@pytest.mark.parametrize("variant", ["flag-off", "no-w1", "no-socket-path"])
def test_not_applicable_claims_exactly_as_before(env, monkeypatch, variant):
    if variant == "flag-off":
        monkeypatch.setenv("FW_SIDECAR_W1_PROMPT_ORIGIN", "0")
    elif variant == "no-w1":
        (env["root"] / ".claude" / "settings.json").write_text("{}")
        monkeypatch.setenv("FW_TERMLINK_ADAPTER2", "0")
    else:
        monkeypatch.delenv("TERMLINK_SIDECAR_SOCKET")
    srv = Stub(env["sock"])
    try:
        _prompt()
    finally:
        srv.close()
    assert srv.seen == []                                 # nothing sent
    assert env["claims"] == [{"session_id": SID, "force": False}]


# 5 ─ headless → no claim, nothing sent ─────────────────────────────────────────────

def test_headless_never_claims(env, monkeypatch):
    monkeypatch.setattr(adapter, "_is_headless", lambda pid: True)
    srv = Stub(env["sock"])
    try:
        _prompt()
    finally:
        srv.close()
    assert env["claims"] == [] and srv.seen == []
