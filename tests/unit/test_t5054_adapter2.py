"""T-5054 slice 1 — the Claude Code adapter's termlink.adapter/2 reports (010 P-44).

Checked against TermLink's parity fixture tests/fixtures/termlink-parity/p2-report-ordering.json
(TermLink 8b5e51fd0): our lines carry every field the fixture's payloads carry, in the same
types; mono_ns is a decimal string; nothing orders on at_ms. An ordering oracle written from
the fixture's own `about` text is first checked against every fixture case (and an oracle keyed
on at_ms against the negative control), then fed OUR emitted lines.
"""

import json
import os
import socket
import threading
from pathlib import Path

import pytest

from lib.sidecar import adapter2 as a2


@pytest.fixture(autouse=True)
def _isolated_config(tmp_path, monkeypatch):
    """Never read the developer's own .framework.yaml: on a host running the adapter trial it
    sets TERMLINK_ADAPTER2 and TERMLINK_SIDECAR_SOCKET, which made the switch-off legs pass or
    fail by host. A test that needs a project root sets CLAUDE_PROJECT_DIR itself."""
    empty = tmp_path / "isolated-project"
    empty.mkdir()
    monkeypatch.setenv("CLAUDE_PROJECT_DIR", str(empty))
    for k in ("FW_TERMLINK_ADAPTER2", "TERMLINK_SIDECAR_SOCKET", "FW_TERMLINK_SIDECAR_SOCKET"):
        monkeypatch.delenv(k, raising=False)

ROOT = Path(__file__).resolve().parents[2]
P2 = json.loads((ROOT / "tests/fixtures/termlink-parity/p2-report-ordering.json").read_text())
SID = "sess-p2"
AGENT = P2["agent_id"]


def clock(boot="b1", start=100, wall=None):
    n = iter(range(start, start + 10_000))
    w = iter(wall) if wall is not None else None
    return a2.Clock(boot=boot, mono=lambda: next(n), wall_ms=(lambda: next(w)) if w else (lambda: 1))


# ── fixture parity: field set and types ────────────────────────────────────────

def _emit_like(p: dict) -> dict:
    """Our report for the same event, clocked to the fixture's own boot_id/mono_ns."""
    boot = p.get("boot_id")
    ns = p.get("mono_ns")
    c = a2.Clock(boot=boot if (boot and ns is not None) else None,
                 mono=lambda: int(ns) if ns is not None else 0, wall_ms=lambda: p["at_ms"])
    extra = {k: p[k] for k in ("state", "origin", "basis") if k in p}
    return a2.report(p["event"], agent_id=p["agent_id"], session_id=p["session_id"], clock=c, **extra)


def _malformed_pair(p: dict) -> bool:
    """A pair the fixture sends on purpose to test the RECEIVER's rejection (b:1, '', 12x, -1,
    past u64). A producer never emits one; test_we_never_emit_a_malformed_pair covers our side."""
    if "boot_id" not in p or "mono_ns" not in p:
        return False
    b, n = p["boot_id"], p["mono_ns"]
    ok_n = (isinstance(n, str) and n.isdigit() and int(n) < 2 ** 64) or \
        (isinstance(n, int) and not isinstance(n, bool) and 0 <= n < 2 ** 64)
    return not (isinstance(b, str) and a2._BOOT_RE.match(b) and ok_n)


def _fixture_payloads():
    for case in P2["cases"]:
        for i, st in enumerate(case["steps"]):
            if not _malformed_pair(st["payload"]):
                yield f"{case['name']}#{i}", st["payload"]


def test_we_never_emit_a_malformed_pair():
    for boot in ("b:1", "", "x" * 65, "b 1"):
        c = a2.Clock(boot=boot, mono=lambda: 5)
        r = a2.report("ready", agent_id=AGENT, session_id=SID, clock=c, state="BUSY")
        assert "boot_id" not in r and "mono_ns" not in r
    r = a2.report("ready", agent_id=AGENT, session_id=SID, clock=a2.Clock(boot="b1", mono=lambda: 7), state="BUSY")
    assert r["mono_ns"].isdigit() and int(r["mono_ns"]) < 2 ** 64


@pytest.mark.parametrize("label,p", list(_fixture_payloads()))
def test_every_fixture_payload_field_is_emitted_with_the_same_value_and_type(label, p):
    ours = _emit_like(p)
    for k, v in p.items():
        if k in ("boot_id", "mono_ns") and not ("boot_id" in p and "mono_ns" in p):
            continue                       # a half pair: we never send one (asserted below)
        if k == "mono_ns" and isinstance(v, int):
            assert ours[k] == str(v), label  # integer accepted by the meter; we always send the string form
            continue
        assert k in ours, f"{label}: missing {k}"
        assert ours[k] == v and type(ours[k]) is type(v), f"{label}: {k} {ours[k]!r} != {v!r}"
    assert "op" not in ours
    assert ("boot_id" in ours) == ("mono_ns" in ours), f"{label}: half pair emitted"


def test_mono_ns_above_2_pow_53_stays_an_exact_decimal_string():
    big = 2 ** 53 + 7
    r = a2.report("ready", agent_id=AGENT, session_id=SID, clock=a2.Clock(boot="b1", mono=lambda: big),
                  state="BUSY")
    line = a2.encode(r)
    assert json.loads(line)["mono_ns"] == str(big)
    assert f'"mono_ns":"{big}"'.encode() in line


def test_no_boot_id_means_neither_order_field():
    r = a2.report("ready", agent_id=AGENT, session_id=SID, clock=a2.Clock(boot=None, mono=lambda: 5),
                  state="READY")
    assert "boot_id" not in r and "mono_ns" not in r


def test_encode_refuses_op_and_oversize():
    with pytest.raises(ValueError):
        a2.encode({"op": "ready"})
    with pytest.raises(ValueError):
        a2.encode({"schema": a2.SCHEMA, "pad": "x" * a2.MAX_LINE})


def test_real_clock_values_are_valid():
    b = a2.boot_id()
    assert b is None or a2._BOOT_RE.match(b)
    x, y = a2.mono_ns(), a2.mono_ns()
    assert x.isdigit() and int(y) >= int(x)


# ── hook → reports mapping ──────────────────────────────────────────────────────

HI = {"session_id": SID, "transcript_path": None, "prompt": "hello"}


def _events(rs):
    return [(r["event"], r.get("state")) for r in rs]


def test_hook_mapping_and_strict_order_within_a_hook():
    c = clock()
    kw = dict(agent_id=AGENT, clock=c, harness_pid=4242, interactive=True)
    assert _events(a2.reports_for("stop", HI, **kw)) == [("turn_stop", None), ("ready", "READY")]
    assert _events(a2.reports_for("prompt", HI, **kw)) == [("ready", "BUSY"), ("prompt_submit", None)]
    pre = a2.reports_for("pre-tool", {**HI, "tool_name": "Bash"}, **kw)
    assert _events(pre) == [("ready", "BUSY"), ("tool_start", None)] and pre[1]["tool"] == "Bash"
    assert _events(a2.reports_for("post-tool", {**HI, "tool_name": "Bash"}, **kw)) == [("tool_end", None)]
    assert _events(a2.reports_for("session-end", HI, **kw)) == [("session_end", None)]
    ss = a2.reports_for("session-start", {**HI, "transcript_path": "/x.jsonl"}, **kw)[0]
    assert ss["event"] == "session_start" and ss["harness_pid"] == 4242 and ss["interactive"] is True
    rs = a2.reports_for("stop", HI, **kw)
    assert int(rs[0]["mono_ns"]) < int(rs[1]["mono_ns"])


def test_session_start_requires_harness_pid_and_bad_session_id_is_refused():
    with pytest.raises(ValueError):
        a2.reports_for("session-start", HI, agent_id=AGENT, clock=clock(), harness_pid=None)
    with pytest.raises(ValueError):
        a2.reports_for("stop", {"session_id": "bad id/../x"}, agent_id=AGENT, clock=clock())


def test_a_clock_that_repeats_still_gives_strictly_increasing_mono_ns():
    c = a2.Clock(boot="b1", mono=lambda: 500)
    assert [int(c.tick()[1]) for _ in range(3)] == [500, 501, 502]


# ── prompt origin (17.5) ────────────────────────────────────────────────────────

def _transcript(tmp_path, recs):
    p = tmp_path / "t.jsonl"
    p.write_text("".join(json.dumps(r) + "\n" for r in recs))
    return str(p)


def _rec(text, **marks):
    return {"type": "user", "promptId": "p1", "message": {"role": "user", "content": text}, **marks}


@pytest.mark.parametrize("hi,interactive,want", [
    ({"prompt": "[sidecar] 2 peer messages waiting (ids ab12 cd34, typed 2026-11-13T07:05Z). x"}, True,
     ("automated", "doorbell")),
    ({"prompt": "do the thing"}, False, ("automated", "non-interactive")),
    ({"prompt": "do the thing"}, True, ("human", "inferred")),
    ({"prompt": "do the thing"}, None, ("unknown", None)),
])
def test_origin_rules(hi, interactive, want):
    assert a2.classify_origin(hi, interactive) == want


@pytest.mark.parametrize("marks", [
    {"origin": {"kind": "task-notification"}, "promptSource": "system"},
    {"origin": {"kind": "peer"}},
    {"turnOrigin": "scheduled", "scheduledTaskId": "abc"},
])
def test_transcript_marks_prove_generated(tmp_path, marks):
    t = _transcript(tmp_path, [_rec("wake up", **marks)])
    assert a2.classify_origin({"prompt": "wake up", "transcript_path": t}, True) == ("automated", "harness-mark")


def test_human_mark_or_other_prompts_record_never_upgrades(tmp_path):
    # a record marked human for THIS prompt stays inferred (17.5.d: marks cannot prove human)
    t = _transcript(tmp_path, [_rec("hi", origin={"kind": "human"}, promptSource="typed")])
    assert a2.classify_origin({"prompt": "hi", "transcript_path": t}, True) == ("human", "inferred")
    # a generated record for a DIFFERENT prompt is not this prompt's mark
    t2 = _transcript(tmp_path, [_rec("other", origin={"kind": "task-notification"})])
    assert a2.transcript_mark(t2, "hi") is None


def test_every_origin_result_is_a_pair_the_receiver_accepts(tmp_path):
    t = _transcript(tmp_path, [_rec("x", turnOrigin="scheduled")])
    for hi in ({"prompt": "x", "transcript_path": t}, {"prompt": "[sidecar] 1 peer message waiting (ids a1)"},
               {"prompt": "y"}):
        for inter in (True, False, None):
            o, b = a2.classify_origin(hi, inter)
            assert b in a2.VALID_ORIGIN[o]
    rs = a2.reports_for("prompt", {"session_id": SID, "prompt": "y"}, agent_id=AGENT, clock=clock(),
                        interactive=None)
    # 010 msg 0d44a3d3: their meter reads a missing basis as "" (inconsistent); send "absent".
    assert rs[1]["basis"] == "absent" and rs[1]["origin"] == "unknown"


# ── transport ───────────────────────────────────────────────────────────────────

class FakeSidecar:
    """One JSON line per connection; answers with `answer(obj)`."""

    def __init__(self, path, answer):
        self.path, self.answer, self.lines = path, answer, []
        self.srv = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self.srv.bind(path)
        self.srv.listen(8)
        self.t = threading.Thread(target=self._serve, daemon=True)
        self.t.start()

    def _serve(self):
        while True:
            try:
                conn, _ = self.srv.accept()
            except OSError:
                return
            with conn:
                buf = b""
                while not buf.endswith(b"\n"):
                    chunk = conn.recv(4096)
                    if not chunk:
                        break
                    buf += chunk
                self.lines.append(buf)
                conn.sendall(json.dumps(self.answer(json.loads(buf))).encode() + b"\n")

    def close(self):
        self.srv.close()


@pytest.fixture
def sockdir():
    # AF_UNIX paths are length-limited; pytest's tmp_path can be too long.
    import tempfile
    d = tempfile.mkdtemp(prefix="a2-")
    yield d
    import shutil
    shutil.rmtree(d, ignore_errors=True)


def test_send_writes_one_newline_terminated_line_without_op_and_returns_checked_origin(sockdir):
    srv = FakeSidecar(os.path.join(sockdir, "agent-b.send.sock"),
                      lambda o: {"ok": True, "origin_checked": "automated", "basis_checked": "pty-input"}
                      if o["event"] == "prompt_submit" else {"ok": True})
    try:
        rs = a2.reports_for("prompt", {"session_id": SID, "prompt": "hi"}, agent_id=AGENT, clock=clock(),
                            interactive=True)
        replies = a2.send(rs, srv.path)
        assert [r["ok"] for r in replies] == [True, True]
        assert all(l.endswith(b"\n") and l.count(b"\n") == 1 and b'"op"' not in l for l in srv.lines)
        # the hook said human/inferred; the claim uses the receiver's downgrade
        assert rs[1]["origin"] == "human" and a2.checked_origin(rs, replies) == "automated"
    finally:
        srv.close()


def test_old_sidecar_refusal_is_retried_once_without_order_fields(sockdir):
    def answer(o):
        if "boot_id" in o:
            return {"ok": False, "code": "unknown-field", "error": 'field "boot_id" is not accepted by ready'}
        return {"ok": True}
    srv = FakeSidecar(os.path.join(sockdir, "agent-b.send.sock"), answer)
    try:
        rs = a2.reports_for("stop", {"session_id": SID}, agent_id=AGENT, clock=clock())
        assert a2.send(rs, srv.path) == [{"ok": True}, {"ok": True}]
        sent = [json.loads(l) for l in srv.lines]
        assert len(sent) == 4 and "boot_id" in sent[0] and "boot_id" not in sent[1]
    finally:
        srv.close()


def test_unreachable_sidecar_fails_open_and_claim_is_unknown(sockdir, monkeypatch):
    monkeypatch.setattr(a2, "_log_error", lambda where: None)
    rs = a2.reports_for("prompt", {"session_id": SID, "prompt": "hi"}, agent_id=AGENT, clock=clock(),
                        interactive=True)
    replies = a2.send(rs, os.path.join(sockdir, "nobody.send.sock"))
    assert replies == [None, None] and a2.checked_origin(rs, replies) == "unknown"


def test_enablement_needs_flag_and_socket(monkeypatch):
    monkeypatch.setenv("FW_TERMLINK_ADAPTER2", "1")
    monkeypatch.delenv("TERMLINK_SIDECAR_SOCKET", raising=False)
    assert not a2.enabled()
    monkeypatch.setenv("TERMLINK_SIDECAR_SOCKET", "/run/x/agent-b.send.sock")
    assert a2.enabled() and a2.agent_id_for("/run/x/agent-b.send.sock") == "agent-b"
    monkeypatch.setenv("FW_TERMLINK_ADAPTER2", "0")
    assert not a2.enabled()
    assert a2.run("stop", {"session_id": SID}) == []


# ── ordering oracle from the fixture's `about` ─────────────────────────────────

def _key(p, rx, by_at_ms=False):
    if by_at_ms:
        return ("at", p["at_ms"])
    b, n = p.get("boot_id"), p.get("mono_ns")
    ok = isinstance(b, str) and a2._BOOT_RE.match(b) and (
        (isinstance(n, str) and n.isdigit()) or (isinstance(n, int) and not isinstance(n, bool) and n >= 0))
    return (b, int(n)) if ok else ("rx", rx)


class Oracle:
    """Written from p2's `about`: within one boot the higher mono_ns is later; another boot or
    a switch between adapter order and receive stamp is later than everything before."""

    def __init__(self, by_at_ms=False):
        self.by, self.rx, self.seq = by_at_ms, 1_000_000, 0
        self.last = None              # last key seen, for boot/stamp switches
        self.ready = None             # (rank, state)
        self.prompt = None
        self.turn_stopped = False

    def _rank(self, k):
        if self.last is None or k[0] != self.last[0]:
            self.seq += 1             # a new boot or a switch: later than everything before
        self.last = k
        return (self.seq, k[1])

    def step(self, p, adv=0):
        self.rx += adv
        rank = self._rank(_key(p, self.rx, self.by))
        ev = p["event"]
        if ev == "ready":
            if self.ready and rank < self.ready[0]:
                return "dropped:ready-reordered"
            if self.ready and rank == self.ready[0] and self.ready[1] == "BUSY" and p["state"] != "BUSY":
                return "dropped:tie keeps BUSY"
            self.ready = (rank, p["state"])
            if p["state"] == "READY" and self.prompt and rank > self.prompt:
                self.turn_stopped = True
            return "applied"
        if ev == "prompt_submit":
            if self.prompt and rank < self.prompt:
                return "dropped:prompt-reordered"
            self.prompt, self.turn_stopped = rank, False
            return "applied"
        if ev == "turn_stop":
            if self.prompt and rank > self.prompt:
                self.turn_stopped = True
            return "applied"
        return "applied"


def _run_case(case, by_at_ms=False):
    o, got = Oracle(by_at_ms), []
    for st in case["steps"]:
        got.append(o.step(st["payload"], st.get("rx_advance_ms", 0)))
    return o, got


def test_oracle_matches_every_fixture_case():
    for case in P2["cases"]:
        o, got = _run_case(case)
        want = [st["expect"] for st in case["steps"]]
        assert got == want, case["name"]
        after = case.get("after", {})
        if "ready_state" in after:
            assert o.ready[1] == after["ready_state"], case["name"]
        if "turn_stopped" in case:
            assert o.turn_stopped == case["turn_stopped"], case["name"]


def test_negative_control_an_at_ms_oracle_fails_the_headline_case():
    case = next(c for c in P2["cases"] if c["name"] == "backward-wall-clock-step-does-not-freeze-ready")
    _, got = _run_case(case, by_at_ms=True)
    assert got != [st["expect"] for st in case["steps"]]


def test_our_lines_survive_a_backward_wall_clock_step():
    """Prompt, then Stop, while the wall clock steps back an hour: fed to the oracle the
    turn ends and the session is READY; the same lines ordered on at_ms would not."""
    wall = [1_700_000_000_000, 1_700_000_000_001, 1_699_996_400_000, 1_699_996_400_001]
    c = clock(boot="3f0c-boot", start=7_003_000_000_000, wall=wall)
    kw = dict(agent_id=AGENT, clock=c, interactive=True)
    lines = a2.reports_for("prompt", {"session_id": SID, "prompt": "hi"}, **kw) + \
        a2.reports_for("stop", {"session_id": SID}, **kw)
    assert lines[2]["at_ms"] < lines[1]["at_ms"]          # the wall clock really went back
    good = Oracle()
    assert [good.step(json.loads(a2.encode(r))) for r in lines] == ["applied"] * 4
    assert good.ready[1] == "READY" and good.turn_stopped
    bad = Oracle(by_at_ms=True)
    [bad.step(r) for r in lines]
    assert not (bad.ready[1] == "READY" and bad.turn_stopped)


# ── 010's answers, 2026-11-13 ───────────────────────────────────────────────────

def test_termlink_si1_line_is_automated_doorbell():
    ids = "0123456789abcdef0123456789abcdef fedcba9876543210fedcba9876543210"
    line = f"sidecar: 2 peer messages waiting, ids {ids}. The prompt hook shows them as untrusted data."
    assert a2.classify_origin({"prompt": line}, True) == ("automated", "doorbell")
    assert a2.classify_origin({"prompt": "please quote: sidecar: 2 peer messages waiting, ids x"}, True) == \
        ("human", "inferred")                                   # only a line that STARTS with it


def test_agent_id_comes_from_the_socket_env_is_only_a_cross_check(monkeypatch):
    logged = []
    monkeypatch.setattr(a2, "_log_error", lambda where: logged.append(where))
    monkeypatch.setenv("TERMLINK_AGENT_ID", "someone-else")
    assert a2.agent_id_for("/run/x/agent-b.send.sock") == "agent-b" and logged == ["agent_id"]
    monkeypatch.delenv("TERMLINK_AGENT_ID")
    assert a2.agent_id_for("/run/x/not-a-socket") is None


# ── slice 3: socket from config, the never-beside-W1 guard ──────────────────────

@pytest.fixture
def proj(tmp_path, monkeypatch):
    root = tmp_path / "p"
    (root / ".claude").mkdir(parents=True)
    (root / ".framework.yaml").write_text("project_name: p\n")
    monkeypatch.setenv("CLAUDE_PROJECT_DIR", str(root))
    monkeypatch.setenv("HOME", str(tmp_path / "home"))
    for v in ("FW_TERMLINK_ADAPTER2", "TERMLINK_SIDECAR_SOCKET", "FW_TERMLINK_SIDECAR_SOCKET"):
        monkeypatch.delenv(v, raising=False)
    return root


def test_switch_and_socket_come_from_framework_yaml(proj):
    (proj / ".framework.yaml").write_text(
        "project_name: p\nTERMLINK_ADAPTER2: '1'\nTERMLINK_SIDECAR_SOCKET: /run/t/aef.send.sock  # trial\n")
    assert a2.socket_path() == "/run/t/aef.send.sock" and a2.enabled()


def test_env_socket_wins_over_config(proj, monkeypatch):
    (proj / ".framework.yaml").write_text("TERMLINK_SIDECAR_SOCKET: /cfg/a.send.sock\n")
    monkeypatch.setenv("TERMLINK_SIDECAR_SOCKET", "/env/b.send.sock")
    assert a2.socket_path() == "/env/b.send.sock"


@pytest.mark.parametrize("where", ["project", "local", "home"])
def test_w1_hooks_anywhere_keep_the_adapter_off(proj, tmp_path, monkeypatch, where):
    monkeypatch.setattr(a2, "_log_error", lambda w: None)
    (proj / ".framework.yaml").write_text("TERMLINK_ADAPTER2: 1\nTERMLINK_SIDECAR_SOCKET: /run/t/aef.send.sock\n")
    assert a2.enabled()
    f = {"project": proj / ".claude" / "settings.json", "local": proj / ".claude" / "settings.local.json",
         "home": tmp_path / "home" / ".claude" / "settings.json"}[where]
    f.parent.mkdir(parents=True, exist_ok=True)
    f.write_text(json.dumps({"hooks": {"Stop": [{"hooks": [{"type": "command",
                                                            "command": "termlink sidecar hook stop"}]}]}}))
    assert a2.w1_hook_files() == [str(f)] and not a2.enabled()


def test_off_path_imports_no_yaml():
    import subprocess
    import sys
    p = subprocess.run([sys.executable, "-c", "import sys; import lib.sidecar.adapter2 as a; a.enabled(); "
                        "print('yaml' in sys.modules)"], cwd=ROOT, capture_output=True, text=True)
    assert p.stdout.strip() == "False", p.stderr
