"""T-3684 / T-3685 / T-3745 — LIVE proof of the sidecar watcher. Not mocked.

Real interactive Claude Code sessions launched with `claude-fw --termlink` in
scratch projects (which, since T-3684, start their own sidecar: receiver plus
supervised watcher at the DEFAULT tick, 30 s). A second scratch project, A, is
the sending peer: its own sidecar (`fw sidecar start`) and the real
`fw sidecar send`. Nobody types into the receiving session except where a test
deliberately makes it BUSY (a prompt that runs `sleep`).

Every timing assertion is computed from ledger timestamps written by the
components themselves — A's sender ledger (SENT / RECEIVED / HANDED_OVER /
ESCALATED rows) and B's receiver event ledger (STORED / INJECT_ATTEMPT /
HANDED_OVER) — never from the test's own clock alone.

  test_1_idle_session_receives_within_60s
  test_2_legacy_hub_topic_post_picked_up_within_60s
  test_3_busy_gets_non_urgent_only_after_turn_ends_urgent_while_busy
  test_4_watcher_killed_reported_not_live_and_restarted
  test_5_negative_control_watcher_disabled_no_pickup_sender_escalated
  test_6_two_sessions_one_project_idle_gets_it_busy_pty_gets_nothing   (T-3745)

Evidence: one JSON per test in $T3684_E2E_EVIDENCE_DIR (default: the scratch
base dir). Slow (~15 min) and costs real model tokens. Skipped, loudly, when
`termlink`, `claude` or tmux are absent.
"""

from __future__ import annotations

import json
import os
import random
import re
import signal
import string
import subprocess
import sys
import time
from datetime import datetime
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent))
import t3693_sidecar_e2e_test as base  # noqa: E402  (shared live helpers)

FW_ROOT = base.FW_ROOT
FW = base.FW
CLAUDE_FW = base.CLAUDE_FW
MODEL = os.environ.get("T3684_E2E_MODEL", "haiku")
BASE_DIR = Path(f"/tmp/t3684-e2e-{os.getpid()}-{int(time.time())}")
ENABLED_DIR = BASE_DIR / "sidecar-enabled"      # never the host registry the cron reads
EVIDENCE_DIR = Path(os.environ.get("T3684_E2E_EVIDENCE_DIR") or BASE_DIR)
TICK_S = 30                                       # the default; asserted from liveness.yaml

needs_live = pytest.mark.skipif(
    bool(base.MISSING),
    reason=f"T-3684 LIVE E2E NOT RUN — missing on PATH: {', '.join(base.MISSING)}. "
           "These tests are the only live proof of T-3684/T-3685/T-3745; a skip proves nothing.")
pytestmark = needs_live


def _log(msg: str) -> None:
    print(f"[t3684-e2e {time.strftime('%H:%M:%S')}] {msg}", flush=True)


def _env(**extra) -> dict:
    return base._clean_env(FW_SIDECAR_ENABLED_DIR=str(ENABLED_DIR), **extra)


def _run(argv, cwd, timeout=120, **extra) -> subprocess.CompletedProcess:
    return subprocess.run(argv, cwd=cwd, env=_env(**extra), capture_output=True,
                          text=True, timeout=timeout)


def _ts(s) -> float:
    return datetime.fromisoformat(str(s)).timestamp()


def _jsonl(p: Path) -> list[dict]:
    return base._jsonl(p)


def _ledger(root: Path) -> list[dict]:
    return _jsonl(root / ".context/sidecar/direct-ack.jsonl")


def _receipts(root: Path) -> list[dict]:
    return _jsonl(root / ".context/sidecar/receipts.jsonl")


def _events(root: Path, mid: str | None = None) -> list[dict]:
    rows = _jsonl(root / ".context/sidecar/receiver/events.jsonl")
    return [r for r in rows if mid is None or r.get("msg_id") == mid]


def _first(rows, **match):
    for r in rows:
        if all(r.get(k) == v for k, v in match.items()):
            return r
    return None


def _records(root: Path) -> list[dict]:
    d = root / ".context/sidecar/sessions"
    out = []
    for p in d.glob("*.json") if d.is_dir() else []:
        try:
            out.append(json.loads(p.read_text()))
        except (OSError, json.JSONDecodeError):
            pass
    return out


def _record_for(root: Path, tl: str) -> dict | None:
    recs = [r for r in _records(root) if r.get("termlink_session") == tl]
    recs.sort(key=lambda r: r.get("updated_at") or "")
    return recs[-1] if recs else None


def _pty(tl: str, lines: int = 400) -> str:
    return base._pty(tl, lines)


def _short(mid: str) -> str:
    return re.sub(r"[^A-Za-z0-9-]", "", mid)[:8]


def _wait(pred, timeout: float, step: float = 1.0):
    deadline = time.time() + timeout
    while time.time() < deadline:
        v = pred()
        if v:
            return v
        time.sleep(step)
    return pred()


def _evidence(name: str, ev: dict) -> None:
    EVIDENCE_DIR.mkdir(parents=True, exist_ok=True)
    (EVIDENCE_DIR / f"T-3684-e2e-{name}.json").write_text(json.dumps(ev, indent=2, default=str))
    _log(f"evidence: {EVIDENCE_DIR / f'T-3684-e2e-{name}.json'}")


# ── agents ──────────────────────────────────────────────────────────────────

class Session:
    """One `claude-fw --termlink` wrapper and the Claude session inside it."""

    def __init__(self, root: Path, label: str):
        self.root, self.label = root, label
        self.wrapper: subprocess.Popen | None = None
        self.tl: str | None = None

    def launch(self) -> None:
        log = BASE_DIR / f"{self.root.name}-{self.label}.claude-fw.log"
        self.wrapper = subprocess.Popen(
            [CLAUDE_FW, "--termlink", "--no-restart", "--model", MODEL, "hello"],
            cwd=self.root, env=_env(), stdin=subprocess.DEVNULL,
            stdout=open(log, "wb"), stderr=subprocess.STDOUT, start_new_session=True)
        self.log = log

    def bring_up(self, timeout: float = 180) -> None:
        name = f"claude-master-{self.wrapper.pid}"
        deadline = time.time() + timeout
        trusted = False
        while time.time() < deadline:
            if self.tl is None:
                out = subprocess.run(["termlink", "discover", "--json"], capture_output=True,
                                     text=True, timeout=15, env=base._clean_env())
                try:
                    for s in json.loads(out.stdout).get("sessions", []):
                        if s.get("display_name") == name:
                            self.tl = s["id"]
                except json.JSONDecodeError:
                    pass
            if self.tl:
                screen = re.sub(r"\s+", "", _pty(self.tl, 40))
                if not trusted and "trustthisfolder" in screen:
                    base._key(self.tl, "Down")
                    time.sleep(0.5)
                    base._key(self.tl, "Enter")
                    trusted = True
                    _log(f"{self.label}: accepted folder trust")
                rec = _record_for(self.root, self.tl)
                if rec and rec.get("ready"):
                    _log(f"{self.label}: {self.tl} ready (its own Stop hook, session {rec['session_id']})")
                    return
            time.sleep(2)
        raise AssertionError(f"{self.label} never became ready; tl={self.tl}; "
                             f"records={_records(self.root)}; pty={_pty(self.tl, 30) if self.tl else '-'}; "
                             f"log={self.log.read_text()[-1500:]}")

    def ready(self) -> bool:
        rec = _record_for(self.root, self.tl) if self.tl else None
        return bool(rec and rec.get("ready"))

    def make_busy(self, seconds: int) -> float:
        """Type a prompt that keeps the session in one turn for `seconds`.
        Returns when the session's own record says busy."""
        # FOREGROUND, explicitly: run 1 showed haiku choosing run_in_background,
        # which ends the turn at once and makes "busy" a 6-second window.
        # Run 2: Claude Code's Bash tool refuses a bare `sleep N` ("use
        # Monitor…"), so the wait is a python one-liner the harness runs as-is.
        cmd = f"python3 -c 'import time; time.sleep({seconds}); print(42)'"
        base._type(self.tl, f"Use the Bash tool with run_in_background set to false and "
                            f"timeout 300000 to run exactly this command in the FOREGROUND: "
                            f"{cmd} . Wait for it to finish. Then reply with the "
                            "single word done and end your turn.")
        assert _wait(lambda: not self.ready(), 30, 0.5), f"{self.label} never went busy"
        _wait(lambda: f"time.sleep({seconds})" in _pty(self.tl, 60), 60, 1)
        started = time.time()
        time.sleep(8)
        assert not self.ready(), (f"{self.label} ended its turn within 8 s of a foreground "
                                  f"sleep {seconds} — the busy precondition does not hold; "
                                  f"pty: {_pty(self.tl, 30)}")
        return started

    def teardown(self) -> None:
        if self.tl:
            subprocess.run(["termlink", "pty", "inject", self.tl, "/exit", "--enter"],
                           capture_output=True, timeout=15, env=base._clean_env())
        time.sleep(3)
        if self.wrapper and self.wrapper.poll() is None:
            try:
                os.killpg(self.wrapper.pid, signal.SIGTERM)
                self.wrapper.wait(timeout=20)
            except (ProcessLookupError, subprocess.TimeoutExpired):
                try:
                    os.killpg(self.wrapper.pid, signal.SIGKILL)
                except ProcessLookupError:
                    pass
        if self.tl:
            subprocess.run(["termlink", "signal", self.tl, "SIGTERM"], capture_output=True,
                           timeout=15, env=base._clean_env())


def _scratch(name: str) -> Path:
    return base._project(BASE_DIR, name)


def _send(a_root: Path, to: str, body: str, *, urgent=False, deadline=900,
          registry: Path | None = None) -> dict:
    argv = [FW, "sidecar", "send", "--to", to, "--body", body, "--conversation",
            f"t3684-{to}", "--handover-deadline", str(deadline), "--json"]
    if urgent:
        argv.append("--urgent")
    extra = {"FW_SIDECAR_REGISTRY_DIR": str(registry)} if registry else {}
    t = time.time()
    proc = _run(argv, a_root, **extra)
    assert proc.returncode == 0, proc.stdout + proc.stderr
    out = json.loads(proc.stdout.strip().splitlines()[-1])
    out["_sent_wallclock"] = t
    return out


def _msg_id_in_b(b_root: Path, needle: str) -> str | None:
    for p in (b_root / ".context/sidecar/receiver/messages").glob("*.json"):
        msg = json.loads(p.read_text())
        if needle in str(msg.get("body", "")):
            return msg["client_msg_id"]
    return None


@pytest.fixture(scope="module")
def pair():
    """Sender A (sidecar only) and receiver B (one real claude-fw --termlink
    session, which starts B's sidecar itself)."""
    BASE_DIR.mkdir(parents=True, exist_ok=True)
    run = "".join(random.choices(string.ascii_lowercase + string.digits, k=6))
    a_root, b_root = _scratch(f"t3684a-{run}"), _scratch(f"t3684b-{run}")
    proc = _run([FW, "sidecar", "start"], a_root)
    assert proc.returncode == 0, proc.stdout + proc.stderr
    b = Session(b_root, "B")
    b.launch()
    try:
        b.bring_up()
        log = b.log.read_text()
        assert "sidecar watcher running" in log, log[-2000:]
        lv = json.loads(_run([FW, "sidecar", "liveness", "--json"], b_root).stdout)
        assert lv["state"] == "live" and lv["liveness"]["tick_s"] == TICK_S, lv
        yield {"run": run, "a": a_root, "b": b_root, "B": b,
               "a_name": a_root.name, "b_name": b_root.name}
    finally:
        b.teardown()
        for root in (a_root, b_root):
            _run([FW, "sidecar", "stop", "--quiet"], root)


def _handed_over_within(pair, mid: str, sent_at: float, limit: float, wait: float):
    b_root = pair["b"]
    got = _wait(lambda: _first(_events(b_root, mid), event="HANDED_OVER"), wait, 1)
    assert got, f"no HANDED_OVER for {mid}: events={_events(b_root, mid)}"
    lat = _ts(got["ts"]) - sent_at
    return got, lat


def test_1_idle_session_receives_within_60s(pair):
    b, a = pair["B"], pair["a"]
    assert _wait(b.ready, 60), "B not idle"
    time.sleep(3)
    nonce = "".join(random.choices(string.ascii_lowercase, k=10))
    res = _send(a, pair["b_name"], f"Peer check IDLE-{nonce}: no action and no reply needed; "
                                    "just end your turn.")
    cid = res["client_msg_id"]
    sent = _first(_ledger(a), client_msg_id=cid, state="SENT")
    got, lat = _handed_over_within(pair, cid, _ts(sent["ts"]), 60, 90)
    recv = _first(_ledger(a), client_msg_id=cid, state="RECEIVED")
    a_ho = _wait(lambda: _first(_ledger(a), client_msg_id=cid, state="HANDED_OVER"), 30, 1)
    surfaced = base._surfaced_in_transcript(pair["b"], f"IDLE-{nonce}")
    ev = {"msg": cid, "send_to_received_s": _ts(recv["ts"]) - _ts(sent["ts"]),
          "send_to_handed_over_s": lat, "sender_ledger_handed_over": a_ho,
          "b_events": _events(pair["b"], cid), "transcript": surfaced}
    _evidence("1-idle", ev)
    assert lat <= 60, ev
    assert a_ho and a_ho["by"].startswith("peer-receiver:"), ev     # CONFIRM-2 reached the sender
    assert surfaced, ev                                             # the model was given it


def test_2_legacy_hub_topic_post_picked_up_within_60s(pair):
    """Posted the pre-receiver way: A's send with NO receiver registry entry
    for B falls back to the hub inbox topic (what a 1.7.740 peer does). Only
    B's watcher tick can pick it up."""
    b, a = pair["B"], pair["a"]
    assert _wait(b.ready, 120), "B not idle"
    nonce = "".join(random.choices(string.ascii_lowercase, k=10))
    empty = BASE_DIR / "empty-registry"
    empty.mkdir(exist_ok=True)
    res = _send(a, pair["b_name"], f"Peer check LEGACY-{nonce}: no action and no reply needed; "
                                    "just end your turn.", registry=empty)
    assert res.get("topic") and res.get("delivered"), res          # it went to the hub topic
    mid = _wait(lambda: _msg_id_in_b(pair["b"], f"LEGACY-{nonce}"), 70, 1)
    assert mid, "watcher never ingested the hub-topic consult"
    msg = json.loads((pair["b"] / f".context/sidecar/receiver/messages/{mid}.json").read_text())
    hub_ts = msg["hub_ts"]
    sent_at = hub_ts / 1000 if isinstance(hub_ts, (int, float)) and hub_ts > 1e11 else _ts(hub_ts)
    got, lat = _handed_over_within(pair, mid, sent_at, 60, 90)
    inj = [e for e in _events(pair["b"], mid) if e["event"] == "INJECT_ATTEMPT" and e.get("ok")]
    ingest = _first(_events(pair["b"], mid), event="INGESTED_FROM_HUB")
    # Receipts at the SENDER (operator 2026-10-03): RECEIVED at once, then
    # HANDED_OVER — rows in A's receipts ledger, timed from A's own outbox.
    a_sent = _ts(json.loads((a / f".context/sidecar/outbox/{mid}.json").read_text())["created_at"])
    rcpt = lambda st: _first(_receipts(a), client_msg_id=mid, state=st)  # noqa: E731
    a_recv = _wait(lambda: rcpt("RECEIVED"), 60, 1)
    a_ho = _wait(lambda: rcpt("HANDED_OVER"), 60, 1)
    ev = {"msg": mid, "via": msg.get("via"), "hub_ts": hub_ts,
          "send_to_received_s": _ts(ingest["ts"]) - sent_at, "send_to_handed_over_s": lat,
          "inject_triggers": [e["trigger"] for e in inj], "b_events": _events(pair["b"], mid),
          "transcript": base._surfaced_in_transcript(pair["b"], f"LEGACY-{nonce}"),
          "sender_receipt_received": a_recv, "sender_receipt_handed_over": a_ho,
          "sender_send_to_received_s": a_recv and _ts(a_recv["ts"]) - a_sent,
          "sender_send_to_handed_over_s": a_ho and _ts(a_ho["ts"]) - a_sent}
    _evidence("2-legacy-topic", ev)
    assert msg.get("via") == "hub-topic" and inj and inj[0]["trigger"] == "tick", ev
    assert lat <= 60, ev
    assert ev["transcript"], ev
    assert a_recv and ev["sender_send_to_received_s"] <= 60, ev
    assert a_ho and a_ho["by"] == f"peer:{pair['b_name']}", ev


def test_2b_legacy_consult_answered_with_in_reply_to_gives_sender_replied(pair):
    b, a = pair["B"], pair["a"]
    assert _wait(b.ready, 120), "B not idle"
    nonce = "".join(random.choices(string.ascii_lowercase, k=10))
    empty = BASE_DIR / "empty-registry"
    empty.mkdir(exist_ok=True)
    _send(a, pair["b_name"], f"Peer check REPLY-{nonce}: answer me now by running the reply "
                             "command shown under this message, with the body pong. "
                             "Nothing else.", registry=empty)
    mid = _wait(lambda: _msg_id_in_b(pair["b"], f"REPLY-{nonce}"), 70, 1)
    assert mid, "watcher never ingested the hub-topic consult"
    a_sent = _ts(json.loads((a / f".context/sidecar/outbox/{mid}.json").read_text())["created_at"])
    got = {st: _wait(lambda st=st: _first(_receipts(a), client_msg_id=mid, state=st), 180, 1)
           for st in ("RECEIVED", "HANDED_OVER", "REPLIED")}
    lat = json.loads(_run([FW, "sidecar", "latency", "--json"], a).stdout)
    row = [m for m in lat["outbound"]["messages"] if m["client_msg_id"] == mid]
    ev = {"msg": mid, "receipts": got, "latency_row": row,
          "sender_send_to_s": {st: got[st] and _ts(got[st]["ts"]) - a_sent for st in got},
          "b_receipts_sent": [r for r in _jsonl(pair["b"] / ".context/sidecar/receipts-sent.jsonl")
                              if r.get("client_msg_id") == mid]}
    _evidence("2b-replied", ev)
    assert all(got.values()), ev
    assert row and row[0]["path"] == "hub" and row[0]["send_to_replied_s"] is not None, ev


def test_3_busy_gets_non_urgent_only_after_turn_ends_urgent_while_busy(pair):
    b, a = pair["B"], pair["a"]
    assert _wait(b.ready, 120), "B not idle"
    busy_since = b.make_busy(90)
    n_nonce = "".join(random.choices(string.ascii_lowercase, k=10))
    n = _send(a, pair["b_name"], f"Peer check BUSY-{n_nonce}: no action and no reply needed.")
    time.sleep(6)
    nid = n["client_msg_id"]
    assert not b.ready()
    early = [e for e in _events(pair["b"], nid) if e["event"] == "INJECT_ATTEMPT"]
    assert early == [], f"non-urgent injected into a busy session: {early}"
    assert _short(nid) not in _pty(b.tl), "busy session's PTY received the non-urgent line"

    u_nonce = "".join(random.choices(string.ascii_lowercase, k=10))
    u = _send(a, pair["b_name"], f"Peer check URGENT-{u_nonce}: no action and no reply needed.",
              urgent=True)
    uid = u["client_msg_id"]
    u_inj = _wait(lambda: _first(_events(pair["b"], uid), event="INJECT_ATTEMPT", ok=True), 40, 0.5)
    busy_at_urgent = not b.ready()
    pty_has_urgent = _short(uid) in _pty(b.tl)
    assert u_inj, f"urgent never injected: {_events(pair['b'], uid)}"

    # the turn ends (sleep 90 + the reply) → B's own Stop → the tick injects N
    turn_end = _wait(lambda: b.ready() and time.time(), 240, 0.5)
    assert turn_end, "B's turn never ended"
    n_inj = _wait(lambda: _first(_events(pair["b"], nid), event="INJECT_ATTEMPT", ok=True), 120, 1)
    n_ho = _wait(lambda: _first(_events(pair["b"], nid), event="HANDED_OVER"), 120, 1)
    u_ho = _wait(lambda: _first(_events(pair["b"], uid), event="HANDED_OVER"), 120, 1)
    n_sent = _ts(_first(_ledger(a), client_msg_id=nid, state="SENT")["ts"])
    u_sent = _ts(_first(_ledger(a), client_msg_id=uid, state="SENT")["ts"])
    ev = {"busy_since": busy_since, "turn_end_observed": turn_end,
          "non_urgent": {"msg": nid, "inject": n_inj, "handed_over": n_ho,
                         "send_to_inject_s": n_inj and _ts(n_inj["ts"]) - n_sent,
                         "turn_end_to_inject_s": n_inj and _ts(n_inj["ts"]) - turn_end,
                         "send_to_handed_over_s": n_ho and _ts(n_ho["ts"]) - n_sent},
          "urgent": {"msg": uid, "inject": u_inj, "busy_at_inject": busy_at_urgent,
                     "pty_has_line_while_busy": pty_has_urgent, "handed_over": u_ho,
                     "send_to_inject_s": _ts(u_inj["ts"]) - u_sent,
                     "send_to_handed_over_s": u_ho and _ts(u_ho["ts"]) - u_sent},
          "b_events": _events(pair["b"])[-40:]}
    _evidence("3-busy-urgent", ev)
    assert u_inj.get("urgent_bypass") is True and busy_at_urgent and pty_has_urgent, ev
    assert _ts(u_inj["ts"]) < turn_end, ev                       # injected while busy
    assert n_inj and _ts(n_inj["ts"]) >= turn_end - 1.5, ev       # only after the turn ended
    assert n_inj["trigger"] == "tick", ev                         # on-store saw it busy; the tick delivered
    assert n_ho, ev


def _doctor_line(root: Path) -> str:
    out = _run([FW, "doctor"], root, timeout=600)
    return "\n".join(l for l in (out.stdout + out.stderr).splitlines() if "Sidecar watcher" in l)


def _audit_lines(root: Path) -> str:
    out = _run([FW, "audit"], root, timeout=900)
    lines = (out.stdout + out.stderr).splitlines()
    return "\n".join(l for i, l in enumerate(lines) if "Sidecar watcher" in l
                     or (i and "Sidecar watcher" in lines[i - 1]))


def test_4_watcher_killed_reported_not_live_and_restarted(pair):
    b_root = pair["b"]
    wdir = b_root / ".context/sidecar/watcher"
    pid = lambda w: int((wdir / f"{w}.pid").read_text())  # noqa: E731
    liveness = lambda: json.loads(_run([FW, "sidecar", "liveness", "--json"], b_root).stdout)["state"]  # noqa: E731
    # (a) SIGKILL the watcher alone: its supervisor respawns it within seconds
    w1 = pid("watcher")
    os.kill(w1, signal.SIGKILL)
    assert _wait(lambda: pid("watcher") != w1, 15, 0.5), "supervisor did not respawn the watcher"
    # (a2) the watcher is HUNG (SIGSTOP — alive, ticking nothing). Nobody acts:
    #      doctor and audit report it not live after 2 ticks, and the
    #      supervisor itself replaces it one tick later.
    assert _wait(lambda: liveness() == "live", 2 * TICK_S, 2)
    w_hung = pid("watcher")
    os.kill(w_hung, signal.SIGSTOP)
    hung_at = time.time()
    assert _wait(lambda: liveness() == "not-live", 2 * TICK_S + 20, 2)
    doctor_hung = _doctor_line(b_root)
    audit_hung = _audit_lines(b_root)
    healed = _wait(lambda: pid("watcher") != w_hung and liveness() == "live", 3 * TICK_S + 30, 2)
    healed_after_s = time.time() - hung_at
    hung_killed = [e for e in _jsonl(wdir / "events.jsonl")
                   if e.get("event") == "WATCHER_HUNG_KILLED" and e.get("pid") == w_hung]
    try:
        os.kill(w_hung, signal.SIGKILL)       # in case it was not reaped
    except ProcessLookupError:
        pass
    # (b) kill supervisor AND watcher: nothing ticks; doctor and audit say not live
    s2, w2 = pid("supervisor"), pid("watcher")
    os.kill(s2, signal.SIGKILL)
    os.kill(w2, signal.SIGKILL)
    killed_at = time.time()
    assert _wait(lambda: json.loads(_run([FW, "sidecar", "liveness", "--json"], b_root).stdout)
                 ["state"] == "not-live", 2 * TICK_S + 30, 2)
    doctor = _doctor_line(b_root)
    audit = _audit_lines(b_root)
    # (c) the keep-alive (the cron command) restarts the supervisor
    ens = _run([FW, "sidecar", "ensure", "--all", "--json"], b_root)
    back = _wait(lambda: json.loads(_run([FW, "sidecar", "liveness", "--json"], b_root).stdout)
                 ["state"] == "live", 30, 1)
    doctor_after = _doctor_line(b_root)
    ev = {"respawned_watcher": [w1, pid("watcher")], "killed_at": killed_at,
          "hung": {"pid": w_hung, "doctor": doctor_hung, "audit": audit_hung,
                   "healed_by_supervisor": bool(healed), "healed_after_s": healed_after_s,
                   "hung_killed_event": hung_killed},
          "doctor_not_live": doctor, "audit_not_live": audit, "ensure": ens.stdout,
          "doctor_after_ensure": doctor_after,
          "watcher_events": _jsonl(wdir / "events.jsonl")[-20:]}
    _evidence("4-kill", ev)
    assert "FAIL" in doctor_hung and "NOT live" in doctor_hung, ev
    assert "[FAIL] Sidecar watcher NOT live" in audit_hung, ev
    assert healed and hung_killed, ev
    assert "FAIL" in doctor and "NOT live" in doctor, ev
    assert "[FAIL] Sidecar watcher NOT live" in audit, ev
    assert "supervisor restarted" in ens.stdout and back, ev
    assert "OK" in doctor_after and "live" in doctor_after, ev


def test_5_negative_control_watcher_disabled_no_pickup_sender_escalated(pair):
    """Same busy-then-idle shape as test 3, with B's watcher stopped (receiver
    kept). Nothing may inject once B goes idle, and A — whose own watcher runs
    the deadline — must read ESCALATED, not silence. The legacy-topic leg gets
    no pickup either."""
    b, a, b_root = pair["B"], pair["a"], pair["b"]
    assert _wait(b.ready, 120)
    assert _run([FW, "sidecar", "stop", "--quiet"], b_root).returncode == 0
    assert _run([FW, "sidecar", "receiver", "start", "--no-watcher", "--quiet"], b_root).returncode == 0
    assert json.loads(_run([FW, "sidecar", "liveness", "--json"], b_root).stdout)["state"] == "absent"
    try:
        b.make_busy(40)
        nonce = "".join(random.choices(string.ascii_lowercase, k=10))
        res = _send(a, pair["b_name"], f"Peer check NEG-{nonce}: no action needed.", deadline=90)
        cid = res["client_msg_id"]
        empty = BASE_DIR / "empty-registry"
        empty.mkdir(exist_ok=True)
        _send(a, pair["b_name"], f"Peer check NEGLEGACY-{nonce}: no action needed.", registry=empty)
        assert _wait(b.ready, 180), "B's turn never ended"
        escalated = _wait(lambda: _first(_ledger(a), client_msg_id=cid, state="ESCALATED"),
                          90 + 2 * TICK_S + 30, 2)
        ev = {"msg": cid, "sender_states": [r["state"] for r in _ledger(a) if r["client_msg_id"] == cid],
              "escalated_row": escalated, "b_events": _events(b_root, cid),
              "legacy_ingested": _msg_id_in_b(b_root, f"NEGLEGACY-{nonce}")}
        _evidence("5-negative-control", ev)
        assert not [e for e in _events(b_root, cid) if e["event"] in ("INJECT_ATTEMPT", "HANDED_OVER")], ev
        assert escalated and escalated["by"] == "infrastructure", ev
        assert "HANDED_OVER" not in ev["sender_states"], ev
        assert ev["legacy_ingested"] is None, ev
    finally:
        _run([FW, "sidecar", "start", "--quiet"], b_root)


def test_6_two_sessions_one_project_idle_gets_it_busy_pty_gets_nothing(pair):
    """T-3745: two real claude-fw --termlink sessions in ONE project. One busy,
    one idle; a non-urgent consult lands in the idle one only."""
    a = pair["a"]
    c_root = _scratch(f"t3684c-{pair['run']}")
    c1, c2 = Session(c_root, "C1"), Session(c_root, "C2")
    try:
        c1.launch()
        c1.bring_up()
        c2.launch()
        c2.bring_up()
        assert c1.tl != c2.tl
        c1.make_busy(90)
        assert c2.ready() and not c1.ready()
        nonce = "".join(random.choices(string.ascii_lowercase, k=10))
        res = _send(a, c_root.name, f"Peer check TWO-{nonce}: no action and no reply needed.")
        cid = res["client_msg_id"]
        ho = _wait(lambda: _first(_events(c_root, cid), event="HANDED_OVER"), 90, 1)
        inj = _first(_events(c_root, cid), event="INJECT_ATTEMPT", ok=True)
        c1_busy_still = not c1.ready()
        c1_pty, c2_pty = _pty(c1.tl), _pty(c2.tl)
        c2_sid = _record_for(c_root, c2.tl)["session_id"]
        ev = {"msg": cid, "c1": c1.tl, "c2": c2.tl, "c2_session_id": c2_sid,
              "inject": inj, "handed_over": ho, "c1_busy_at_check": c1_busy_still,
              "c1_pty_has_line": _short(cid) in c1_pty, "c2_pty_has_line": _short(cid) in c2_pty,
              "c1_pty_has_any_sidecar_line": "[sidecar]" in c1_pty,
              "events": _events(c_root, cid)}
        _evidence("6-two-sessions", ev)
        assert inj and inj["session"] == c2.tl and inj["target_session_id"] == c2_sid, ev
        assert ho and ho["evidence"] == f"transcript:{c2_sid}.jsonl", ev
        assert ev["c2_pty_has_line"] and not ev["c1_pty_has_line"], ev
        assert not ev["c1_pty_has_any_sidecar_line"], ev
        assert c1_busy_still, ev
    finally:
        for s in (c1, c2):
            s.teardown()
        _run([FW, "sidecar", "stop", "--quiet"], c_root)
