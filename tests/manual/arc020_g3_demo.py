#!/usr/bin/env python3
"""arc-020 headline mechanic, G3 leg — self-heal (T-3341).

Demonstrates, against a LIVE termlink hub, that a dropped circuit self-heals:
a worker addresses a peer by its DURABLE NAME; the peer's live circuit has
dropped; the framework re-provisions an equivalent instance under the SAME
durable name (a NEW circuit, per D1 — never a resurrection) and the peer's
message still lands.

The flow, entirely on shipped substrate:

  1. BIND    spawn circuit-1 (a real termlink session); the durable name
             (a V9 address WITHOUT session=) is bound to it. A message
             delivered to circuit-1 lands.
  2. DROP    circuit-1 is killed. The LIVE T-3338 probe (termlink_probe)
             reports it DEFINITIVELY ABSENT — the hub answered "not found",
             not "unreachable" (the D4-A distinction the self-heal rests on).
  3. ELECT   two candidates race the durable name via the T-3335 live claim
             backend; exactly ONE wins (exactly-once), the other backs off.
  4. HEAL    the winner drives aef_resolve.provision() over the durable name:
             resolve locates the deepest live ancestor (the project — the
             agent rung has no live circuit), and the session provisioner
             materializes circuit-2 with a FRESH id (circuit-1 != circuit-2).
  5. LAND    a message delivered to the durable name — now bound to
             circuit-2 — lands on the healed circuit.

Substrate used (all shipped): aef_address (S1), aef_resolve.provision +
termlink_probe (S3/S8/T-3338), aef_election live claim backend (S8/T-3335),
and termlink spawn/interact/signal for the real circuits. No new stub, no
NotImplementedError — the demo is glue over shipped seams.

The one bridge worth naming: the live probe RAISES on a bare agent rung
(no session to ping) — agent-level presence is a v2 concern. So the heal
walk supplies the agent rung's answer from the circuit verdict we already
measured in step 2 (circuit-1 absent -> the durable name has no live
circuit). That is not a fabricated substrate answer; it is the real v1
semantics (an agent's liveness IS its carrying circuit's), routed from the
same live probe. Everything else in the walk is the shipped live probe.

Usage:
    termlink hub status --json     # confirm a hub is running (else: hub start)
    python3 tests/manual/arc020_g3_demo.py
Writes evidence to docs/reports/T-3341-g3-demo-evidence.md and exits 0 on success.
"""
from __future__ import annotations

import datetime
import json
import os
import socket
import subprocess
import sys
import time
import uuid
from dataclasses import replace
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))

from lib.aef_address import AEFAddress, serialize
from lib.aef_election import TermlinkChannelClaimBackend, default_termlink_invoke, elect
from lib.aef_resolve import (
    PROVISIONED,
    ResolveIndeterminate,
    provision,
    termlink_probe,
)

CHANNEL = "aef-g3-demo"
EVIDENCE = ROOT / "docs" / "reports" / "T-3341-g3-demo-evidence.md"
NONCE = uuid.uuid4().hex[:8]
BASE = f"g3-healer-{NONCE}"


def _sh(args: list[str], timeout: float = 30.0) -> dict:
    """Run termlink, parse JSON stdout; never raise (return {} on failure)."""
    try:
        p = subprocess.run(
            ["termlink", *args], capture_output=True, text=True, timeout=timeout
        )
    except Exception:
        return {}
    try:
        return json.loads(p.stdout)
    except (json.JSONDecodeError, ValueError):
        return {"_raw": p.stdout, "_err": p.stderr}


def _sessions() -> list[dict]:
    lst = _sh(["list", "--json"], timeout=20.0)
    return lst if isinstance(lst, list) else lst.get("sessions", lst.get("data", []))


def _spawn_circuit(name: str) -> str | None:
    """Spawn a background PTY shell; return the hub-assigned session id."""
    resp = _sh(["spawn", "--shell", "--backend", "background", "--name", name,
                "--wait", "--wait-timeout", "20", "--json"], timeout=40.0)
    sid = resp.get("session_id") if isinstance(resp, dict) else None
    if sid:
        return sid
    for s in _sessions():  # fall back: match by the name we asked for
        if s.get("name") == name:
            return s.get("id")
    return None


def _listener_pid(token: str) -> int | None:
    """The pid of the session's `termlink register` listener (from list)."""
    for s in _sessions():
        if s.get("id") == token:
            pid = s.get("pid")
            return int(pid) if pid else None
    return None


def _deliver(token: str, tag: str) -> tuple[bool, str]:
    """Run an echo on the live circuit; message 'lands' iff the tag echoes."""
    marker = f"LANDED-{tag}-{NONCE}"
    res = _sh(["interact", token, f"echo {marker}", "--json"], timeout=25.0)
    out = (res.get("output") if isinstance(res, dict) else "") or res.get("_raw", "")
    return (marker in out), marker


def _kill_circuit(token: str) -> None:
    """Terminate a spawned circuit: kill its listener, evict the registration.

    ping tracks the hub REGISTRATION, which the `termlink register` listener
    keeps alive independent of the shell running inside it (an interactive
    PTY shell even ignores SIGTERM). So a faithful drop kills the listener
    pid and lets `clean` evict the now-stale registration — after which ping
    answers 'not found' (a DEFINITIVE absence, not an unreachable timeout).
    """
    pid = _listener_pid(token)
    if pid:
        try:
            os.kill(pid, 9)  # SIGKILL — uncatchable, unlike the shell's TERM
        except ProcessLookupError:
            pass
    _sh(["clean", "--json"], timeout=15.0)


def _drop(token: str, probe) -> bool:
    """Drop the circuit; return True once the LIVE probe reports it absent."""
    _kill_circuit(token)
    deadline = time.monotonic() + 12.0
    while time.monotonic() < deadline:
        try:
            if probe(AEFAddress(host=None, session=token)) is False:
                return True  # hub answered 'not found': definitively absent
        except ResolveIndeterminate:
            _sh(["clean", "--json"], timeout=15.0)  # nudge eviction, retry
        time.sleep(0.4)
    return False


def main() -> int:
    lines: list[str] = []
    spawned: list[str] = []
    won_ticket = None
    ok = True

    def emit(s: str = ""):
        print(s)
        lines.append(s)

    ts = datetime.datetime.now(datetime.timezone.utc).isoformat()
    emit("# arc-020 G3 demo evidence — a dropped circuit self-heals")
    emit(f"_Captured {ts} against the live termlink hub (T-3341)._")
    emit()

    host = socket.gethostname()
    project = str(ROOT)
    durable = AEFAddress(host=host, hub="hub-a", project=project, agent="healer")
    durable_wire = serialize(durable)
    real_probe = termlink_probe()  # the shipped T-3338 live probe

    emit(f"- Durable name (correspondent, no `session=`): `{durable_wire}`")
    emit()

    try:
        # ── 1. BIND: spawn circuit-1, prove a message lands ──────────────
        emit("## 1. Bind: the durable name is bound to circuit-1 (live)")
        emit()
        sid1 = _spawn_circuit(f"{BASE}-1")
        if not sid1:
            emit("> SKIP: could not spawn circuit-1 (is a hub running?)")
            EVIDENCE.parent.mkdir(parents=True, exist_ok=True)
            EVIDENCE.write_text("\n".join(lines) + "\n")
            return 2
        spawned.append(sid1)
        c1 = replace(durable, session=sid1)
        alive1 = real_probe(c1) is True
        emit(f"- circuit-1 id: `{sid1}`")
        emit(f"- circuit-1 address (durable name + `session=`): `{serialize(c1)}`")
        emit(f"- live probe → circuit-1 alive? **{alive1}**")
        landed1, marker1 = _deliver(sid1, "c1")
        emit(f"- message `{marker1}` delivered to circuit-1 → lands? **{landed1}**")
        emit()
        ok &= alive1 and landed1

        # ── 2. DROP: kill circuit-1, prove DEFINITIVE absence ────────────
        emit("## 2. Drop: circuit-1 is killed; the live probe reports it absent")
        emit()
        absent = _drop(sid1, real_probe)
        emit(f"- circuit-1's listener killed; the stale registration evicted "
             f"(`termlink clean`).")
        emit(f"- live T-3338 probe → circuit-1 **definitively absent** "
             f"(hub answered 'not found', not 'unreachable')? **{absent}**")
        emit(f"  This is the D4-A distinction the self-heal rests on: a False "
             f"here means *heal*, a raise would have meant *retry*.")
        emit()
        ok &= absent
        circuit_down = absent  # the measured circuit verdict for the heal walk

        # ── 3. ELECT: exactly-once claim of the durable name ─────────────
        emit("## 3. Elect: two candidates race the durable name — exactly one wins")
        emit()
        backend = TermlinkChannelClaimBackend(CHANNEL, invoke=default_termlink_invoke)
        res_a = elect(durable, "healer-A", backend)
        res_b = elect(durable, "healer-B", backend)
        won_ticket = res_a if res_a.won else (res_b if res_b.won else None)
        exactly_once = (res_a.won != res_b.won)  # exactly one True
        emit(f"- elect(healer-A) → role=**{res_a.role}**")
        emit(f"- elect(healer-B) → role=**{res_b.role}** "
             f"(holder=`{(res_b.holder or {}).get('claimer', res_b.holder)}`)")
        emit(f"- exactly one candidate won the durable name? **{exactly_once}**")
        emit()
        ok &= exactly_once

        # ── 4. HEAL: re-provision circuit-2 under the SAME durable name ──
        emit("## 4. Heal: the winner re-provisions a NEW circuit under the same name")
        emit()

        def heal_probe(addr: AEFAddress) -> bool:
            # The bare agent rung (no session) has no circuit to ping — the
            # live probe raises there (v2 deferral). Supply its answer from
            # the circuit verdict measured in step 2: circuit down -> the
            # durable name has no live circuit -> the rung is absent.
            if addr.agent is not None and addr.session is None:
                return not circuit_down and real_probe(addr)
            return real_probe(addr)

        def spawn_session(intended: AEFAddress) -> AEFAddress:
            sid2 = _spawn_circuit(f"{BASE}-2")
            spawned.append(sid2)
            return replace(intended, session=sid2)

        def accept_agent(intended: AEFAddress):
            return None  # accept the intended agent address as-is

        pres = provision(
            durable,
            heal_probe,
            {"session": spawn_session, "agent": accept_agent},
            claim_holder="aef-g3-demo",
            claim_timeout=8.0,
        )
        provisioned = pres.outcome == PROVISIONED
        # circuit-2's id is the session token of the last spawned circuit.
        sid2 = spawned[-1] if len(spawned) > 1 else None
        distinct = bool(sid2) and sid2 != sid1
        emit(f"- provision(durable) → outcome=**{pres.outcome}** "
             f"(resolve found_at=`{pres.resolve.found_at}`)")
        emit(f"- materialized (top-down): {list(pres.materialized)}")
        emit(f"- circuit-2 id: `{sid2}`")
        emit(f"- circuit-1 `{sid1}` ≠ circuit-2 `{sid2}` (D1 — new instance, "
             f"not a resurrection)? **{distinct}**")
        emit()
        ok &= provisioned and distinct

        # ── 5. LAND: the message lands on the healed circuit ─────────────
        emit("## 5. Land: the peer's message lands on the healed circuit-2")
        emit()
        alive2 = bool(sid2) and real_probe(replace(durable, session=sid2)) is True
        landed2, marker2 = (_deliver(sid2, "c2") if sid2 else (False, "-"))
        emit(f"- live probe → circuit-2 alive? **{alive2}**")
        emit(f"- message `{marker2}` delivered to circuit-2 → lands? **{landed2}**")
        emit()
        ok &= alive2 and landed2

        emit("## Result")
        emit()
        emit(f"**RESULT:** the dropped circuit self-healed — the durable name "
             f"`healer` outlived circuit-1, elected exactly-once, re-provisioned "
             f"to a distinct circuit-2, and the peer's message landed. "
             f"G3 {'demonstrated ✓' if ok else 'FAILED ✗'}.")
        emit()

    finally:
        # cleanup: release the claim, terminate every circuit we spawned.
        if won_ticket is not None and won_ticket.won:
            try:
                won_ticket.release()
            except Exception as exc:
                emit(f"- (cleanup) claim release failed: {exc}")
        for token in spawned:
            _kill_circuit(token)
        emit("_Claims released; spawned circuits terminated and cleaned._")

    EVIDENCE.parent.mkdir(parents=True, exist_ok=True)
    EVIDENCE.write_text("\n".join(lines) + "\n")
    print(f"\nEvidence written: {EVIDENCE.relative_to(ROOT)}")
    print("RESULT:", "PASS ✓" if ok else "FAIL ✗")
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
