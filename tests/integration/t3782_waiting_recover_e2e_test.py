"""T-3782 — LIVE proof that a message for a dead recipient is never unnoticed. Not mocked.

Two scratch projects. B is the recipient: a real `claude-fw --termlink` session
is started (which starts B's sidecar: receiver + supervised watcher at the
default 30 s tick) and then KILLED, so B's sidecar is up and its agent is not.
A is the sender: its own sidecar and the real `fw sidecar send`.

  test_waiting_receipt_push_handover_recover_and_negative_control
    1. A sends an URGENT message U and a normal message N to B.
    2. A's sender ledger gets WAITING_NO_RECIPIENT for both (the sender is told,
       with the reason and the time) — from B's real watcher/receiver.
    3. The operator is notified: B's watcher runs the real push path with
       FW_SIDECAR_NOTIFY_CMD capturing it — U at once (urgent), N at the warn
       threshold (FW_SIDECAR_CONSULT_WARN_HOURS=0.02, i.e. 72 s). Each once.
    4. A real `fw handover` in B carries the "Messages Waiting for a Recipient"
       section naming both.
    5. `fw sidecar recover U` starts a REAL claude-fw --termlink session in B
       whose first prompt carries U framed as untrusted data; B records
       HANDED_OVER from that session's transcript, and A's ledger shows it.
    6. Negative control, judged over the whole no-agent window (before step
       5): N, never recovered, is still listed, NOT handed over, pushed once.
       After step 5 N may reach the now-live agent normally — but it is never
       silently gone: listed or handed over.

Evidence: $T3782_E2E_EVIDENCE_DIR (default: the scratch base dir). Slow
(~6 min) and costs real model tokens. Skipped, loudly, without termlink,
claude or tmux.
"""

from __future__ import annotations

import json
import os
import random
import signal
import string
import subprocess
import sys
import time
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent))
import t3693_sidecar_e2e_test as base  # noqa: E402
import t3684_sidecar_watcher_e2e_test as live  # noqa: E402

FW = base.FW
BASE_DIR = live.BASE_DIR
EVIDENCE_DIR = Path(os.environ.get("T3782_E2E_EVIDENCE_DIR") or BASE_DIR)
WARN_HOURS = "0.02"   # 72 s: the threshold leg runs inside the test

pytestmark = pytest.mark.skipif(
    bool(base.MISSING),
    reason=f"T-3782 LIVE E2E NOT RUN — missing on PATH: {', '.join(base.MISSING)}. "
           "This is the only live proof of T-3782; a skip proves nothing.")


def _log(msg: str) -> None:
    print(f"[t3782-e2e {time.strftime('%H:%M:%S')}] {msg}", flush=True)


def _pushes(log: Path) -> list[str]:
    try:
        return log.read_text().splitlines()
    except OSError:
        return []


def _waiting(b_root: Path) -> list[dict]:
    p = live._run([FW, "sidecar", "waiting", "--json"], b_root)
    assert p.returncode == 0, p.stdout + p.stderr
    return json.loads(p.stdout)["items"]


def test_waiting_receipt_push_handover_recover_and_negative_control():
    BASE_DIR.mkdir(parents=True, exist_ok=True)
    run = "".join(random.choices(string.ascii_lowercase + string.digits, k=6))
    a_root, b_root = live._scratch(f"t3782a-{run}"), live._scratch(f"t3782b-{run}")
    push_log = BASE_DIR / f"pushes-{run}.log"
    push_cmd = BASE_DIR / f"push-{run}.sh"
    push_cmd.write_text(f'#!/bin/sh\nprintf "%s|%s\\n" "$1" "$2" >> {push_log}\n')
    push_cmd.chmod(0o755)
    b_env = {"FW_SIDECAR_NOTIFY_CMD": str(push_cmd),
             "FW_SIDECAR_CONSULT_WARN_HOURS": WARN_HOURS}
    ev: dict = {"run": run, "a": str(a_root), "b": str(b_root)}
    recovered_pid = None
    recovered_tl = None
    try:
        p = live._run([FW, "sidecar", "start"], a_root)
        assert p.returncode == 0, p.stdout + p.stderr
        # B: a real agent session (it starts B's sidecar with b_env) — then kill it.
        b = live.Session(b_root, "B")
        b.launch(**b_env)
        b.bring_up()
        assert "sidecar watcher running" in b.log.read_text()
        b.teardown()
        assert live._wait(lambda: live._run([FW, "sidecar", "liveness", "--json"], b_root)
                          .returncode == 0, 90, 3), "B's watcher did not outlive its agent"
        _log("B's agent killed; B's sidecar live")

        # 1. send
        u = live._send(a_root, b_root.name, f"URGENT-{run} please answer", urgent=True)
        n = live._send(a_root, b_root.name, f"NORMAL-{run} please answer")
        u_id, n_id = u["client_msg_id"], n["client_msg_id"]
        ev["u"], ev["n"] = u_id, n_id
        t_sent = time.time()

        # 2. the sender is told, on A's own ledger, with reason and time
        def waiting_rows():
            return [r for r in live._ledger(a_root)
                    if r.get("state") == "WAITING_NO_RECIPIENT" and r["client_msg_id"] in (u_id, n_id)]
        rows = live._wait(lambda: len(waiting_rows()) == 2 and waiting_rows(), 90, 2)
        assert rows, f"no WAITING_NO_RECIPIENT at A: {live._ledger(a_root)}"
        for r in rows:
            assert "no live recipient" in r["note"] and r["since"], r
        ev["sender_waiting_rows"] = rows
        ev["sender_told_within_s"] = round(time.time() - t_sent, 1)
        _log(f"sender told in {ev['sender_told_within_s']} s")

        # 3. operator push: U at once, N at the threshold, each once
        assert live._wait(lambda: any(f"URGENT Peer message waiting" in l for l in _pushes(push_log)),
                          90, 2), f"no urgent push: {_pushes(push_log)}"
        assert live._wait(lambda: len(_pushes(push_log)) >= 2, 72 + 120, 3), \
            f"no threshold push for N: {_pushes(push_log)}"
        time.sleep(65)   # two more ticks: nothing new may be pushed
        pushes = _pushes(push_log)
        assert len(pushes) == 2, pushes
        assert any(u_id in l for l in pushes) and any(n_id in l for l in pushes), pushes
        ev["pushes"] = pushes

        # 4. a real handover lists both
        p = live._run([FW, "handover"], b_root, timeout=600)
        latest = (b_root / ".context/handovers/LATEST.md").read_text()
        assert "## Messages Waiting for a Recipient" in latest, p.stdout[-2000:]
        assert u_id in latest and n_id in latest
        ev["handover_has_section"] = True

        # 6 (judged here, over the whole no-agent window): the negative control.
        # N, never recovered, is still listed, NOT handed over, pushed once —
        # nothing but an operator action or a live agent closes it.
        items = {i["id"]: i for i in _waiting(b_root)}
        assert n_id in items and items[n_id]["state"] == "no-live-recipient", items
        assert u_id in items, items
        assert not live._first(live._events(b_root, n_id), event="HANDED_OVER")
        assert sum(1 for l in _pushes(push_log) if n_id in l) == 1
        ev["negative_control_listed_s_after_send"] = round(time.time() - t_sent, 1)
        ev["negative_control_listed"] = items[n_id]

        # 5. recover U: a real agent starts with U as its first prompt
        p = live._run([FW, "sidecar", "recover", u_id, "--json"], b_root, timeout=120,
                      FW_SIDECAR_RECOVER_MODEL=live.MODEL)
        assert p.returncode == 0, p.stdout + p.stderr
        rec = json.loads(p.stdout)
        recovered_pid = rec["wrapper_pid"]
        ev["recover"] = rec
        _log(f"recover started {rec['termlink_session']}")
        deadline = time.time() + 240
        while time.time() < deadline:
            if recovered_tl is None:
                out = subprocess.run(["termlink", "discover", "--json"], capture_output=True,
                                     text=True, timeout=15, env=base._clean_env())
                try:
                    for s in json.loads(out.stdout).get("sessions", []):
                        if s.get("display_name") == rec["termlink_session"]:
                            recovered_tl = s["id"]
                except json.JSONDecodeError:
                    pass
            if recovered_tl and "trustthisfolder" in "".join(base._pty(recovered_tl, 40).split()):
                base._key(recovered_tl, "Down"); time.sleep(0.5); base._key(recovered_tl, "Enter")
            if live._first(live._events(b_root, u_id), event="HANDED_OVER"):
                break
            time.sleep(3)
        ho = live._first(live._events(b_root, u_id), event="HANDED_OVER")
        assert ho and str(ho.get("evidence", "")).startswith("recover-transcript:"), \
            f"no recover hand-over: {live._events(b_root, u_id)}"
        assert live._wait(lambda: any(r.get("state") == "HANDED_OVER" and r["client_msg_id"] == u_id
                                      for r in live._ledger(a_root)), 60, 2), \
            "A was not told HANDED_OVER"
        ev["recover_handed_over"] = ho

        # After recover, U is closed. N now has a live agent in its project and
        # may be delivered to it by the normal path — but it is never silently
        # gone: it is either still listed or handed over.
        items = {i["id"]: i for i in _waiting(b_root)}
        assert u_id not in items, items
        n_handed = live._first(live._events(b_root, n_id), event="HANDED_OVER")
        assert n_id in items or n_handed, (items, live._events(b_root, n_id))
        ev["n_after_recover"] = "listed" if n_id in items else "handed-over-to-recovered-agent"
        ev["result"] = "PASS"
    finally:
        EVIDENCE_DIR.mkdir(parents=True, exist_ok=True)
        (EVIDENCE_DIR / f"T-3782-e2e-{run}.json").write_text(json.dumps(ev, indent=2, default=str))
        _log(f"evidence: {EVIDENCE_DIR / f'T-3782-e2e-{run}.json'}")
        if recovered_tl:
            subprocess.run(["termlink", "pty", "inject", recovered_tl, "/exit", "--enter"],
                           capture_output=True, timeout=15, env=base._clean_env())
            time.sleep(3)
        if recovered_pid:
            try:
                os.killpg(recovered_pid, signal.SIGTERM)
            except ProcessLookupError:
                pass
        if recovered_tl:
            subprocess.run(["termlink", "signal", recovered_tl, "SIGTERM"], capture_output=True,
                           timeout=15, env=base._clean_env())
        for root in (a_root, b_root):
            live._run([FW, "sidecar", "stop", "--quiet"], root)
