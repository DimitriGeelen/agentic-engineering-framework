"""T-3684 / T-3685 — the always-on sidecar watcher: tick, liveness, supervision.

Real processes where the behaviour is about processes: the receiver, the
supervisor and the watcher are started through the CLI and killed with real
signals. The one stand-in is the `termlink` binary inside single-tick tests
(a recorded runner, and a recorded hub reader for the legacy topic). The live
legs — real Claude sessions, real TermLink, real hub — are
tests/integration/t3684_sidecar_watcher_e2e_test.py.
"""

from __future__ import annotations

import io
import json
import os
import signal
import subprocess
import sys
import time
from datetime import datetime, timedelta, timezone
from pathlib import Path

import pytest

FW_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(FW_ROOT))

from lib.sidecar import adapter, direct, hooks, inject, latency, lifecycle, receipts, receiver, watcher  # noqa: E402

CLI = [sys.executable, str(FW_ROOT / "lib" / "sidecar_cli.py")]
NO_TERMLINK_PATH = "/usr/bin:/bin"   # termlink lives in /usr/local/bin and ~/.local/bin here


@pytest.fixture
def proj(tmp_path, monkeypatch):
    root = tmp_path / "t3684"
    (root / ".context").mkdir(parents=True)
    (root / ".framework.yaml").write_text("project_name: t3684\n")
    monkeypatch.setenv("PROJECT_ROOT", str(root))
    monkeypatch.setenv("FW_SIDECAR_AGENT_ID", "t3684")
    monkeypatch.delenv("FW_SIDECAR_TICK", raising=False)
    monkeypatch.delenv("FW_REVIEW_WORKER", raising=False)
    monkeypatch.delenv("TERMLINK_SESSION_ID", raising=False)
    # Not headless whoever runs the suite (a `claude -p` worker would be, and a
    # headless session is never an inject target — T-3684 round 3).
    monkeypatch.setattr(adapter, "_claude_ancestor_pid", lambda *a, **k: None)
    yield root
    _cli(root, "stop", "--quiet")


def _cli(root, *args, path=None, timeout=90):
    e = dict(os.environ, PROJECT_ROOT=str(root))
    if path:
        e["PATH"] = path
    return subprocess.run(CLI + list(args), cwd=root, env=e, capture_output=True,
                          text=True, timeout=timeout)


def _wait(pred, timeout=20.0, step=0.2):
    deadline = time.time() + timeout
    while time.time() < deadline:
        v = pred()
        if v:
            return v
        time.sleep(step)
    return pred()


class Termlink:
    def __init__(self, sessions):
        self.sessions, self.injects = sessions, []

    def __call__(self, argv, **_):
        if argv[1] == "discover":
            return subprocess.CompletedProcess(argv, 0, json.dumps({"sessions": self.sessions}), "")
        self.injects.append(argv)
        return subprocess.CompletedProcess(argv, 0, "", "")


def _tagged(*ids):
    return [{"id": i, "tags": ["claude", inject.project_tag()], "metadata": {}} for i in ids]


def _stop_hook(monkeypatch, sid, tl):
    monkeypatch.setenv("TERMLINK_SESSION_ID", tl)
    hooks.stop({"session_id": sid, "transcript_path": f"/tr/{sid}.jsonl"})
    monkeypatch.delenv("TERMLINK_SESSION_ID")


# ── configuration ───────────────────────────────────────────────────────────

def test_tick_default_30_env_and_framework_yaml(proj, monkeypatch):
    assert watcher.tick_seconds() == 30
    (proj / ".framework.yaml").write_text("project_name: t3684\nSIDECAR_TICK: 12\n")
    assert watcher.tick_seconds() == 12
    monkeypatch.setenv("FW_SIDECAR_TICK", "7")
    assert watcher.tick_seconds() == 7
    assert watcher.tick_seconds(3) == 3
    monkeypatch.setenv("FW_SIDECAR_TICK", "0")          # < 1 is refused, not spun on
    assert watcher.tick_seconds() == 12


def test_sidecar_tick_is_a_registered_config_key():
    out = subprocess.run(["bash", "-c", f"source {FW_ROOT}/lib/config.sh; fw_config SIDECAR_TICK"],
                         capture_output=True, text=True, env={"PATH": os.environ["PATH"]})
    assert out.stdout.strip() == "30"
    assert '"SIDECAR_TICK|30|' in (FW_ROOT / "lib" / "config.sh").read_text()


# ── one tick ────────────────────────────────────────────────────────────────

def test_tick_injects_into_the_ready_session_and_writes_liveness(proj, monkeypatch):
    assert _cli(proj, "receiver", "start", "--no-watcher", "--agent", "t3684").returncode == 0
    _stop_hook(monkeypatch, "sess-1", "tl-1")
    receiver.store_message("m1", {"client_msg_id": "m1", "from": "peer", "body": "x",
                                  "conversation_id": "c"})
    tl = Termlink(_tagged("tl-1"))
    rep = watcher.run_tick(41, 30.0, runner=tl, hub_reader=lambda *a, **k: [])
    assert rep["deliver"]["injected"] == ["m1"] and tl.injects[0][3] == "tl-1"
    live = watcher.read_liveness()
    assert live["seq"] == 41 and live["identity"] == "t3684"
    assert live["last_probe_ok"] is True and live["last_probe_latency_ms"] > 0
    assert set(watcher._LIVENESS_KEYS) <= set(live)
    ev = [e for e in receiver.read_events("m1") if e["event"] == "INJECT_ATTEMPT"][0]
    assert ev["trigger"] == "tick"


def test_tick_never_types_into_a_busy_session(proj, monkeypatch):
    _stop_hook(monkeypatch, "sess-1", "tl-1")
    monkeypatch.setenv("TERMLINK_SESSION_ID", "tl-1")
    hooks.prompt({"session_id": "sess-1"}, out=io.StringIO(), spawn=False)   # busy
    monkeypatch.delenv("TERMLINK_SESSION_ID")
    receiver.store_message("m1", {"client_msg_id": "m1", "from": "p", "body": "x"})
    tl = Termlink(_tagged("tl-1"))
    rep = watcher.run_tick(1, 30.0, runner=tl, hub_reader=lambda *a, **k: [])
    assert tl.injects == [] and "not ready" in rep["deliver"]["reason"]


def test_urgent_injects_on_the_tick_while_busy(proj, monkeypatch):
    _stop_hook(monkeypatch, "sess-1", "tl-1")
    monkeypatch.setenv("TERMLINK_SESSION_ID", "tl-1")
    hooks.prompt({"session_id": "sess-1"}, out=io.StringIO(), spawn=False)   # busy
    monkeypatch.delenv("TERMLINK_SESSION_ID")
    receiver.store_message("u1", {"client_msg_id": "u1", "from": "p", "body": "x", "urgent": True})
    tl = Termlink(_tagged("tl-1"))
    rep = watcher.run_tick(1, 30.0, runner=tl, hub_reader=lambda *a, **k: [])
    assert rep["deliver"]["injected"] == ["u1"]


def test_probe_fails_without_a_receiver_and_verdict_is_not_live(proj):
    watcher.enable("t3684", 30, True)
    rep = watcher.run_tick(1, 30.0, runner=Termlink([]), hub_reader=lambda *a, **k: [])
    assert rep["probe"]["ok"] is False and "receiver not running" in rep["probe"]["reason"]
    v = watcher.liveness_verdict()
    assert v["state"] == "not-live" and any("self-probe failed" in r for r in v["reasons"])


def test_verdict_stalled_seq_absent_and_never_ticked(proj):
    assert watcher.liveness_verdict()["state"] == "absent"
    watcher.enable("t3684", 2, True)
    v = watcher.liveness_verdict()
    assert v["state"] == "not-live" and "never" in v["reasons"][0]
    watcher.write_liveness({"identity": "t3684", "seq": 5, "last_probe_ok": True,
                            "updated_at": datetime.now(timezone.utc).isoformat(), "tick_s": 2})
    assert watcher.liveness_verdict()["state"] == "live"
    later = datetime.now(timezone.utc) + timedelta(seconds=2 * 2 + watcher.STALL_GRACE_S + 1)
    v = watcher.liveness_verdict(now=later)
    assert v["state"] == "not-live" and "seq stalled at 5" in v["reasons"][0]


def test_tick_escalates_our_own_expired_sends(proj):
    direct.record("x1", direct.SENT, by="sender", target="peer")
    past = (datetime.now(timezone.utc) - timedelta(seconds=5)).isoformat()
    direct.record("x1", direct.RECEIVED, by="receiver-response", deadline=past)
    rep = watcher.run_tick(1, 30.0, runner=Termlink([]), hub_reader=lambda *a, **k: [])
    assert rep["escalated"] == ["x1"] and direct.latest_state("x1") == direct.ESCALATED


# ── legacy hub topic ────────────────────────────────────────────────────────

def _hub_envelope(offset, cmid, body):
    import base64
    return {"offset": offset, "ts": int(time.time() * 1000) - 5000,
            "payload_b64": base64.b64encode(body.encode()).decode(),
            "metadata": {"client_msg_id": cmid, "from_agent": "old-peer",
                         "conversation_id": "legacy-c"}}


def test_legacy_topic_consult_is_ingested_once_and_injected(proj, monkeypatch):
    posted = {}

    def reader(topic, cursor, limit=100):
        return [e for e in posted.get(topic, []) if e["offset"] >= cursor]
    monkeypatch.setattr(watcher.inbox, "read_topics", lambda agent=None: ["sidecar:t3684"])
    posted["sidecar:t3684"] = [_hub_envelope(0, "legacy-1", "old-style consult")]
    _stop_hook(monkeypatch, "sess-1", "tl-1")
    tl = Termlink(_tagged("tl-1"))
    rep = watcher.run_tick(1, 30.0, runner=tl, hub_reader=reader)
    assert rep["hub"]["ingested"] == ["legacy-1"]
    assert rep["deliver"]["injected"] == ["legacy-1"]
    msg = receiver.read_message("legacy-1")
    assert msg["via"] == "hub-topic" and msg["body"] == "old-style consult"
    assert msg["from"] == "old-peer" and msg["hub_ts"]
    # the cursor moved: a second tick ingests nothing
    assert watcher.run_tick(2, 30.0, runner=tl, hub_reader=reader)["hub"]["ingested"] == []


def test_urgent_hub_topic_consult_is_injected_on_the_tick_while_busy(proj, monkeypatch):
    # R5 over the hub fallback: urgent=1 metadata → ingest keeps urgency → the
    # same tick types it into a BUSY session; a non-urgent one beside it waits.
    posted = {}

    def reader(topic, cursor, limit=100):
        return [e for e in posted.get(topic, []) if e["offset"] >= cursor]
    monkeypatch.setattr(watcher.inbox, "read_topics", lambda agent=None: ["sidecar:t3684"])
    urgent = _hub_envelope(0, "hub-urgent", "urgent over the hub")
    urgent["metadata"]["urgent"] = "1"
    posted["sidecar:t3684"] = [urgent, _hub_envelope(1, "hub-plain", "not urgent")]
    _stop_hook(monkeypatch, "sess-1", "tl-1")
    monkeypatch.setenv("TERMLINK_SESSION_ID", "tl-1")
    hooks.prompt({"session_id": "sess-1"}, out=io.StringIO(), spawn=False)   # busy
    monkeypatch.delenv("TERMLINK_SESSION_ID")
    tl = Termlink(_tagged("tl-1"))
    rep = watcher.run_tick(1, 30.0, runner=tl, hub_reader=reader)
    assert sorted(rep["hub"]["ingested"]) == ["hub-plain", "hub-urgent"]
    assert receiver.read_message("hub-urgent")["urgent"] is True
    assert receiver.read_message("hub-plain")["urgent"] is False
    assert rep["deliver"]["injected"] == ["hub-urgent"]


def test_legacy_sender_gets_a_handed_over_receipt_not_a_skip(proj, monkeypatch):
    receiver.store_message("legacy-2", {"client_msg_id": "legacy-2", "from": "old-peer",
                                        "body": "b", "via": "hub-topic"})
    sent = []
    monkeypatch.setattr(receipts, "send", lambda env, st, by, **k: sent.append((env["client_msg_id"], st, by)))
    hooks._confirm("legacy-2", receiver.read_message("legacy-2"), "t3684")
    assert sent == [("legacy-2", "HANDED_OVER", "prompt-hook")]


def test_hub_skipped_visibly_when_termlink_absent(proj, monkeypatch):
    monkeypatch.setattr(watcher.shutil, "which", lambda _b: None)
    assert watcher.ingest_hub() == {"skipped": "termlink absent", "ingested": []}


# ── supervision (real processes, real signals) ──────────────────────────────

def _pid(root, which):
    try:
        return int((root / ".context/sidecar/watcher" / f"{which}.pid").read_text())
    except (OSError, ValueError):
        return None


def _alive(pid):
    return lifecycle.pid_alive(pid)


def test_start_supervises_restarts_and_ensure_recovers(proj):
    out = _cli(proj, "start", "--tick", "1", "--agent", "t3684", path=NO_TERMLINK_PATH)
    assert out.returncode == 0, out.stdout + out.stderr
    assert "termlink=ABSENT" in out.stdout              # inert, and says so
    assert _wait(lambda: (watcher.read_liveness() or {}).get("seq", 0) >= 2)
    live = watcher.read_liveness()
    assert live["termlink"] == "absent" and live["last_probe_ok"] is True
    st = json.loads(_cli(proj, "liveness", "--json").stdout)
    assert st["state"] == "live" and st["supervisor_alive"] is True
    status = _cli(proj, "status", path=NO_TERMLINK_PATH).stdout
    assert "watcher:          live" in status and "supervisor=up" in status

    # 1. SIGKILL the watcher → the supervisor respawns it; seq keeps rising
    w1 = _pid(proj, "watcher")
    seq1 = watcher.read_liveness()["seq"]
    os.kill(w1, signal.SIGKILL)
    assert _wait(lambda: _pid(proj, "watcher") not in (None, w1))
    assert _wait(lambda: watcher.read_liveness()["seq"] > seq1 + 1)

    # 2. hang the watcher (SIGSTOP) → seq stalls → not-live → supervisor kills
    #    and replaces it
    w2 = _pid(proj, "watcher")
    os.kill(w2, signal.SIGSTOP)
    assert _wait(lambda: watcher.liveness_verdict()["state"] == "not-live", timeout=15)
    assert _cli(proj, "liveness").returncode == 1
    assert _wait(lambda: _pid(proj, "watcher") not in (None, w2), timeout=20)
    assert _wait(lambda: watcher.liveness_verdict()["state"] == "live", timeout=15)
    assert any(e["event"] == "WATCHER_HUNG_KILLED" for e in watcher.read_events())

    # 3. kill supervisor AND watcher → not-live; `ensure --all` (the cron
    #    command) brings it back
    s3, w3 = _pid(proj, "supervisor"), _pid(proj, "watcher")
    os.kill(s3, signal.SIGKILL)
    os.kill(w3, signal.SIGKILL)
    assert _wait(lambda: watcher.liveness_verdict()["state"] == "not-live", timeout=15)
    enabled_dir = Path(os.environ["FW_SIDECAR_ENABLED_DIR"])
    assert len(list(enabled_dir.glob("*.json"))) == 1
    ens = _cli(proj, "ensure", "--all", "--json", path=NO_TERMLINK_PATH)
    assert "supervisor restarted" in ens.stdout, ens.stdout + ens.stderr
    assert _wait(lambda: watcher.liveness_verdict()["state"] == "live", timeout=15)

    # 4. stop → everything gone, disabled, verdict absent
    s4, w4 = _pid(proj, "supervisor"), _pid(proj, "watcher")
    assert _cli(proj, "stop").returncode == 0
    assert _wait(lambda: not _alive(s4) and not _alive(w4))
    assert watcher.liveness_verdict()["state"] == "absent"
    assert not list(enabled_dir.glob("*.json"))


def test_supervisor_restarts_a_dead_receiver(proj):
    assert _cli(proj, "start", "--tick", "1", "--agent", "t3684",
                path=NO_TERMLINK_PATH).returncode == 0
    old = lifecycle.read_triple_file()["pid"]
    os.kill(old, signal.SIGKILL)
    assert _wait(lambda: (lifecycle.read_triple_file() or {}).get("pid") not in (None, old)
                 and lifecycle.health(lifecycle.read_triple_file()["url"]), timeout=20)
    assert _wait(lambda: any(e["event"] == "RECEIVER_RESTARTED" for e in watcher.read_events()))


def test_receiver_start_starts_the_watcher_and_receiver_stop_stops_it(proj):
    assert _cli(proj, "receiver", "start", "--tick", "1", "--agent", "t3684",
                path=NO_TERMLINK_PATH).returncode == 0
    assert _wait(lambda: watcher.supervisor_alive())
    sup = _pid(proj, "supervisor")
    assert _cli(proj, "receiver", "stop").returncode == 0
    assert _wait(lambda: not _alive(sup))
    assert watcher.read_enabled() is None


# ── latency report ──────────────────────────────────────────────────────────

def test_latency_reports_median_p95_max_from_ledgers(proj):
    t0 = datetime(2026, 10, 2, 12, 0, 0, tzinfo=timezone.utc)
    rows = []
    for i, (recv, ho) in enumerate([(0.1, 5.0), (0.2, 31.0), (0.3, None)]):
        cid = f"o{i}"
        rows.append({"client_msg_id": cid, "state": "SENT", "by": "sender", "target": "p",
                     "ts": t0.isoformat()})
        rows.append({"client_msg_id": cid, "state": "RECEIVED", "by": "r",
                     "ts": (t0 + timedelta(seconds=recv)).isoformat()})
        if ho is not None:
            rows.append({"client_msg_id": cid, "state": "HANDED_OVER", "by": "peer",
                         "ts": (t0 + timedelta(seconds=ho)).isoformat()})
    p = proj / ".context/sidecar/direct-ack.jsonl"
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text("".join(json.dumps(r) + "\n" for r in rows))
    rep = latency.report()["outbound"]
    assert rep["send_to_received"] == {"n": 3, "median": 0.2, "p95": 0.3, "max": 0.3}
    assert rep["send_to_handed_over"]["n"] == 2 and rep["send_to_handed_over"]["max"] == 31.0
    assert rep["open"] == 1
    out = _cli(proj, "latency")
    assert out.returncode == 0 and "send to handed over" in out.stdout


def test_latency_inbound_uses_hub_ts_for_legacy_messages(proj):
    hub_ms = int(time.time() * 1000) - 4000
    receiver.store_message("h1", {"client_msg_id": "h1", "from": "old", "body": "b",
                                  "via": "hub-topic", "hub_ts": hub_ms})
    receiver.mark_handed_over("h1", evidence="transcript:x.jsonl")
    m = latency.report()["inbound"]["messages"][0]
    assert m["via"] == "hub-topic" and 3.0 < m["send_to_received_s"] < 30
    assert m["send_to_handed_over_s"] >= m["send_to_received_s"]


# ── wiring ──────────────────────────────────────────────────────────────────

def test_cron_registry_has_the_keepalive_and_boot_legs():
    import yaml
    jobs = {j["id"]: j for j in yaml.safe_load((FW_ROOT / ".context/cron-registry.yaml").read_text())["jobs"]}
    assert jobs["sidecar-ensure-1m"]["schedule"] == "* * * * *"
    assert "sidecar ensure --all" in jobs["sidecar-ensure-1m"]["command"]
    assert jobs["sidecar-ensure-boot"]["schedule"] == "@reboot"
    assert jobs["sidecar-ensure-1m"]["status"] == jobs["sidecar-ensure-boot"]["status"] == "active"


def test_claude_fw_starts_the_sidecar_for_every_session_and_says_when_inert():
    src = (FW_ROOT / "bin" / "claude-fw").read_text()
    assert "sidecar start --quiet --json" in src
    assert "INERT for injection — TermLink absent" in src
    # T-4003: a plain session is reached through a tmux pane when it runs in one,
    # so the wrapper names both routes and says which one this session lacks.
    assert "no tmux/--termlink: peer messages reach the agent at its next prompt" in src
    assert "this session runs in tmux, so peer messages are typed in when it is idle" in src


@pytest.mark.parametrize("args,expect", [
    (["--termlink"], "INERT for injection — TermLink absent"),
    # Captured output is not a terminal, so T-4003's tmux re-launch is skipped.
    ([], "no tmux/--termlink: peer messages reach the agent at its next prompt"),
])
def test_claude_fw_really_starts_the_sidecar(proj, tmp_path, args, expect):
    """Run the REAL bin/claude-fw with a stub `claude` on a PATH without
    termlink: the wrapper's own sidecar_start must leave a live, supervised
    watcher in the project and print the inert line."""
    stub = tmp_path / "stubbin"
    stub.mkdir()
    (stub / "claude").write_text("#!/bin/sh\necho stub-claude\nexit 0\n")
    (stub / "claude").chmod(0o755)
    env = {"HOME": os.environ["HOME"], "PATH": f"{stub}:{NO_TERMLINK_PATH}",
           "FW_SIDECAR_ENABLED_DIR": os.environ["FW_SIDECAR_ENABLED_DIR"],
           "FW_SIDECAR_REGISTRY_DIR": os.environ["FW_SIDECAR_REGISTRY_DIR"],
           "FW_SIDECAR_AGENT_ID": "t3684"}
    out = subprocess.run([str(FW_ROOT / "bin" / "claude-fw"), *args, "--no-restart"],
                         cwd=proj, env=env, capture_output=True, text=True, timeout=180)
    text = out.stdout + out.stderr
    assert expect in text and "stub-claude" in text, text[-2000:]
    assert _wait(lambda: watcher.liveness_verdict()["state"] == "live", timeout=20)
    assert watcher.supervisor_alive()
    assert (watcher.read_liveness() or {}).get("termlink") == "absent"


# ── R14: SessionStart autostart, explicit stop respected, stale code replaced ─

def _autostart(proj, **extra):
    env = dict(os.environ, PROJECT_ROOT=str(proj), PATH=NO_TERMLINK_PATH)
    env.pop("FW_REVIEW_WORKER", None)
    env.update(extra)
    p = subprocess.run(["bash", str(FW_ROOT / "agents/context/sidecar-autostart.sh")],
                       input="{}", env=env, capture_output=True, text=True, timeout=30)
    assert p.returncode == 0 and p.stdout == ""


def test_session_start_hook_starts_a_sidecar_never_started_here(proj):
    t0 = time.time()
    _autostart(proj)
    assert time.time() - t0 < 5                      # detached: never holds a session start
    assert _wait(lambda: watcher.liveness_verdict()["state"] == "live", timeout=30)
    assert watcher.supervisor_alive() and lifecycle.read_triple_file()


def test_session_start_hook_respects_an_explicit_stop_and_review_workers(proj):
    _autostart(proj)
    assert _wait(lambda: watcher.supervisor_alive(), timeout=30)
    assert _cli(proj, "stop").returncode == 0
    assert watcher.stopped_marker().exists()
    _autostart(proj)
    time.sleep(4)
    assert not watcher.supervisor_alive() and watcher.liveness_verdict()["state"] == "absent"
    watcher.stopped_marker().unlink()
    _autostart(proj, FW_REVIEW_WORKER="1")
    time.sleep(3)
    assert not watcher.supervisor_alive()


def test_start_replaces_a_receiver_and_watcher_running_stale_code(proj, monkeypatch):
    assert _cli(proj, "start", "--tick", "1", "--agent", "t3684", path=NO_TERMLINK_PATH).returncode == 0
    assert _wait(lambda: watcher.supervisor_alive())
    old_recv = lifecycle.read_triple_file()["pid"]
    old_sup = watcher.read_pid("supervisor")
    assert not watcher.is_stale(old_recv)
    monkeypatch.setattr(watcher, "code_mtime", lambda: time.time() + 3600)   # code "changed"
    assert watcher.is_stale(old_recv) and watcher.is_stale(old_sup)
    from lib import sidecar_cli
    args = type("A", (), {"agent": "t3684", "port": None, "tick": 1.0, "no_inject": False,
                          "quiet": True, "json": False})()
    monkeypatch.setenv("PATH", NO_TERMLINK_PATH)
    sidecar_cli.cmd_start(args)
    assert not lifecycle.pid_alive(old_recv) and lifecycle.read_triple_file()["pid"] != old_recv
    assert _wait(lambda: watcher.read_pid("supervisor") not in (None, old_sup) and watcher.supervisor_alive())
