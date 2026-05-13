#!/usr/bin/env python3
"""v2 peer-consult subscriber + responder spawn-bridge.

T-1818 (framework-half) / pairs with TermLink T-1636 (`inbox.queued` emitter).
Substrate: `termlink event poll <target> --topic inbox.queued --since <cursor>`.
Wire contract per T-1804: payload = {addressee_session_id, channel,
message_offset, enqueued_at}, no message body.

On each event the subscriber resolves the addressee to a responder workflow
(via .context/peer-consult-prompts.yaml), spawns a TermLink worker via
`fw termlink dispatch` with the original event payload as preamble, then
advances cursor. Resolution failures are logged (one line per miss) and the
loop continues — no crash, no stall.

Designed for cron-driven 30s `--once` invocations. Long-poll timeout is short
enough to terminate within the cron interval.
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import time
from pathlib import Path
from typing import Any, Iterable

PROJECT_ROOT = Path(os.environ.get("PROJECT_ROOT") or os.getcwd()).resolve()
WORKING = PROJECT_ROOT / ".context" / "working"
CURSOR_FILE = WORKING / ".peer-subscribe.cursor"
MISS_LOG = WORKING / "peer-consult-misses.log"
PROMPTS_FILE = PROJECT_ROOT / ".context" / "peer-consult-prompts.yaml"
TOPIC = "inbox.queued"


def _now_iso() -> str:
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())


def _read_cursor() -> tuple[str, int]:
    try:
        text = CURSOR_FILE.read_text()
    except FileNotFoundError:
        return "", 0
    target, since = "", 0
    for line in text.splitlines():
        if ":" not in line:
            continue
        k, _, v = line.partition(":")
        k, v = k.strip(), v.strip().strip("\"'")
        if k == "target_session":
            target = v
        elif k == "since" and v.isdigit():
            since = int(v)
    return target, since


def _write_cursor(target: str, since: int) -> None:
    WORKING.mkdir(parents=True, exist_ok=True)
    CURSOR_FILE.write_text(f"target_session: {target}\nsince: {since}\n")


def _list_ready_sessions(runner=subprocess.run) -> list[dict[str, Any]]:
    try:
        proc = runner(
            ["termlink", "list", "--json"],
            capture_output=True, text=True, timeout=5,
        )
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return []
    if proc.returncode != 0 or not proc.stdout:
        return []
    try:
        data = json.loads(proc.stdout)
    except json.JSONDecodeError:
        return []
    return [s for s in data.get("sessions", []) if s.get("state") == "ready"]


def _pick_target(saved: str, runner=subprocess.run) -> str:
    ready = _list_ready_sessions(runner=runner)
    if not ready:
        return ""
    if saved:
        for s in ready:
            if s.get("display_name") == saved:
                return saved
    return ready[0].get("display_name", "") or ""


def _load_prompts() -> dict[str, dict[str, str]]:
    """Tiny YAML reader for peer-consult-prompts.yaml — top-level entries with
    indented scalar fields. Avoids a PyYAML dep for cron-path code."""
    if not PROMPTS_FILE.exists():
        return {}
    out: dict[str, dict[str, str]] = {}
    cur: str | None = None
    for raw in PROMPTS_FILE.read_text().splitlines():
        if not raw.strip() or raw.lstrip().startswith("#"):
            continue
        if not raw.startswith(" ") and raw.endswith(":"):
            cur = raw[:-1].strip()
            out[cur] = {}
        elif cur is not None and ":" in raw:
            k, _, v = raw.strip().partition(":")
            out[cur][k.strip()] = v.strip().strip("\"'")
    return out


def resolve_addressee(event: dict[str, Any], prompts: dict[str, dict[str, str]]):
    """Map an inbox.queued event to a responder workflow.

    Match precedence: explicit addressee_session_id > channel prefix.
    Returns (workflow_path, responder_name) or (None, None) if no match.
    """
    addr = event.get("addressee_session_id") or event.get("addressee") or ""
    chan = event.get("channel") or ""
    for key, cfg in prompts.items():
        if cfg.get("addressee") and cfg["addressee"] == addr:
            return cfg.get("workflow"), cfg.get("name", key)
        prefix = cfg.get("channel")
        if prefix and chan.startswith(prefix):
            return cfg.get("workflow"), cfg.get("name", key)
    return None, None


def log_miss(event: dict[str, Any]) -> None:
    WORKING.mkdir(parents=True, exist_ok=True)
    with MISS_LOG.open("a", encoding="utf-8") as f:
        f.write(f"{_now_iso()} {json.dumps(event, sort_keys=True)}\n")


def spawn_responder(workflow: str, name: str, event: dict[str, Any],
                    runner=subprocess.run) -> subprocess.CompletedProcess | None:
    preamble = (
        f"v2 peer-consult responder: {name}\n\n"
        f"Origin event ({TOPIC}):\n{json.dumps(event, indent=2, sort_keys=True)}\n\n"
        f"Workflow: {workflow}\n"
        f"Task context: respond per workflow; emit terminal_event when complete.\n"
    )
    cmd = [
        "bin/fw", "termlink", "dispatch",
        "--name", f"peer-{name}",
        "--prompt", preamble,
        "--task", "T-1818",
    ]
    try:
        return runner(cmd, capture_output=True, text=True, timeout=30)
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return None


def poll_once(target: str, since: int, timeout: int = 25,
              runner=subprocess.run) -> list[dict[str, Any]]:
    try:
        proc = runner(
            ["termlink", "event", "poll", target,
             "--topic", TOPIC, "--since", str(since),
             "--json", "--timeout", str(timeout)],
            capture_output=True, text=True, timeout=timeout + 5,
        )
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return []
    if proc.returncode != 0 or not proc.stdout:
        return []
    try:
        data = json.loads(proc.stdout)
    except json.JSONDecodeError:
        return []
    if isinstance(data, dict):
        data = data.get("events", []) or []
    return list(data) if isinstance(data, list) else []


def subscribe(once: bool = True, max_iters: int | None = None,
              runner=subprocess.run, sleep=time.sleep) -> int:
    """Run subscriber loop. Returns number of iterations completed.

    `once=True` polls a single batch then returns — cron mode.
    `once=False` loops continuously (daemon mode, not preferred per T-1804).
    """
    prompts = _load_prompts()
    saved_target, since = _read_cursor()
    target = _pick_target(saved_target, runner=runner)
    if not target:
        return 0
    if saved_target and target != saved_target:
        since = 0  # cursor reset when target session changes
    iters = 0
    while True:
        events = poll_once(target, since, runner=runner)
        for ev in events:
            seq = ev.get("message_offset") or ev.get("seq") or 0
            if isinstance(seq, int) and seq > since:
                since = seq  # advance cursor on every seen event (miss or hit)
            workflow, name = resolve_addressee(ev, prompts)
            if not workflow:
                log_miss(ev)
                continue
            spawn_responder(workflow, name, ev, runner=runner)
        _write_cursor(target, since)
        iters += 1
        if once or (max_iters is not None and iters >= max_iters):
            return iters
        sleep(1)


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(
        prog="fw peer",
        description="v2 peer-consult subscriber + responder spawn-bridge",
    )
    sub = p.add_subparsers(dest="cmd", required=True)
    s = sub.add_parser(
        "subscribe",
        help="long-poll inbox.queued events + spawn responders (cron mode)",
    )
    s.add_argument("--once", action="store_true",
                   help="single poll then exit (cron default)")
    s.add_argument("--daemon", action="store_true",
                   help="loop continuously (not preferred — use cron)")
    args = p.parse_args(argv)
    if args.cmd == "subscribe":
        once = not args.daemon
        subscribe(once=once)
        return 0
    return 1


if __name__ == "__main__":
    sys.exit(main() or 0)
