"""arc-011 sidecar watcher — the per-agent, always-on tick (T-3684, T-3685).

Operator, 2026-10-02: "a watcher … watching if the message flag is up every
30 seconds and when it's up it looks if it is an urgent message and injects
directly, or if it's not urgent it looks if the prompt is free and if it's
free it injects the message and informs the sender."

Design of record: T-3397 §Consumption (30 s tick, configurable; the
guaranteed-delivery fallback behind the write-time fast path), T-3396
Amendment 5 IW-2 (liveness), target architecture §2 steps 7-9, register rows
R3 R5 R7 R14 R15.

One tick, every SIDECAR_TICK seconds (lib/config.sh FW_CONFIG_REGISTRY,
default 30):
  1. hub inbox topic(s): consults posted the pre-receiver way (peers on older
     installs, 1.7.740) are drained from the agent's inbox topics and stored in
     the receiver like any direct message — one delivery path from here on.
     Covered until T-3690 retires the topic.
  2. inject (lib/sidecar/inject.py): urgent → now, whatever the state (R5);
     otherwise only into a session whose OWN ready record says ready (T-3745).
     HANDED_OVER and CONFIRM-2 to the sender stay transcript-evidenced
     (lib/sidecar/hooks.py) — the tick never claims a hand-over.
  3. deadline: our own sent messages whose HANDED_OVER never came are
     ESCALATED (direct.escalate_expired) — the sender sees it within a tick,
     not at the next 5-minute sweep.
  4. liveness (R7): seq += 1, a loopback self-probe of our own receiver over
     the same authenticated HTTP path a peer uses, and
     .context/sidecar/liveness.yaml {identity, seq, last_probe_at,
     last_probe_ok, last_probe_latency_ms, …}. NOT live = seq stalled for 2
     ticks OR the probe failed (`liveness_verdict`, read by fw doctor and
     fw audit).

Supervision (T-3685): `fw sidecar start` / `fw sidecar receiver start` start a
detached SUPERVISOR (`watcher.py supervise`) which runs the watcher as its
child and restarts it when it exits or when its seq stalls (a hung tick), and
restarts the receiver when its process is gone. The supervisor itself is
restarted by `fw sidecar ensure --all` — the cron job `sidecar-ensure-1m` plus
an @reboot entry, the repo's existing supervision pattern (cron registry →
/etc/cron.d) — for every project whose sidecar was started and not stopped
(the host enabled-registry, ~/.local/state/fw-sidecar/enabled/).

Inert without TermLink, and visibly so: messages are still stored and
confirmed RECEIVED, nothing is injected, and liveness.yaml / `fw sidecar
status` say `termlink: absent`.
"""

from __future__ import annotations

import fcntl
import hashlib
import json
import os
import re
import shutil
import signal
import subprocess
import sys
import time
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

if __package__ in (None, ""):
    sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
    __package__ = "lib.sidecar"

from . import circuit, direct, inbox, inject, lifecycle, receipts, receiver  # noqa: E402

DEFAULT_TICK_S = 30
STALL_TICKS = 2          # IW-2: seq not advanced for 2 ticks = not live
STALL_GRACE_S = 5        # scheduling slack on top of 2 ticks
HUNG_KILL_TICKS = STALL_TICKS + 1   # supervisor replaces a hung watcher one tick after it reads not-live
SUPERVISE_POLL_S = 1.0
TICK_LOG_CAP = 2000      # ticks.jsonl keeps the newest N non-idle ticks


def _now() -> datetime:
    return datetime.now(timezone.utc)


# ── configuration ───────────────────────────────────────────────────────────

def _framework_yaml_value(key: str) -> str | None:
    try:
        text = (receiver._root() / ".framework.yaml").read_text(encoding="utf-8")
    except OSError:
        return None
    m = re.search(rf"^{re.escape(key)}:\s*['\"]?([^'\"#\n]+?)['\"]?\s*(#.*)?$", text, re.M)
    return m.group(1).strip() if m else None


def tick_seconds(override: float | None = None) -> float:
    """SIDECAR_TICK, resolved like fw_config: explicit > FW_SIDECAR_TICK env >
    .framework.yaml > registry default (30). Anything unparseable or < 1
    falls back to the default rather than spinning."""
    for raw in (override, os.environ.get("FW_SIDECAR_TICK"),
                _framework_yaml_value("SIDECAR_TICK")):
        if raw in (None, ""):
            continue
        try:
            val = float(raw)
        except (TypeError, ValueError):
            continue
        if val >= 1:
            return val
    return float(DEFAULT_TICK_S)


# ── paths ───────────────────────────────────────────────────────────────────

def _dir() -> Path:
    d = receiver._root() / ".context" / "sidecar" / "watcher"
    if not d.is_dir():
        d.mkdir(parents=True, exist_ok=True)
        lifecycle._ensure_runtime_ignored(d.parent)   # runtime state, never git
    return d


def liveness_path() -> Path:
    return receiver._root() / ".context" / "sidecar" / "liveness.yaml"


def enabled_path() -> Path:
    return _dir() / "enabled.json"


def _pidfile(which: str) -> Path:
    return _dir() / f"{which}.pid"


def _events_path() -> Path:
    return _dir() / "events.jsonl"


def record_event(event: str, **detail) -> None:
    row = {"ts": _now().isoformat(), "event": event}
    row.update({k: v for k, v in detail.items() if v is not None})
    with open(_events_path(), "a", encoding="utf-8") as fh:
        fh.write(json.dumps(row) + "\n")


def read_events() -> list[dict]:
    try:
        lines = _events_path().read_text(encoding="utf-8").splitlines()
    except OSError:
        return []
    out = []
    for ln in lines:
        try:
            out.append(json.loads(ln))
        except json.JSONDecodeError:
            continue
    return out


def host_enabled_dir() -> Path:
    env = os.environ.get("FW_SIDECAR_ENABLED_DIR")
    if env:
        d = Path(env)
    else:
        base = os.environ.get("XDG_STATE_HOME") or str(Path.home() / ".local" / "state")
        d = Path(base) / "fw-sidecar" / "enabled"
    d.mkdir(parents=True, exist_ok=True)
    return d


def _host_enabled_file(root: Path) -> Path:
    return host_enabled_dir() / (hashlib.sha256(str(root.resolve()).encode()).hexdigest()[:16] + ".json")


def read_pid(which: str) -> int | None:
    try:
        return int(_pidfile(which).read_text().strip())
    except (OSError, ValueError):
        return None


def _write_pid(which: str, pid: int) -> None:
    _pidfile(which).write_text(str(pid), encoding="utf-8")


def _agent() -> str:
    try:
        return circuit.agent_name()
    except circuit.CircuitError:
        return receiver._root().name


# ── enable / disable ────────────────────────────────────────────────────────

def enable(agent: str, tick: float | None, inject_on: bool) -> dict:
    root = receiver._root().resolve()
    cfg = {"agent": agent, "tick_s": tick, "inject": bool(inject_on),
           "project_root": str(root), "enabled_at": _now().isoformat()}
    enabled_path().write_text(json.dumps(cfg), encoding="utf-8")
    _host_enabled_file(root).write_text(json.dumps(cfg), encoding="utf-8")
    return cfg


def disable() -> None:
    root = receiver._root().resolve()
    for p in (enabled_path(), _host_enabled_file(root)):
        try:
            p.unlink()
        except FileNotFoundError:
            pass


def read_enabled() -> dict | None:
    try:
        return json.loads(enabled_path().read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return None


# ── 1. legacy hub inbox topics ──────────────────────────────────────────────

_ID_OK = re.compile(r"[A-Za-z0-9_:-]{1,128}")


def _hub_msg_id(msg: dict) -> str:
    cid = str(msg.get("client_msg_id") or "")
    if _ID_OK.fullmatch(cid):
        return cid
    h = hashlib.sha256(f"{msg.get('topic')}|{msg.get('offset')}".encode()).hexdigest()[:16]
    return f"hub-{h}"


def ingest_hub(reader=None) -> dict:
    """Drain this agent's hub inbox topic(s) into the receiver store.

    The cursor advances (inbox.pending), so the topic surface hook
    (sidecar-inbox.sh, which only peeks) does not show these again: from here
    a hub consult travels the receiver path — flag, tick, inject, transcript
    evidence — like any direct message."""
    if reader is None and shutil.which("termlink") is None:
        return {"skipped": "termlink absent", "ingested": []}
    kwargs = {"advance": True}
    if reader is not None:
        kwargs["reader"] = reader
    try:
        msgs = inbox.pending(**kwargs)
    except Exception as e:  # an unreadable hub must not stop the tick
        return {"error": f"{type(e).__name__}: {e}"[:300], "ingested": []}
    ingested = []
    for m in msgs:
        mid = _hub_msg_id(m)
        envelope = {
            "client_msg_id": mid,
            "from": m.get("from"),
            "from_circuit": m.get("from_circuit"),
            "conversation_id": m.get("conversation_id"),
            "body": m.get("body") or "",
            "urgent": False,
            "via": "hub-topic",
            "hub_topic": m.get("topic"),
            "hub_offset": m.get("offset"),
            "hub_ts": m.get("ts"),
        }
        ok, err = receiver.store_message(mid, envelope)
        if ok:
            receiver.record_event(mid, "INGESTED_FROM_HUB", topic=m.get("topic"),
                                  offset=m.get("offset"), hub_ts=m.get("ts"))
            ingested.append(mid)
            # RECEIVED back to the sender at once (receipts.py, T-3684).
            try:
                receipts.send(envelope, receipts.RECEIVED, by="watcher")
            except Exception as e:  # a receipt failure must not stop ingest
                receiver.record_event(mid, "RECEIPT_FAILED", state="RECEIVED",
                                      error=f"{type(e).__name__}: {e}"[:200])
        else:
            # The same id already stored (the peer dual-posted direct + hub):
            # the message is here once, which is the point.
            receiver.record_event(mid, "HUB_DUPLICATE_SKIPPED", reason=err,
                                  topic=m.get("topic"), offset=m.get("offset"))
    return {"ingested": ingested}


# ── 4. loopback self-probe ──────────────────────────────────────────────────

def self_probe(timeout: float = 3.0) -> dict:
    """Probe OUR receiver over the path a peer uses: /health, then an
    authenticated POST /ack for an id we never sent — the handler must answer
    with a well-formed `recorded: false`, proving the token, the handler and
    the ledger read all work. Latency covers both calls."""
    t0 = time.monotonic()
    out = {"at": _now().isoformat()}
    info = lifecycle.read_triple_file()
    if not info or not lifecycle.is_receiver_alive(info):
        return dict(out, ok=False, latency_ms=None, reason="receiver not running")
    url = str(info["url"])
    try:
        with urllib.request.urlopen(f"{url}/health", timeout=timeout) as resp:
            if resp.status != 200 or json.loads(resp.read()).get("status") != "ok":
                return dict(out, ok=False, latency_ms=None, reason="health not ok")
        token = lifecycle.read_token() or ""
        status, body = direct._post(url, "/ack", token, {
            "client_msg_id": f"probe-{os.getpid()}-{int(t0 * 1000)}",
            "state": "PROBE", "peer": "self-probe"}, timeout=timeout)
    except OSError as e:
        return dict(out, ok=False, latency_ms=None, reason=f"receiver unreachable: {e}"[:200])
    ms = round((time.monotonic() - t0) * 1000, 1)
    if status == 404 and body.get("recorded") is False:
        return dict(out, ok=True, latency_ms=ms, reason="")
    return dict(out, ok=False, latency_ms=ms,
                reason=f"authenticated /ack probe answered HTTP {status} {body}"[:200])


# ── liveness.yaml ───────────────────────────────────────────────────────────

_LIVENESS_KEYS = ("identity", "seq", "last_probe_at", "last_probe_ok",
                  "last_probe_latency_ms", "last_probe_reason", "updated_at",
                  "tick_s", "pid", "termlink", "inject_enabled")


def _yaml_scalar(v) -> str:
    if v is None:
        return "null"
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return str(v)
    return json.dumps(str(v))       # a JSON string is a valid YAML scalar


def write_liveness(state: dict) -> None:
    path = liveness_path()
    lines = ["# arc-011 sidecar liveness (T-3685, IW-2). Written every tick by",
             "# lib/sidecar/watcher.py. Not live = seq stalled 2 ticks OR probe failed."]
    for k in _LIVENESS_KEYS:
        lines.append(f"{k}: {_yaml_scalar(state.get(k))}")
    tmp = path.with_suffix(f".yaml.{os.getpid()}.tmp")
    tmp.write_text("\n".join(lines) + "\n", encoding="utf-8")
    os.replace(tmp, path)


def read_liveness() -> dict | None:
    try:
        text = liveness_path().read_text(encoding="utf-8")
    except OSError:
        return None
    out = {}
    for ln in text.splitlines():
        if ln.startswith("#") or ":" not in ln:
            continue
        k, v = ln.split(":", 1)
        v = v.strip()
        if v == "null":
            out[k] = None
        elif v in ("true", "false"):
            out[k] = v == "true"
        else:
            try:
                out[k] = json.loads(v)
            except json.JSONDecodeError:
                out[k] = v
    return out


def liveness_verdict(now: datetime | None = None) -> dict:
    """{state: live | not-live | absent, reasons[], …} — the one predicate
    fw doctor, fw audit, fw sidecar status and the supervisor all read.

    absent   — never started here and not enabled (R14 gap, not a fault)
    not-live — enabled or ticking before, and seq has not advanced for
               STALL_TICKS ticks (+grace), or the last probe failed
    live     — otherwise
    """
    now = now or _now()
    live = read_liveness()
    enabled = read_enabled()
    v = {"enabled": enabled is not None, "liveness": live, "reasons": []}
    if live is None:
        if enabled is None:
            v["state"] = "absent"
            v["reasons"].append("no sidecar watcher has run in this project (fw sidecar start)")
        else:
            v["state"] = "not-live"
            v["reasons"].append("enabled but liveness.yaml was never written (watcher never ticked)")
        return v
    tick = float(live.get("tick_s") or DEFAULT_TICK_S)
    try:
        age = (now - datetime.fromisoformat(str(live.get("updated_at")))).total_seconds()
    except ValueError:
        age = float("inf")
    v["age_s"] = round(age, 1)
    v["stall_after_s"] = STALL_TICKS * tick + STALL_GRACE_S
    if age > v["stall_after_s"]:
        v["reasons"].append(f"seq stalled at {live.get('seq')} for {age:.0f}s "
                            f"(> {STALL_TICKS} ticks of {tick:g}s)")
    if live.get("last_probe_ok") is False:
        v["reasons"].append(f"self-probe failed: {live.get('last_probe_reason') or 'unknown'}")
    if enabled is None:
        # Not started, or stopped on purpose: what liveness.yaml holds is history.
        v["state"] = "absent"
        v["reasons"] = ["sidecar not enabled here (stopped, or never started with fw sidecar start); "
                        "liveness.yaml is history"]
    else:
        v["state"] = "not-live" if v["reasons"] else "live"
    return v


# ── one tick ────────────────────────────────────────────────────────────────

def run_tick(seq: int, tick_s: float, runner=subprocess.run, hub_reader=None) -> dict:
    t0 = time.monotonic()
    report = {"seq": seq, "at": _now().isoformat()}
    report["hub"] = ingest_hub(hub_reader)
    try:
        dr = inject.deliver_pending(trigger="tick", runner=runner)
        report["deliver"] = {k: dr.get(k) for k in ("waiting", "injected", "session",
                                                    "target_session_id", "reason")}
    except Exception as e:
        report["deliver"] = {"error": f"{type(e).__name__}: {e}"[:300]}
    try:
        report["escalated"] = direct.escalate_expired()
    except Exception as e:
        report["escalated_error"] = f"{type(e).__name__}: {e}"[:300]
    probe = self_probe()
    report["probe"] = probe
    write_liveness({
        "identity": _agent(), "seq": seq, "last_probe_at": probe["at"],
        "last_probe_ok": probe["ok"], "last_probe_latency_ms": probe.get("latency_ms"),
        "last_probe_reason": probe.get("reason") or None,
        "updated_at": _now().isoformat(), "tick_s": tick_s, "pid": os.getpid(),
        "termlink": "present" if shutil.which("termlink") else "absent",
        "inject_enabled": lifecycle.inject_enabled(),
    })
    report["elapsed_ms"] = round((time.monotonic() - t0) * 1000, 1)
    if (report["hub"].get("ingested") or report["hub"].get("error")
            or (report.get("deliver") or {}).get("injected") or report.get("escalated")
            or not probe["ok"] or "error" in (report.get("deliver") or {})):
        _log_tick(report)
    return report


def _log_tick(report: dict) -> None:
    path = _dir() / "ticks.jsonl"
    with open(path, "a", encoding="utf-8") as fh:
        fh.write(json.dumps(report) + "\n")
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
        if len(lines) > TICK_LOG_CAP * 2:
            path.write_text("\n".join(lines[-TICK_LOG_CAP:]) + "\n", encoding="utf-8")
    except OSError:
        pass


def _single_instance(which: str):
    """Hold <which>.lock for the life of the process; None if another holds it."""
    fh = open(_dir() / f"{which}.lock", "a+")
    try:
        fcntl.flock(fh, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError:
        fh.close()
        return None
    return fh


def run_forever(tick_s: float | None = None) -> int:
    """The watcher process body: tick until SIGTERM."""
    tick = tick_seconds(tick_s)
    lock = _single_instance("watcher")
    if lock is None:
        record_event("WATCHER_REFUSED", pid=os.getpid(), reason="another watcher holds the lock")
        return 3
    stop = {"flag": False}

    def _term(*_):
        stop["flag"] = True
    signal.signal(signal.SIGTERM, _term)
    signal.signal(signal.SIGINT, _term)
    _write_pid("watcher", os.getpid())
    prev = read_liveness() or {}
    seq = int(prev.get("seq") or 0)
    record_event("WATCHER_STARTED", pid=os.getpid(), tick_s=tick, resumed_seq=seq)
    while not stop["flag"]:
        started = time.monotonic()
        seq += 1
        try:
            run_tick(seq, tick)
        except Exception as e:  # a tick that throws must not end the watcher
            record_event("TICK_ERROR", seq=seq, error=f"{type(e).__name__}: {e}"[:300])
        while not stop["flag"] and time.monotonic() - started < tick:
            time.sleep(min(0.5, tick))
    record_event("WATCHER_STOPPED", pid=os.getpid(), seq=seq)
    return 0


# ── supervisor ──────────────────────────────────────────────────────────────

def _spawn(args: list[str], log_name: str) -> subprocess.Popen:
    root = str(receiver._root().resolve())
    log = open(_dir() / log_name, "ab")
    return subprocess.Popen([sys.executable, os.path.abspath(__file__), *args],
                            stdin=subprocess.DEVNULL, stdout=log, stderr=log, cwd=root,
                            env=dict(os.environ, PROJECT_ROOT=root), start_new_session=True)


def _receiver_down() -> bool:
    info = lifecycle.read_triple_file()
    return not (info and lifecycle.is_receiver_alive(info))


def _restart_receiver(cfg: dict) -> None:
    """Restart the receiver the way `fw sidecar receiver start` would, keeping
    its inject setting. Done through the CLI so there is one start path."""
    cli = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "sidecar_cli.py")
    argv = [sys.executable, cli, "receiver", "start", "--quiet", "--no-watcher",
            "--agent", str(cfg.get("agent") or _agent())]
    if not cfg.get("inject", True):
        argv.append("--no-inject")
    root = str(receiver._root().resolve())
    proc = subprocess.run(argv, cwd=root, env=dict(os.environ, PROJECT_ROOT=root),
                          capture_output=True, text=True, timeout=60)
    record_event("RECEIVER_RESTARTED", rc=proc.returncode,
                 detail=(proc.stdout + proc.stderr).strip()[-300:] or None)


def supervise() -> int:
    """Run the watcher as a child; restart it when it exits or stalls; restart
    the receiver when its process is gone. Exits when disabled or on SIGTERM
    (taking the watcher with it)."""
    stop = {"flag": False}

    def _term(*_):
        stop["flag"] = True
    signal.signal(signal.SIGTERM, _term)
    signal.signal(signal.SIGINT, _term)
    lock = _single_instance("supervisor")
    if lock is None:
        return 3
    _write_pid("supervisor", os.getpid())
    record_event("SUPERVISOR_STARTED", pid=os.getpid())
    # A watcher orphaned by a supervisor that died (SIGKILL, OOM) still ticks.
    # Adopt by replacing it: one watcher per project, owned by this supervisor.
    orphan = read_pid("watcher")
    if lifecycle.pid_alive(orphan):
        record_event("ORPHAN_WATCHER_REPLACED", pid=orphan)
        os.kill(orphan, signal.SIGTERM)
        deadline = time.time() + 10
        while time.time() < deadline and lifecycle.pid_alive(orphan):
            time.sleep(0.1)
        if lifecycle.pid_alive(orphan):
            os.kill(orphan, signal.SIGKILL)
    child: subprocess.Popen | None = None
    child_started = 0.0
    last_receiver_check = 0.0
    try:
        while not stop["flag"]:
            cfg = read_enabled()
            if cfg is None:
                record_event("SUPERVISOR_DISABLED")
                break
            tick = tick_seconds(cfg.get("tick_s"))
            if child is None or child.poll() is not None:
                if child is not None:
                    record_event("WATCHER_DIED", pid=child.pid, rc=child.returncode)
                child = _spawn(["run", "--tick", str(tick)], "watcher.log")
                child_started = time.monotonic()
                record_event("WATCHER_SPAWNED", pid=child.pid)
            elif time.monotonic() - child_started > HUNG_KILL_TICKS * tick + STALL_GRACE_S:
                # Report first, heal second: doctor/audit call the watcher
                # not-live after STALL_TICKS; the supervisor replaces it one
                # tick later, so a hang is both visible and self-healing.
                v = liveness_verdict()
                age = v.get("age_s") or 0
                if (v["state"] == "not-live" and any("stalled" in r for r in v["reasons"])
                        and age > HUNG_KILL_TICKS * tick + STALL_GRACE_S):
                    record_event("WATCHER_HUNG_KILLED", pid=child.pid, reasons=v["reasons"])
                    try:
                        child.kill()
                        child.wait(timeout=10)
                    except (OSError, subprocess.TimeoutExpired):
                        pass
                    continue
            if time.monotonic() - last_receiver_check >= min(tick, 5):
                last_receiver_check = time.monotonic()
                if _receiver_down():
                    _restart_receiver(cfg)
            time.sleep(SUPERVISE_POLL_S)
    finally:
        if child is not None and child.poll() is None:
            child.terminate()
            try:
                child.wait(timeout=10)
            except subprocess.TimeoutExpired:
                child.kill()
        record_event("SUPERVISOR_STOPPED", pid=os.getpid())
        if read_pid("supervisor") == os.getpid():
            try:
                _pidfile("supervisor").unlink()
            except FileNotFoundError:
                pass
    return 0


def supervisor_alive() -> bool:
    return lifecycle.pid_alive(read_pid("supervisor"))


def start_supervisor(wait_s: float = 15.0) -> dict:
    """Start the supervisor unless one is running; wait for the first tick."""
    if supervisor_alive():
        return {"started": False, "pid": read_pid("supervisor"), "reason": "already running"}
    before = (read_liveness() or {}).get("seq")
    proc = _spawn(["supervise"], "supervisor.log")
    deadline = time.time() + wait_s
    while time.time() < deadline:
        live = read_liveness() or {}
        if live.get("seq") != before and live.get("seq") is not None:
            return {"started": True, "pid": proc.pid, "seq": live.get("seq")}
        if proc.poll() is not None:
            return {"started": False, "pid": proc.pid,
                    "reason": f"supervisor exited rc={proc.returncode} (see {_dir() / 'supervisor.log'})"}
        time.sleep(0.2)
    return {"started": True, "pid": proc.pid, "reason": f"no tick within {wait_s:.0f}s yet"}


def stop_all(timeout: float = 10.0) -> dict:
    """Disable, then stop supervisor and watcher (the supervisor's exit takes
    its child; the watcher pidfile covers an orphan)."""
    disable()
    stopped = {}
    for which in ("supervisor", "watcher"):
        pid = read_pid(which)
        if lifecycle.pid_alive(pid):
            os.kill(pid, signal.SIGTERM)
            deadline = time.time() + timeout
            while time.time() < deadline and lifecycle.pid_alive(pid):
                time.sleep(0.1)
            if lifecycle.pid_alive(pid):
                os.kill(pid, signal.SIGKILL)
            stopped[which] = pid
    return stopped


def ensure_all() -> list[dict]:
    """Cron / @reboot entry: for every project on this host whose sidecar is
    enabled, (re)start its supervisor if it is not running. Projects whose root
    is gone are dropped from the host registry."""
    out = []
    for f in sorted(host_enabled_dir().glob("*.json")):
        try:
            cfg = json.loads(f.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            continue
        root = Path(str(cfg.get("project_root") or ""))
        if not (root / ".context").is_dir():
            f.unlink(missing_ok=True)
            out.append({"project_root": str(root), "action": "dropped (project gone)"})
            continue
        cli = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "sidecar_cli.py")
        proc = subprocess.run([sys.executable, cli, "ensure", "--json"], cwd=str(root),
                              env=dict(os.environ, PROJECT_ROOT=str(root)),
                              capture_output=True, text=True, timeout=120)
        try:
            row = json.loads(proc.stdout.strip().splitlines()[-1])
        except (IndexError, json.JSONDecodeError):
            row = {"error": (proc.stdout + proc.stderr)[-300:]}
        row["project_root"] = str(root)
        out.append(row)
    return out


def main(argv=None) -> int:
    argv = sys.argv[1:] if argv is None else argv
    if argv[:1] == ["run"]:
        tick = None
        if len(argv) >= 3 and argv[1] == "--tick":
            tick = float(argv[2])
        return run_forever(tick)
    if argv[:1] == ["supervise"]:
        return supervise()
    print("usage: watcher.py run [--tick N] | supervise", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main())
