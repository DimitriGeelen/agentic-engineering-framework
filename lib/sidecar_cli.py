#!/usr/bin/env python3
"""`fw sidecar` — the callable surface of the arc-011 peer-consult sidecar.

T-3406, slice 4. Slices 1-3 shipped three library modules with zero callers
outside their own tests. This is what makes them usable by an agent: a verb
it can run, and a verb it can be TOLD to run in a dispatch prompt.

    fw sidecar whoami
    fw sidecar send --to <agent> --body <text> [--hub host:port] [--conversation ID]
    fw sidecar inbox [--json] [--peek]
    fw sidecar receiver start|stop|status     (T-3693: the receiving sidecar)
    fw sidecar deliver-pending | acks         (T-3693)

Delivery is not reimplemented here — `send` calls slice 1's outbox, slice 2's
deliver() and slice 3's transport and probe, so the ack ledger, the hub
capability gate and the loud-failure semantics all apply unchanged.
"""

from __future__ import annotations

import argparse
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from lib.sidecar import circuit, delivery, dm, e2e, inbox, outbox, retry, status as status_mod  # noqa: E402
from lib.sidecar import termlink_transport as transport, receiver, lifecycle, adapter, direct, inject  # noqa: E402


def cmd_whoami(args) -> int:
    """Who this agent is and where a consult for it lands (T-3433).

    Both topics are printed, not just the current one: during the transition
    the legacy `sidecar:` alias is still drained, so an operator debugging a
    consult that "went missing" needs to see both addresses at once.
    """
    try:
        payload = {
            "agent_id": inbox.agent_id(),
            "circuit_id": circuit.circuit_id("agent"),
            "circuit_id_full": circuit.circuit_id("full"),
            "project_circuit": circuit.circuit_id("project"),
            "inbox_topic": inbox.inbox_topic(),
            "legacy_topics": inbox.legacy_topics(),
            # T-3442: the TermLink identity fingerprint, distinct from every
            # circuit id above — machine-wide (T-3405), and the key DM rails
            # (dm:<a>:<b>) are addressed with. `dm.rails_for_key()` defaults
            # to this same value.
            "identity_fingerprint": dm.identity_fingerprint(),
        }
    except circuit.CircuitError as exc:
        print(f"whoami: no address can be derived — {exc}", file=sys.stderr)
        return 2
    if args.json:
        print(json.dumps(payload))
    else:
        print(f"agent_id:      {payload['agent_id']}")
        print(f"circuit:       {payload['circuit_id']}")
        print(f"  full:        {payload['circuit_id_full']}")
        print(f"  project:     {payload['project_circuit']}   (durable role address)")
        print(f"inbox topic:   {payload['inbox_topic']}")
        for topic in payload["legacy_topics"]:
            print(f"legacy (read): {topic}")
        print(f"identity fp:   {payload['identity_fingerprint'] or '- (termlink unreachable)'}"
              "   (DM rail key, machine-wide — T-3405)")
    return 0


def _send_direct(args, entry: dict) -> int:
    """T-3693: the peer has a registered receiver — call its API directly."""
    row = direct.send(entry, from_id=inbox.agent_id(), to=args.to, body=args.body,
                      conversation_id=args.conversation or f"consult-{args.to}",
                      urgent=args.urgent, in_reply_to=args.in_reply_to,
                      handover_deadline_s=args.handover_deadline,
                      retries=args.retries)
    ok = row["state"] == direct.RECEIVED
    payload = {"client_msg_id": row["client_msg_id"], "state": row["state"],
               "delivered": ok, "reason": row.get("error"), "path": "direct",
               "url": entry.get("url"), "handover_deadline": row.get("deadline")}
    if args.json:
        print(json.dumps(payload))
    else:
        print(f"{'delivered' if ok else 'NOT delivered'}: {row['state']}  ->  "
              f"{args.to} receiver {entry.get('url')}")
        print(f"client_msg_id: {row['client_msg_id']}")
        if row.get("error"):
            print(f"reason: {row['error']}")
    return 0 if ok else 1


def cmd_send(args) -> int:
    # T-3693: a peer with a registered receiver is called directly (D-645 §2).
    # The hub topic path below stays as the fallback when no receiver was ever
    # registered for the name. A registered-but-down receiver is NOT rerouted:
    # it spends the retry budget and is recorded UNDELIVERABLE.
    if not args.hub:
        entry = lifecycle.lookup(args.to)
        if entry is not None:
            return _send_direct(args, entry)

    # Resolve the address HERE rather than carrying a level flag through the
    # outbox: a resolved circuit is used verbatim by transport.topic_for, so
    # the ledger records the exact address the post went to (T-3433).
    try:
        target = circuit.resolve_address(args.to, level=args.level)
    except circuit.CircuitError as exc:
        print(f"send: {exc}", file=sys.stderr)
        return 2

    client_msg_id = outbox.write_message(
        from_id=inbox.agent_id(), to=target, body=args.body,
        conversation_id=args.conversation or f"consult-{args.to}",
        urgent=args.urgent, hub=args.hub)

    result = delivery.deliver(client_msg_id, transport.termlink_transport,
                              transport.probe_hub)

    payload = {
        "client_msg_id": result.client_msg_id,
        "state": result.state,
        "delivered": result.delivered,
        "reason": result.reason,
        "topic": circuit.topic_for_circuit(target),
    }
    if args.json:
        print(json.dumps(payload))
    else:
        verdict = "delivered" if result.delivered else "NOT delivered"
        print(f"{verdict}: {result.state}  ->  {payload['topic']}")
        print(f"client_msg_id: {result.client_msg_id}")
        if result.reason:
            print(f"reason: {result.reason}")
    # A refused hub or a failed post is a real failure, and the exit code
    # says so — the message stays retryable in the outbox either way.
    return 0 if result.delivered else 1


def cmd_inbox(args) -> int:
    messages = inbox.pending(advance=not args.peek)
    # T-3442: `--peek` shows DM rail SUMMARIES (count/cursor/unread, no hub
    # drain of content) — the same shape `fw sidecar status` prints. A
    # non-peek call actually drains unread DM posts (like the consult inbox
    # above) and advances each rail's cursor.
    dm_rows = dm.summary() if args.peek else []
    dm_posts = [] if args.peek else dm.pending(advance=True)

    if args.json:
        payload = {"consults": messages}
        if args.peek:
            payload["dm_rails"] = dm_rows
        else:
            payload["dm_posts"] = dm_posts
        print(json.dumps(payload, indent=2))
        return 0

    if not messages and not (dm_rows or dm_posts):
        print(f"no pending consults on {inbox.inbox_topic()}")
        return 0
    for msg in messages:
        sender = msg.get("from") or "unknown"
        print(f"--- consult @{msg.get('offset')} from {sender} "
              f"[{msg.get('conversation_id')}] ---")
        print(msg.get("body", ""))
        print()
    if args.peek:
        for row in dm_rows:
            print(f"dm rail {row['topic']}: count={row['count']} "
                  f"cursor={row['cursor']} unread={row['unread']}")
    else:
        for msg in dm_posts:
            sender = msg.get("from") or "unknown"
            print(f"--- dm @{msg.get('offset')} on {msg.get('topic')} "
                  f"from {sender} ---")
            print(msg.get("body", ""))
            print()
    return 0


def _inbound_or_unknown() -> dict:
    """`inbox.unread_summary()`, or an explicit UNKNOWN when no address can be
    derived (T-3544).

    The library raises rather than guessing, which is right: an unreadable hub
    anchor means the inbox has no address, and inventing one would be worse
    than failing. But `fw sidecar status` is a status command — it should
    report what it could not determine, not abort. So the failure is caught
    HERE, at the display boundary, and rendered as `unknown` with its reason.

    `unread: None` is deliberately not `0`. Everything in this task exists
    because a check that cannot see its subject had been indistinguishable
    from a check that saw nothing wrong.
    """
    try:
        return inbox.unread_summary()
    except circuit.CircuitError as exc:
        return {"unread": None, "topics": [], "reason": str(exc)}


def cmd_status(args) -> int:
    snap = status_mod.snapshot()
    # T-3442: DM rail summary is queried HERE, separately from
    # status_mod.snapshot() — snapshot()'s one design rule is that it reads
    # only our own durable state and never asks the hub (see status.py's
    # module docstring). Listing which dm:* rails exist has no durable
    # answer of its own, so it is merged in at the CLI boundary instead of
    # folded into the hub-free function.
    dm_rows = dm.summary()
    # T-3544: the INBOUND consult backlog, merged at the CLI boundary for the
    # same reason dm_rows is (see the comment above) — snapshot() stays
    # hub-free. Until this line existed, `status` reported the outbound ledger
    # in five ways and the one number a waiting peer cares about in none.
    #
    # An unreadable hub anchor degrades to UNKNOWN, never to 0. `status` must
    # not start crashing on a host that could always run it, and it must not
    # answer "no consults waiting" when what it means is "I could not look" —
    # that false green is the whole subject of this task.
    inbound = _inbound_or_unknown()
    probe = None
    if args.probe:
        # Kept apart from the file-derived numbers on purpose: the hub's
        # self-report must never be able to overwrite what our own ledger says.
        verdict = transport.probe_hub(None)
        probe = {"ok": verdict.ok, "reason": verdict.reason}
    if args.json:
        payload = dict(snap)
        payload["dm_rails"] = dm_rows
        payload["inbound"] = inbound
        if probe is not None:
            payload["hub_probe"] = probe
        print(json.dumps(payload, indent=2))
        return 0
    print(status_mod.render(snap))
    # Printed unconditionally, including the zero. "inbound unread: 0" is a
    # measurement; the absence of a line is indistinguishable from a check
    # that was never made, which is the state this whole task is about.
    if inbound["unread"] is None:
        print(f"inbound unread:   unknown — {inbound.get('reason', 'no address')}")
    else:
        print(f"inbound unread:   {inbound['unread']}")
    for row in inbound["topics"]:
        age = "unknown" if row["age_hours"] is None else f"{row['age_hours']}h"
        print(f"  {row['topic']}: {row['unread']} unread, oldest {age}"
              f" from {row['oldest_from'] or 'unknown'}")
    if dm_rows:
        print("dm rails:")
        for row in dm_rows:
            print(f"  {row['topic']}: count={row['count']} "
                  f"cursor={row['cursor']} unread={row['unread']}")
    if probe is not None:
        print(f"hub probe:        {'ok' if probe['ok'] else 'REFUSED'} — {probe['reason']}")
    return 0


def cmd_sweep(args) -> int:
    """Drive the universal retry ladder one tick (T-3434, D-600).

    OBS-447 is ruled, so the sweep no longer merely records failures: it
    re-posts what never reached the hub, escalates what the hub holds unread
    (inbox nudge from the 15-minute rung, operator from the 1-day rung), and
    dead-letters after the last rung. Exit 0 either way — a clean sweep is not
    an error, and cron should not page on it. The ladder lives in
    lib/retry_ladder.py; the walk lives in lib/sidecar/retry.py.
    """
    report = retry.sweep(now=args.now)
    # T-3693: the direct path's deadline check — HANDED_OVER missing past the
    # deadline is ESCALATED by infrastructure, never left as silence.
    report["direct_escalated"] = direct.escalate_expired(now=args.now)
    if args.json:
        print(json.dumps(report, indent=2, sort_keys=True))
        return 0
    print(f"swept: {report['considered']} open row(s), {report['due']} due  ->  "
          f"{report['reposted']} reposted, {report['nudged']} nudged, "
          f"{report['operator']} to operator, {report['answered']} answered, "
          f"{report['deadlettered']} dead-lettered, "
          f"{len(report['direct_escalated'])} direct escalated")
    for cid in report["direct_escalated"]:
        print(f"  {'escalate-direct':<22} {cid}  HANDED_OVER deadline passed")
    for action in report["actions"]:
        detail = action.get("reason") or action.get("state") or ""
        print(f"  {action['verb']:<22} {action['client_msg_id']}  {detail}")
    return 0


def cmd_e2e(args) -> int:
    """Live end-to-end run against the real hub and a real dispatched worker.

    T-3423. Preflight first so a missing hub never costs a worker; then
    lib/sidecar/e2e.py:run with the real collaborators; JSON record under
    .context/sidecar/e2e/<run>.json; exit 0 on PASS, 1 on FAIL, 3 on PENDING
    (T-3476: peer mode only — "no answer yet" is not "broken", and `fw
    sidecar settle <run_id>` re-checks a PENDING record later without
    re-sending).
    """
    ok, why = e2e.preflight()
    if not ok:
        print(f"e2e: preflight refused — {why}", file=sys.stderr)
        return 2
    task = args.task or e2e.focused_task()
    if not task:
        print("e2e: no --task and no focused task — dispatch needs a task reference",
              file=sys.stderr)
        return 2
    if args.peer and args.ambient:
        print("e2e: --ambient is meaningless with --peer (no prompt of ours is involved)",
              file=sys.stderr)
        return 2
    # T-3426: a real peer answers when it next reads, not when we poll — long
    # window, slow poll, unless the caller says otherwise.
    timeout = args.timeout if args.timeout is not None else (1800 if args.peer else 300)
    poll = args.poll if args.poll is not None else (15.0 if args.peer else 5.0)
    cfg = e2e.Config(task=task, timeout=timeout, ambient=args.ambient, peer=args.peer,
                     poll_interval=poll, worker_timeout=args.worker_timeout)
    if not args.json:
        what = (f"consulting peer {cfg.peer}, waiting up to {timeout}s for its answer"
                if cfg.peer else f"sending, then dispatching {cfg.responder}")
        print(f"e2e: preflight ok ({why}); run={cfg.run_id} mode={cfg.mode} — {what} …",
              flush=True)
    report = e2e.run(cfg)
    path = e2e.write_report(report)
    report["report_path"] = str(path)
    if not args.keep:
        # Drop the throwaway inbox cursors so `fw sidecar status` stays readable.
        state = inbox.load_state()
        for topic in (inbox.inbox_topic(cfg.sender), inbox.inbox_topic(cfg.responder)):
            state.get("topics", {}).pop(topic, None)
        inbox.save_state(state)
    if args.json:
        print(json.dumps(report, indent=2, sort_keys=True))
    else:
        print(e2e.render(report))
        print(f"  report: {path}")
    return _exit_for_verdict(report["verdict"])


def _exit_for_verdict(verdict: str) -> int:
    """0 PASS, 1 FAIL, 3 PENDING — distinct so a caller can tell "not yet"
    from "broken" (T-3476) instead of collapsing both into a bare failure."""
    if verdict == e2e.PASS:
        return 0
    if verdict == e2e.PENDING:
        return 3
    return 1


def cmd_settle(args) -> int:
    """Re-check a stored peer-mode e2e run against current hub state and
    update its verdict in place, without re-sending (T-3476).

    Reads .context/sidecar/e2e/<run_id>.json, re-derives H2/H4/H5 from
    current hub messages keyed on the record's own client_msg_id and
    conversation_id, and writes the settled record back to the same path —
    a PENDING run turns PASS the moment the peer's ACK lands on the hub, or
    stays PENDING (still no answer) or moves to FAIL (H1/H2 evidence turned
    up broken, which settle() also re-checks).
    """
    path = e2e.report_dir() / f"{args.run_id}.json"
    try:
        report = json.loads(path.read_text(encoding="utf-8"))
    except OSError:
        print(f"settle: no run record for {args.run_id!r} at {path}", file=sys.stderr)
        return 2
    try:
        report = e2e.settle(report)
    except ValueError as exc:
        print(f"settle: {exc}", file=sys.stderr)
        return 2
    e2e.write_report(report)
    if args.json:
        print(json.dumps(report, indent=2, sort_keys=True))
    else:
        print(e2e.render(report))
        print(f"  settled: {report['settle_history'][-1]['from_verdict']} -> {report['verdict']}")
        print(f"  report: {path}")
    return _exit_for_verdict(report["verdict"])


def cmd_dm_stale(args) -> int:
    """Rails with an unread content post older than `--threshold-hours` —
    the fact both `fw doctor` and `fw audit`'s `check_sidecar_ledger` read
    for the T-3442 AC2 WARN. Exit 0 always (a WARN is not a command
    failure); the caller decides what a non-empty list means."""
    rows = dm.stale(min_age_hours=args.threshold_hours)
    if args.json:
        print(json.dumps(rows, indent=2))
        return 0
    for row in rows:
        print(f"{row['topic']}\t{row['unread']}\t{row['age_hours']}")
    return 0


def cmd_inbox_stale(args) -> int:
    """Consult-inbox topics holding an unread consult older than
    `--threshold-hours` — the fact both `fw doctor` and `fw audit`'s
    `check_sidecar_ledger` read for the T-3544 WARN. Deliberately the same
    contract as `dm-stale` above: exit 0 always, because a backlog is a
    finding and not a command failure, and the caller decides what a non-empty
    list means. Moves no cursor — see `inbox.unread_summary`.

    The ONE thing it does not do is exit 0 on a failure to look. When no
    address can be derived, it exits 2 with the reason on stderr, so the fact
    function reports rc 2 ("the check could not run") deliberately rather than
    picking that up from an incidental traceback — and so neither caller can
    mistake "I could not look" for "nothing is waiting"."""
    try:
        rows = inbox.unread_stale(min_age_hours=args.threshold_hours)
    except circuit.CircuitError as exc:
        print(f"consult-inbox backlog check could not run: {exc}", file=sys.stderr)
        return 2
    if args.json:
        print(json.dumps(rows, indent=2))
        return 0
    for row in rows:
        age = "unknown" if row["age_hours"] is None else row["age_hours"]
        print(f"{row['topic']}\t{row['unread']}\t{age}\t{row['oldest_from'] or 'unknown'}")
    return 0


def _agent_or_none():
    try:
        return circuit.agent_name()
    except circuit.CircuitError as exc:
        print(f"receiver: no agent name can be derived — {exc}", file=sys.stderr)
        return None


def cmd_receiver_start(args) -> int:
    """Start the per-agent receiver (T-3693).

    Order is the contract (T-3475): the 0600 token is written FIRST; the
    server process reads it and refuses to bind without it; only after it has
    bound does it write the triple-file and the host registry entry. Exit 0
    started, 1 already running, 2 refused/failed.
    """
    import subprocess
    import time

    agent = args.agent or _agent_or_none()
    if not agent:
        return 2
    info = lifecycle.read_triple_file()
    if info and lifecycle.is_receiver_alive(info) and lifecycle.health(str(info["url"])):
        if not args.quiet:
            print(f"receiver already running: pid={info['pid']} url={info['url']}")
        return 1
    if info:
        lifecycle.clear_triple_file()

    try:
        lifecycle.write_token()
    except OSError as e:
        print(f"receiver: refusing to start — cannot write token: {e}", file=sys.stderr)
        return 2
    lifecycle.write_config(inject=not args.no_inject)

    root = str(receiver._root().resolve())
    env = dict(os.environ, PROJECT_ROOT=root)
    log = open(receiver._receiver_dir() / "server.log", "ab")
    server_py = os.path.join(os.path.dirname(os.path.abspath(__file__)), "sidecar", "http_server.py")
    proc = subprocess.Popen(
        [sys.executable, server_py, "--port", str(args.port or 0), "--agent", agent],
        stdin=subprocess.DEVNULL, stdout=log, stderr=log, cwd=root, env=env,
        start_new_session=True)

    deadline = time.time() + 10
    while time.time() < deadline:
        info = lifecycle.read_triple_file()
        if info and info.get("pid") == proc.pid and lifecycle.health(str(info["url"])):
            break
        if proc.poll() is not None:
            print(f"receiver: server exited with {proc.returncode} before binding "
                  f"(see {receiver._receiver_dir() / 'server.log'})", file=sys.stderr)
            return 2
        time.sleep(0.1)
    else:
        proc.terminate()
        print("receiver: server did not come up within 10s", file=sys.stderr)
        return 2

    if not args.quiet:
        print(f"receiver started: agent={agent} pid={info['pid']} port={info['port']}")
        print(f"  url:    {info['url']}")
        print(f"  token:  {lifecycle.token_path()} (mode 0600)")
        print(f"  inject: {'enabled' if not args.no_inject else 'DISABLED (--no-inject)'}")
    return 0


def cmd_receiver_stop(args) -> int:
    """Stop the receiver: SIGTERM, wait, SIGKILL only if it will not go."""
    import signal
    import time

    info = lifecycle.read_triple_file()
    if not info:
        if not args.quiet:
            print("receiver not running (no triple-file)")
        return 0
    pid = info.get("pid")
    if lifecycle.pid_alive(pid):
        os.kill(pid, signal.SIGTERM)
        deadline = time.time() + 5
        while time.time() < deadline and lifecycle.pid_alive(pid):
            time.sleep(0.1)
        if lifecycle.pid_alive(pid):
            os.kill(pid, signal.SIGKILL)
    # The server clears these itself on a clean exit; this covers a SIGKILL.
    lifecycle.clear_triple_file()
    agent = args.agent or _agent_or_none()
    if agent:
        lifecycle.unregister(agent, pid if isinstance(pid, int) else None)
    if not args.quiet:
        print(f"receiver stopped: was pid={pid}")
    return 0


def cmd_receiver_status(args) -> int:
    """pid/port/url and health. Exit 0 running+healthy, 1 not running/unhealthy."""
    info = lifecycle.read_triple_file()
    payload = {"status": "not_running"}
    if info:
        alive = lifecycle.is_receiver_alive(info)
        healthy = alive and lifecycle.health(str(info["url"]))
        payload = {"status": "running" if healthy else ("unresponsive" if alive else "stale"),
                   "pid": info["pid"], "port": info["port"], "url": info["url"],
                   "healthy": healthy, "inject_enabled": lifecycle.inject_enabled(),
                   "awaiting_handover": len(receiver.awaiting_handover()),
                   "token_file": str(lifecycle.token_path()),
                   "ready_for_input": adapter.is_ready_for_input()}
    if args.json:
        print(json.dumps(payload))
    elif payload["status"] == "not_running":
        print("receiver not running")
    else:
        print(f"receiver {payload['status']}: pid={payload['pid']} port={payload['port']}")
        print(f"  url:               {payload['url']}")
        print(f"  healthy:           {payload['healthy']}")
        print(f"  inject enabled:    {payload['inject_enabled']}")
        print(f"  awaiting handover: {payload['awaiting_handover']}")
        print(f"  agent ready:       {payload['ready_for_input']}")
    return 0 if payload.get("healthy") else 1


def cmd_deliver_pending(args) -> int:
    """Inject if a stored message waits and the agent is ready (T-3693).

    The entry point the 30 s tick (T-3684) will call; this slice adds no tick.
    """
    report = inject.deliver_pending(trigger=args.trigger)
    if args.json:
        print(json.dumps(report))
    else:
        print(f"deliver-pending ({report['trigger']}): waiting={report['waiting']} "
              f"injected={len(report['injected'])} — {report['reason']}")
    return 0


def cmd_acks(args) -> int:
    """The direct-path sender ledger: latest state per message (T-3693)."""
    rows = direct.latest()
    if args.id:
        hist = direct.history(args.id)
        print(json.dumps(hist, indent=2) if args.json else
              "\n".join(f"{r['ts']}  {r['state']:<13} by {r['by']}" for r in hist))
        return 0 if hist else 1
    if args.json:
        print(json.dumps(list(rows.values()), indent=2))
        return 0
    for cid, row in rows.items():
        print(f"{cid}  {row['state']:<13} to {row.get('target')}  [{row.get('conversation_id')}]")
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="fw sidecar",
                                     description=__doc__.split("\n")[0])
    sub = parser.add_subparsers(dest="command", required=True)

    who = sub.add_parser("whoami", help="report this agent's addressable id")
    who.add_argument("--json", action="store_true")
    who.set_defaults(func=cmd_whoami)

    send = sub.add_parser("send", help="send a consult to a peer agent")
    send.add_argument("--to", required=True, help="recipient agent id")
    send.add_argument("--body", required=True, help="the question or message")
    send.add_argument("--hub", default=None,
                      help="target hub host:port (omit for same-host)")
    send.add_argument("--conversation", default=None,
                      help="conversation id to thread on")
    send.add_argument("--level", choices=("auto", "project", "agent"), default="auto",
                      help="address form for a bare --to: project (durable role "
                           "address) or agent. Default auto — see circuit.is_project_id")
    send.add_argument("--urgent", action="store_true",
                      help="direct path: inject even if the peer agent is busy (R5)")
    send.add_argument("--in-reply-to", default=None,
                      help="client_msg_id this message answers (direct path: REPLIED)")
    send.add_argument("--handover-deadline", type=int,
                      default=direct.DEFAULT_HANDOVER_DEADLINE_S,
                      help="direct path: seconds until a missing HANDED_OVER is ESCALATED")
    send.add_argument("--retries", type=int, default=direct.DEFAULT_RETRIES,
                      help="direct path: attempts before UNDELIVERABLE")
    send.add_argument("--json", action="store_true")
    send.set_defaults(func=cmd_send)

    box = sub.add_parser("inbox", help="list consults addressed to this agent")
    box.add_argument("--json", action="store_true")
    box.add_argument("--peek", action="store_true",
                     help="do not advance the cursor")
    box.set_defaults(func=cmd_inbox)

    st = sub.add_parser("status", help="out-of-band channel status from our own "
                        "outbox/ledger/inbox state; never asks the hub")
    st.add_argument("--json", action="store_true")
    st.add_argument("--probe", action="store_true",
                    help="also run the hub capability probe, reported separately")
    st.set_defaults(func=cmd_status)

    sw = sub.add_parser("sweep", help="drive the universal retry ladder one tick: "
                        "re-post, escalate, or dead-letter every due row (T-3434)")
    sw.add_argument("--json", action="store_true")
    sw.add_argument("--now", default=None,
                    help="ISO-8601 instant to sweep as-of (testing and replay; "
                         "default: the real clock)")
    sw.set_defaults(func=cmd_sweep)

    ee = sub.add_parser("e2e", help="live end-to-end check: real hub, real dispatched "
                        "worker, every hop verified from both sides (T-3423)")
    ee.add_argument("--task", default=None,
                    help="task id for the dispatched worker (default: focused task)")
    ee.add_argument("--timeout", type=int, default=None,
                    help="seconds to wait for the reply (default 300; 1800 with --peer)")
    ee.add_argument("--poll", type=float, default=None,
                    help="seconds between inbox polls (default 5; 15 with --peer)")
    ee.add_argument("--worker-timeout", type=int, default=600,
                    help="dispatch kill-watchdog for the responder (default 600)")
    ee.add_argument("--peer", default=None, metavar="AGENT_ID",
                    help="consult a real peer agent instead of dispatching a worker "
                         "(T-3426): H3/H6 become peer-owned, verdict on H1/H2/H4/H5")
    ee.add_argument("--ambient", action="store_true",
                    help="prompt never mentions consults; measures the T-3407 stanza alone")
    ee.add_argument("--keep", action="store_true",
                    help="keep the throwaway inbox cursors after the run")
    ee.add_argument("--json", action="store_true")
    ee.set_defaults(func=cmd_e2e)

    se = sub.add_parser("settle", help="re-check a stored peer-mode e2e run against "
                        "current hub state; a late ACK turns PENDING into PASS "
                        "without re-sending (T-3476)")
    se.add_argument("run_id", help="the run id from a prior `fw sidecar e2e --peer` "
                    "(the .context/sidecar/e2e/<run_id>.json filename stem)")
    se.add_argument("--json", action="store_true")
    se.set_defaults(func=cmd_settle)

    ds = sub.add_parser("dm-stale", help="dm:* rails addressed to us with an unread "
                        "content post older than --threshold-hours (T-3442, "
                        "fw doctor / fw audit fact source)")
    ds.add_argument("--threshold-hours", type=float, default=24.0)
    ds.add_argument("--json", action="store_true")
    ds.set_defaults(func=cmd_dm_stale)

    ibs = sub.add_parser("inbox-stale", help="consult-inbox topics holding an unread "
                         "consult older than --threshold-hours (T-3544, "
                         "fw doctor / fw audit fact source)")
    ibs.add_argument("--threshold-hours", type=float, default=24.0)
    ibs.add_argument("--json", action="store_true")
    ibs.set_defaults(func=cmd_inbox_stale)

    # T-3693: receiver start/stop/status — the per-agent receiving sidecar
    recv = sub.add_parser("receiver", help="manage this agent's receiver sidecar (HTTP)")
    recv_sub = recv.add_subparsers(dest="receiver_cmd", required=True)

    recv_start = recv_sub.add_parser("start", help="write the 0600 token, then start the receiver")
    recv_start.add_argument("--port", type=int, default=None,
                            help="bind to this port (default: any free port)")
    recv_start.add_argument("--agent", default=None,
                            help="register under this agent name (default: this agent's name)")
    recv_start.add_argument("--no-inject", action="store_true",
                            help="store and confirm, but never inject (negative control)")
    recv_start.add_argument("--quiet", action="store_true")
    recv_start.set_defaults(func=cmd_receiver_start)

    recv_stop = recv_sub.add_parser("stop", help="stop the receiver")
    recv_stop.add_argument("--agent", default=None)
    recv_stop.add_argument("--quiet", action="store_true")
    recv_stop.set_defaults(func=cmd_receiver_stop)

    recv_status = recv_sub.add_parser("status", help="pid/port/url and health")
    recv_status.add_argument("--json", action="store_true")
    recv_status.set_defaults(func=cmd_receiver_status)

    dp = sub.add_parser("deliver-pending", help="inject waiting receiver messages if the "
                        "agent is ready (called by the tick, T-3684)")
    dp.add_argument("--trigger", default="manual")
    dp.add_argument("--json", action="store_true")
    dp.set_defaults(func=cmd_deliver_pending)

    ak = sub.add_parser("acks", help="direct-path sender ledger: SENT/RECEIVED/"
                        "HANDED_OVER/REPLIED or UNDELIVERABLE/REJECTED/ESCALATED")
    ak.add_argument("id", nargs="?", default=None, help="one message's full history")
    ak.add_argument("--json", action="store_true")
    ak.set_defaults(func=cmd_acks)

    return parser


def main(argv=None) -> int:
    args = build_parser().parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
