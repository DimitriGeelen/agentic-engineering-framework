"""T-5054 slice 2 — the main-lease claim carries the receiver-checked prompt origin (010 P-44).

TermLink's r3 fixture (tests/fixtures/termlink-parity/r3-prompt-origin.json, 8b5e51fd0) lists
what the HUB does with each claim (renewed, ignored, fast-takeover, ...). The hub's decision is
TermLink's; what AEF owns is the claim each hook makes. So every r3 case is checked here as:
the hook the case names makes exactly the claim the case describes (kind, origin, basis,
interactive) — or no claim at all where the case says a hook never renews. Negative controls:
a doorbell line never claims human; tool activity and Stop never claim; an unreachable sidecar
claims `unknown`, never the hook's own `human`. With the switch off every claim is T-5014's.
"""

from __future__ import annotations

import json
import os
import shutil
import socket
import tempfile
import threading
from pathlib import Path

import pytest

from lib.sidecar import adapter, adapter2, hooks, main_session

ROOT = Path(__file__).resolve().parents[2]
R3 = json.loads((ROOT / "tests/fixtures/termlink-parity/r3-prompt-origin.json").read_text())
SID = "0b1c2d3e-4f50-6172-8394-a5b6c7d8e9f0"


class Sidecar:
    """Fake TermLink send socket: answers prompt_submit with a chosen check."""

    def __init__(self, path, check):
        self.path, self.check, self.seen = path, check, []
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
                obj = json.loads(buf)
                self.seen.append(obj)
                ans = {"ok": True}
                if obj["event"] == "prompt_submit":
                    ans.update(self.check(obj))
                conn.sendall(json.dumps(ans).encode() + b"\n")

    def close(self):
        self.srv.close()


@pytest.fixture
def env(tmp_path, monkeypatch):
    root = tmp_path / "t5054"
    (root / ".context" / "sidecar").mkdir(parents=True)
    (root / ".framework.yaml").write_text("project_name: t5054\n")
    monkeypatch.setenv("PROJECT_ROOT", str(root))
    monkeypatch.setenv("CLAUDE_PROJECT_DIR", str(root))
    monkeypatch.setenv("FW_SIDECAR_REGISTRY_DIR", str(tmp_path / "registry"))
    for v in ("FW_REVIEW_WORKER", "FW_DISPATCHED_WORKER", "FW_REVIEWER_IN_DISPATCH", "TERMLINK_SESSION_ID",
              "TERMLINK_AGENT_ID"):
        monkeypatch.delenv(v, raising=False)
    monkeypatch.setattr(adapter, "_claude_ancestor_pid", lambda *a, **k: 4242)
    monkeypatch.setattr(adapter, "_is_headless", lambda pid: False)
    d = tempfile.mkdtemp(prefix="t54-")
    sock = os.path.join(d, "agent-b.send.sock")
    monkeypatch.setenv("TERMLINK_SIDECAR_SOCKET", sock)
    monkeypatch.setenv("FW_TERMLINK_ADAPTER2", "1")
    claims: list[dict] = []

    def fake_claim(session_id, force=False, **kw):
        claims.append({"session_id": session_id, "force": force, **kw})
        return main_session.CLAIMED
    monkeypatch.setattr(main_session, "claim", fake_claim)
    monkeypatch.setattr(main_session, "ask", lambda sid, **k: (main_session.MAIN, "", False))
    yield {"root": root, "sock": sock, "claims": claims}
    shutil.rmtree(d, ignore_errors=True)


def _prompt(env, text="please continue", check=None):
    srv = Sidecar(env["sock"], check or (lambda o: {"origin_checked": o["origin"],
                                                     "basis_checked": o.get("basis")}))
    try:
        hooks.prompt({"session_id": SID, "prompt": text, "transcript_path": None}, out=open(os.devnull, "w"))
    finally:
        srv.close()
    return srv


# ── the r3 cases, from the claiming side ───────────────────────────────────────

PROMPT_CASES = [c for c in R3["cases"] if c["hook"] == "prompt"]


@pytest.mark.parametrize("case", PROMPT_CASES, ids=[c["name"] for c in PROMPT_CASES])
def test_prompt_case_claims_with_the_receiver_checked_origin(env, case):
    """The receiver's check is what the claim carries, whatever the hook guessed. A case with
    no origin is the hub's rule for a harness that does not report one; ours always does."""
    want_origin = case.get("origin", "unknown")
    want_basis = case.get("basis")
    _prompt(env, check=lambda o: {"origin_checked": want_origin, "basis_checked": want_basis})
    (c,) = env["claims"]
    assert c["kind"] == "prompt" and c["origin"] == want_origin
    assert c.get("basis") == (want_basis if want_origin != "unknown" else None)
    argv = main_session.origin_args(c["origin"], c.get("basis"), c["kind"])
    assert argv[:2] == ["--origin", want_origin]          # reporting mode never omits origin
    if want_basis and want_origin != "unknown":
        assert ["--basis", want_basis] == argv[2:4]       # 'watchdog' passes through untouched


def test_tool_activity_never_claims(env):
    """r3 tool-activity-never-renews: no tool hook claims; Stop does not renew either (CR-O3)."""
    case = next(c for c in R3["cases"] if c["hook"] == "tool")
    assert case["expect"] == "unchanged"
    for hook in ("pre-tool", "post-tool", "stop", "session-end"):
        assert adapter2.hook_reports(hook, {"session_id": SID, "tool_name": "Bash"}) == {"claim": False}
    srv = Sidecar(env["sock"], lambda o: {})
    try:
        hooks.stop({"session_id": SID})
    finally:
        srv.close()
    assert env["claims"] == []
    assert [o["event"] for o in srv.seen] == ["turn_stop", "ready"] and srv.seen[1]["state"] == "READY"


@pytest.mark.parametrize("interactive", [True, False])
def test_session_start_claims_as_session_start_with_the_interactive_flag(env, monkeypatch, interactive):
    """r3 interactive-session-start-on-vacant-is-provisional / headless-session-start-takes-nothing:
    an interactive start claims --kind session-start --interactive; a headless one never claims."""
    monkeypatch.setattr(adapter, "_is_headless", lambda pid: not interactive)
    srv = Sidecar(env["sock"], lambda o: {})
    try:
        hooks.session_start({"session_id": SID, "transcript_path": None}, spawn=False)
    finally:
        srv.close()
    assert srv.seen and srv.seen[0]["event"] == "session_start" and srv.seen[0]["interactive"] is interactive
    if interactive:
        (c,) = env["claims"]
        assert c["kind"] == "session-start" and c["interactive"] is True and c["force"] is True
        assert main_session.origin_args(kind="session-start", interactive=True) == \
            ["--kind", "session-start", "--interactive"]
    else:
        assert env["claims"] == []


def test_every_r3_case_is_covered():
    covered = {c["name"] for c in PROMPT_CASES} | {c["name"] for c in R3["cases"]
                                                   if c["hook"] in ("tool", "session-start")}
    assert covered == {c["name"] for c in R3["cases"]} and len(covered) == 13


# ── negative controls, end to end ───────────────────────────────────────────────

def test_doorbell_line_claims_automated_even_if_the_receiver_echoes(env):
    srv = _prompt(env, "[sidecar] 1 peer message waiting (ids ab12cd34, typed 2026-11-13T07:09Z). x")
    sent = [o for o in srv.seen if o["event"] == "prompt_submit"][0]
    assert (sent["origin"], sent["basis"]) == ("automated", "doorbell")
    (c,) = env["claims"]
    assert (c["origin"], c["basis"]) == ("automated", "doorbell")


def test_unreachable_sidecar_claims_unknown_never_human(env, monkeypatch):
    monkeypatch.setattr(adapter2, "_log_error", lambda where: None)
    hooks.prompt({"session_id": SID, "prompt": "hello"}, out=open(os.devnull, "w"))   # no server
    (c,) = env["claims"]
    assert (c["origin"], c.get("basis")) == ("unknown", None)


def test_receiver_downgrade_wins_over_the_hooks_human(env):
    srv = _prompt(env, "hello", check=lambda o: {"origin_checked": "automated", "basis_checked": "pty-input"})
    assert [o for o in srv.seen if o["event"] == "prompt_submit"][0]["origin"] == "human"
    (c,) = env["claims"]
    assert (c["origin"], c["basis"]) == ("automated", "pty-input")


# ── switch off: exactly T-5014 ──────────────────────────────────────────────────

def test_switch_off_claims_exactly_as_before(env, monkeypatch):
    monkeypatch.setenv("FW_TERMLINK_ADAPTER2", "0")
    hooks.prompt({"session_id": SID, "prompt": "hello"}, out=open(os.devnull, "w"))
    hooks.stop({"session_id": SID})
    assert [set(c) for c in env["claims"]] == [{"session_id", "force"}, {"session_id", "force"}]


def test_claim_argv_with_and_without_origin():
    calls = []

    class P:
        returncode, stdout, stderr = 1, "", ""

    def runner(argv, **kw):
        calls.append(argv)
        return P()
    main_session.claim("s1", force=True, runner=runner)
    main_session.claim("s1", force=True, runner=runner, origin="human", basis="inferred", kind="prompt")
    main_session.claim("s1", force=True, runner=runner, origin="bogus", basis="x y", kind="nope")
    assert calls[0][-2:] == ["--session", "s1"]
    assert calls[1][-6:] == ["--origin", "human", "--basis", "inferred", "--kind", "prompt"]
    assert calls[2][-4:] == ["--origin", "unknown", "--kind", "prompt"]     # never upgraded, junk dropped


def test_detached_session_start_claim_accepts_only_the_exact_kind_args(monkeypatch):
    seen = []
    monkeypatch.setattr(main_session, "claim", lambda sid, **kw: seen.append((sid, kw)))
    main_session.main(["claim", "s1"])
    main_session.main(["claim", "s1", "--kind", "session-start", "--interactive"])
    main_session.main(["claim", "s1", "--origin", "human"])                   # not accepted: no claim
    assert seen == [("s1", {"force": True}),
                    ("s1", {"force": True, "kind": "session-start", "interactive": True})]
