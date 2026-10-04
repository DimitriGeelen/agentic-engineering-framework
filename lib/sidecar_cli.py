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
    fw sidecar start|stop|ensure [--all]      (T-3684/T-3685: receiver + supervised watcher)
    fw sidecar liveness | latency | tick      (T-3685 / T-3684)
    fw sidecar waiting [--json]               (T-3782: messages waiting for a recipient)
    fw sidecar recover <id> | drop <id> --reason "..."   (T-3782, operator only)

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
from lib.sidecar import latency as latency_mod, receipts, watcher  # noqa: E402
from lib.sidecar import waiting as waiting_mod  # noqa: E402


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


def _replied_receipt(args) -> None:
    """T-3684: answering a consult that came over the HUB topic tells its
    sender REPLIED (a direct-path original records REPLIED in the sender's own
    receiver already — direct.note_reply)."""
    if not getattr(args, "in_reply_to", None):
        return
    env = receipts.origin(args.in_reply_to)
    if env:
        try:
            receipts.send(env, receipts.REPLIED, by="reply")
        except Exception as e:
            print(f"REPLIED receipt failed: {e}", file=sys.stderr)


def cmd_send(args) -> int:
    rc = _cmd_send(args)
    if rc == 0:
        # REPLIED only for an answer that was actually delivered (RECEIVED by
        # a receiver, or accepted by the hub).
        _replied_receipt(args)
    return rc


def _cmd_send(args) -> int:
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
    try:
        return _print_inbox(args, messages)
    finally:
        # T-3684: a drain took these off the topic — RECEIVED to each sender,
        # only AFTER the output was written. No HANDED_OVER from here: nothing
        # proves where this output went (the transcript-proven paths do that).
        # The prompt hook's peek sends its own receipts for what it showed.
        if messages and not args.peek:
            sys.stdout.flush()
            for m in messages:
                try:
                    receipts.send(m, receipts.RECEIVED, by="inbox-cli")
                except Exception as e:  # never lose the consult over a receipt
                    print(f"receipt for {m.get('client_msg_id')} failed: {e}", file=sys.stderr)


def _print_inbox(args, messages) -> int:
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


def _inbox_topic_check() -> dict:
    """OK / FAIL / UNKNOWN for this agent's own inbox topic (T-3803).

    FAIL names the topic and the remedy. UNKNOWN when it could not be asked
    (no termlink, no address, hub refused the list) — never OK by default.
    """
    import shutil
    if shutil.which("termlink") is None:
        return {"verdict": "UNKNOWN", "topic": None, "reason": "termlink absent"}
    try:
        topic = inbox.inbox_topic()
    except circuit.CircuitError as exc:
        return {"verdict": "UNKNOWN", "topic": None, "reason": str(exc)}
    present, reason = inbox.topic_present(topic)
    if present:
        return {"verdict": "OK", "topic": topic, "reason": topic}
    if present is False:
        return {"verdict": "FAIL", "topic": topic,
                "reason": f"{topic} does not exist on the hub; peers' consults "
                          "cannot be read until it does (fw sidecar ensure creates it)"}
    return {"verdict": "UNKNOWN", "topic": topic, "reason": reason}


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
    topic_check = _inbox_topic_check()
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
        payload["inbox_topic_check"] = topic_check
        if probe is not None:
            payload["hub_probe"] = probe
        payload["watcher"] = dict(watcher.liveness_verdict(), supervisor_alive=watcher.supervisor_alive())
        print(json.dumps(payload, indent=2, default=str))
        return 0
    print(status_mod.render(snap))
    # Printed unconditionally, including the zero. "inbound unread: 0" is a
    # measurement; the absence of a line is indistinguishable from a check
    # that was never made, which is the state this whole task is about.
    # T-3803: a missing topic is a FAIL by name, not a silent 0 — the reader
    # turns the hub's "unknown topic" into an empty list.
    print(f"inbox topic:      {topic_check['verdict']} — {topic_check['reason']}")
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
    # T-3685: the watcher, in the one status command an operator reaches for.
    wv = watcher.liveness_verdict()
    live = wv.get("liveness") or {}
    print(f"watcher:          {wv['state']}  seq={live.get('seq')} tick={live.get('tick_s')}s "
          f"probe_ok={live.get('last_probe_ok')} supervisor={'up' if watcher.supervisor_alive() else 'down'} "
          f"termlink={live.get('termlink', 'unknown')}")
    for r in wv["reasons"]:
        print(f"  - {r}")
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


def _start_receiver(agent: str, port, no_inject: bool, quiet: bool) -> tuple[int, dict | None]:
    """Start the receiver process. (rc, triple-file info): rc 0 started,
    1 already running, 2 refused/failed."""
    import subprocess
    import time

    info = lifecycle.read_triple_file()
    if (info and lifecycle.is_receiver_alive(info) and lifecycle.health(str(info["url"]))
            and not watcher.is_stale(info.get("pid"))):
        if not quiet:
            print(f"receiver already running: pid={info['pid']} url={info['url']}")
        return 1, info
    if info and lifecycle.is_receiver_alive(info):
        # T-3685: running code older than what is on disk — replace it, so a
        # fix (e.g. T-3745's per-session targeting) is actually live.
        import signal as _sig
        if not quiet:
            print(f"receiver pid={info['pid']} runs stale code — restarting it")
        os.kill(int(info["pid"]), _sig.SIGTERM)
        for _ in range(50):
            if not lifecycle.pid_alive(info["pid"]):
                break
            time.sleep(0.1)
        if lifecycle.pid_alive(info["pid"]):
            os.kill(int(info["pid"]), _sig.SIGKILL)
    if info:
        lifecycle.clear_triple_file()

    try:
        lifecycle.write_token()
    except OSError as e:
        print(f"receiver: refusing to start — cannot write token: {e}", file=sys.stderr)
        return 2, None
    lifecycle.write_config(inject=not no_inject)

    root = str(receiver._root().resolve())
    env = dict(os.environ, PROJECT_ROOT=root)
    log = open(receiver._receiver_dir() / "server.log", "ab")
    server_py = os.path.join(os.path.dirname(os.path.abspath(__file__)), "sidecar", "http_server.py")
    proc = subprocess.Popen(
        [sys.executable, server_py, "--port", str(port or 0), "--agent", agent],
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
            return 2, None
        time.sleep(0.1)
    else:
        proc.terminate()
        print("receiver: server did not come up within 10s", file=sys.stderr)
        return 2, None

    if not quiet:
        print(f"receiver started: agent={agent} pid={info['pid']} port={info['port']}")
        print(f"  url:    {info['url']}")
        print(f"  token:  {lifecycle.token_path()} (mode 0600)")
        print(f"  inject: {'enabled' if not no_inject else 'DISABLED (--no-inject)'}")
    return 0, info


def _start_watcher(agent: str, tick, no_inject: bool, quiet: bool) -> dict:
    """Enable + start the supervised watcher (T-3684/T-3685). A supervisor or
    watcher running stale code is replaced."""
    watcher.enable(agent, tick, inject_on=not no_inject)
    if watcher.is_stale(watcher.read_pid("supervisor")) or watcher.is_stale(watcher.read_pid("watcher")):
        watcher.stop_processes()
        watcher.record_event("STALE_CODE_RESTART")
    res = watcher.start_supervisor()
    if not quiet:
        tl = "present" if __import__("shutil").which("termlink") else \
            "ABSENT — inert: messages are stored and confirmed RECEIVED, never injected"
        state = "started" if res.get("started") else res.get("reason", "")
        print(f"watcher {state}: supervisor pid={res.get('pid')} "
              f"tick={watcher.tick_seconds(tick):g}s termlink={tl}")
    return res


def _ensure_inbox_topic(agent: str | None, quiet: bool) -> dict:
    """T-3803: create the owner's inbox topic at receiver start / ensure.

    Before this, only a sender's `--ensure-topic` post created it, so a fresh
    project read "unknown topic" until a peer happened to write first. A
    failure is printed (stderr), never swallowed; termlink absent is reported
    as skipped, since there is no hub to create it on.
    """
    import shutil
    if shutil.which("termlink") is None:
        return {"topic": None, "ok": False, "action": "skipped", "reason": "termlink absent"}
    try:
        row = inbox.ensure_topic(agent or None)
    except circuit.CircuitError as exc:  # no address: report, never abort the start
        row = {"topic": None, "ok": False, "action": "failed", "reason": str(exc)}
    if not row["ok"]:
        print(f"inbox topic: FAIL — could not create {row['topic']}: {row['reason']}",
              file=sys.stderr)
    elif not quiet:
        print(f"inbox topic: {row['action']} {row['topic']}")
    return row


def cmd_receiver_start(args) -> int:
    """Start the per-agent receiver (T-3693) and, unless --no-watcher, its
    supervised watcher (T-3684/T-3685).

    Order is the contract (T-3475): the 0600 token is written FIRST; the
    server process reads it and refuses to bind without it; only after it has
    bound does it write the triple-file and the host registry entry. Exit 0
    started, 1 already running, 2 refused/failed.
    """
    agent = args.agent or _agent_or_none()
    if not agent:
        return 2
    rc, _info = _start_receiver(agent, args.port, args.no_inject, args.quiet)
    if rc != 2:
        _ensure_inbox_topic(agent, args.quiet)
    if rc == 0 and not args.no_watcher:
        _start_watcher(agent, args.tick, args.no_inject, args.quiet)
    return rc


def cmd_start(args) -> int:
    """`fw sidecar start`: receiver (if not running) + supervised watcher.
    Exit 0 when both are up (already-running counts), 2 on failure."""
    agent = args.agent or _agent_or_none()
    if not agent:
        return 2
    rc, info = _start_receiver(agent, args.port, args.no_inject, args.quiet)
    if rc == 2:
        return 2
    topic_row = _ensure_inbox_topic(agent, args.quiet or args.json)
    res = _start_watcher(agent, args.tick, args.no_inject, args.quiet)
    if args.json:
        print(json.dumps({"receiver": info, "watcher": res, "inbox_topic": topic_row, "tick_s": watcher.tick_seconds(args.tick),
                          "liveness": watcher.liveness_verdict()["state"]}))
    return 0 if (res.get("started") or res.get("reason") == "already running") else 2


def cmd_stop(args) -> int:
    """`fw sidecar stop`: disable and stop the watcher, then the receiver."""
    stopped = watcher.stop_all()
    if not args.quiet:
        print(f"watcher stopped: {stopped or 'was not running'}")
    return cmd_receiver_stop(args)


def cmd_ensure(args) -> int:
    """Cron / @reboot / claude-fw entry. Here: if this project's sidecar is
    enabled and its supervisor is not running, start it (and the receiver).
    --all: every enabled project on this host."""
    if args.all:
        rows = watcher.ensure_all()
        if args.json:
            print(json.dumps(rows))
        else:
            for r in rows:
                print(f"{r.get('project_root')}: {r.get('action') or r.get('error')}")
        return 0
    cfg = watcher.read_enabled()
    row = {"enabled": cfg is not None}
    if cfg is None and args.autostart and not watcher.stopped_marker().exists():
        # SessionStart (R14): never started here → start it now.
        agent = _agent_or_none()
        if agent:
            rc, _ = _start_receiver(agent, None, False, True)
            res = _start_watcher(agent, None, False, True) if rc != 2 else {"reason": "receiver failed"}
            row["action"] = f"autostarted: {res.get('reason') or 'started'}"
        else:
            row["action"] = "autostart: no agent name"
    elif cfg is None:
        row["action"] = ("explicitly stopped (fw sidecar start re-enables)"
                         if watcher.stopped_marker().exists()
                         else "not enabled (fw sidecar start enables it)")
    else:
        rc, _ = _start_receiver(str(cfg.get("agent") or _agent_or_none() or ""), None,
                                not cfg.get("inject", True), True)
        row["receiver"] = {0: "restarted", 1: "running", 2: "FAILED"}[rc]
        if watcher.is_stale(watcher.read_pid("supervisor")) or watcher.is_stale(watcher.read_pid("watcher")):
            watcher.stop_processes()
            watcher.record_event("STALE_CODE_RESTART")
        if watcher.supervisor_alive():
            row["action"] = "supervisor running"
        else:
            res = watcher.start_supervisor()
            watcher.record_event("SUPERVISOR_ENSURED", result=res.get("reason") or "started")
            row["action"] = f"supervisor restarted pid={res.get('pid')}"
    # T-3803: every ensure (cron, @reboot, SessionStart) also makes sure the
    # owner's inbox topic exists, enabled or not — `fw sidecar inbox` reads it
    # either way, and an absent topic otherwise stays absent until a peer posts.
    t = _ensure_inbox_topic((cfg or {}).get("agent") or None, True)
    row["inbox_topic"] = {"topic": t["topic"], "action": t["action"], "reason": t["reason"]}
    if args.json:
        print(json.dumps(row))
    else:
        print(row["action"])
    return 0


def cmd_liveness(args) -> int:
    """The liveness verdict doctor/audit read. Exit 0 live, 1 not-live, 2 absent."""
    v = watcher.liveness_verdict()
    v["supervisor_alive"] = watcher.supervisor_alive()
    v["injection_transport"] = "present" if __import__("shutil").which("termlink") else "absent"
    if args.json:
        print(json.dumps(v, default=str))
    else:
        live = v.get("liveness") or {}
        print(f"sidecar watcher: {v['state']}  seq={live.get('seq')} age={v.get('age_s')}s "
              f"probe_ok={live.get('last_probe_ok')} supervisor={'up' if v['supervisor_alive'] else 'down'} "
              f"termlink={v['injection_transport']}")
        for r in v["reasons"]:
            print(f"  - {r}")
    return {"live": 0, "not-live": 1}.get(v["state"], 2)


def cmd_latency(args) -> int:
    rep = latency_mod.report()
    print(json.dumps(rep, indent=2) if args.json else latency_mod.render(rep))
    return 0


def cmd_receipts(args) -> int:
    rows = {"received": receipts.read_ledger(), "sent": receipts.read_sent()}
    if args.json:
        print(json.dumps(rows, indent=2))
        return 0
    for r in rows["received"]:
        print(f"recv  {r['ts']}  {r['state']:<11} {r['client_msg_id']}  {r['by']} via {r.get('via')}")
    for r in rows["sent"]:
        print(f"sent  {r['ts']}  {r['state']:<11} {r['client_msg_id']}  to {r.get('to')} "
              f"{'ok via ' + str(r.get('via')) if r.get('ok') else 'FAILED: ' + str(r.get('error'))}")
    return 0


def cmd_tick(args) -> int:
    """Run ONE watcher tick now, in the foreground (diagnostics)."""
    live = watcher.read_liveness() or {}
    rep = watcher.run_tick(int(live.get("seq") or 0) + 1, watcher.tick_seconds())
    print(json.dumps(rep, indent=2, default=str))
    return 0


def cmd_receiver_stop(args) -> int:
    """Stop the receiver: SIGTERM, wait, SIGKILL only if it will not go.
    The watcher is stopped (and disabled) FIRST, or its supervisor would
    restart the receiver this just stopped."""
    import signal
    import time

    if watcher.read_enabled() is not None or watcher.supervisor_alive():
        watcher.stop_all()

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
                   "ready_for_input": adapter.is_ready_for_input(),
                   "sessions": [{k: r.get(k) for k in ("session_id", "termlink_session",
                                                       "ready", "alive", "updated_at")}
                                for r in adapter.session_records()],
                   "watcher": watcher.liveness_verdict()["state"]}
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
        print(f"  watcher:           {payload['watcher']}")
        for r in payload["sessions"]:
            print(f"  session {str(r['session_id'])[:12]:<12} ready={r['ready']} "
                  f"termlink={r['termlink_session']} alive={r['alive']}")
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


def cmd_waiting(args) -> int:
    """T-3782: every message waiting for a recipient, both directions."""
    items = waiting_mod.open_items()
    if args.json:
        print(json.dumps({"items": items, "warn_hours": waiting_mod.warn_hours(),
                          "overdue_hours": waiting_mod.overdue_hours()}, indent=2, default=str))
    else:
        print(waiting_mod.render(items))
    return 0


def _operator(args, verb: str) -> str | None:
    """Who is acting, or None when refused. Operator verbs (T-3782): refused
    under CLAUDECODE=1 unless --i-am-human (recorded as agent-override);
    Watchtower posts --from-watchtower with CLAUDECODE stripped. --from-watchtower
    does NOT lift the refusal for an agent: the agent shell is the one place
    it must not be accepted from."""
    if os.environ.get("CLAUDECODE") == "1":
        if not args.i_am_human:
            print(f"fw sidecar {verb}: operator-only — refused under CLAUDECODE=1. The operator "
                  f"runs it, or uses the Recover / Drop buttons on Watchtower /approvals. "
                  f"Override for scripts and tests: --i-am-human (recorded).", file=sys.stderr)
            return None
        return "agent-override"
    if args.from_watchtower:
        return "watchtower"
    return "human"


def cmd_recover(args) -> int:
    by = _operator(args, "recover")
    if by is None:
        return 2
    try:
        row = waiting_mod.recover(args.id, by=by)
    except waiting_mod.OperatorRefusal as e:
        print(f"fw sidecar recover: {e}", file=sys.stderr)
        return 1
    if args.json:
        print(json.dumps(row, indent=2))
        return 0
    print(f"recover: started {row['termlink_session']} (claude-fw --termlink, wrapper pid "
          f"{row['wrapper_pid']}) for message {row['id']} from {row.get('peer')}, "
          f"conversation {row.get('conversation_id') or '-'}")
    print(f"  watch:  termlink attach {row['termlink_session']}")
    print(f"  log:    {row['log']}")
    print("  HANDED_OVER is recorded when the new session's transcript shows the message "
          f"(within {waiting_mod.RECOVER_CONFIRM_S:.0f}s); until then it stays listed.")
    return 0


def cmd_drop(args) -> int:
    by = _operator(args, "drop")
    if by is None:
        return 2
    try:
        row = waiting_mod.drop(args.id, args.reason or "", by=by)
    except waiting_mod.OperatorRefusal as e:
        print(f"fw sidecar drop: {e}", file=sys.stderr)
        return 1
    if args.json:
        print(json.dumps(row, indent=2))
        return 0
    told = ""
    if row["side"] == "inbound":
        told = (" — sender told (DROPPED receipt)" if row.get("sender_told")
                else f" — sender NOT told: {row.get('sender_told_via')}")
    print(f"drop: closed {row['side']} message {row['id']} ({row.get('peer')}): "
          f"{row['reason']}{told}")
    return 0


def cmd_recover_finalize(args) -> int:
    row = waiting_mod.finalize_recover(args.id, args.token)
    print(json.dumps(row))
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
    recv_start.add_argument("--no-watcher", action="store_true",
                            help="receiver only; do not start the supervised watcher (T-3684)")
    recv_start.add_argument("--tick", type=float, default=None,
                            help="watcher tick seconds (default SIDECAR_TICK, 30)")
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

    # T-3684 / T-3685: the supervised watcher
    st_ = sub.add_parser("start", help="start this agent's sidecar: receiver + supervised "
                         "watcher (tick every SIDECAR_TICK s, default 30)")
    st_.add_argument("--agent", default=None)
    st_.add_argument("--port", type=int, default=None)
    st_.add_argument("--tick", type=float, default=None)
    st_.add_argument("--no-inject", action="store_true",
                     help="store and confirm, never inject (negative control)")
    st_.add_argument("--quiet", action="store_true")
    st_.add_argument("--json", action="store_true")
    st_.set_defaults(func=cmd_start)

    sp_ = sub.add_parser("stop", help="stop and disable the watcher and the receiver")
    sp_.add_argument("--agent", default=None)
    sp_.add_argument("--quiet", action="store_true")
    sp_.set_defaults(func=cmd_stop)

    en_ = sub.add_parser("ensure", help="restart an enabled sidecar whose supervisor is gone "
                         "(cron sidecar-ensure-1m, @reboot, claude-fw)")
    en_.add_argument("--all", action="store_true",
                     help="every enabled project on this host")
    en_.add_argument("--autostart", action="store_true",
                     help="SessionStart: also start a sidecar never started here (not one explicitly stopped)")
    en_.add_argument("--json", action="store_true")
    en_.set_defaults(func=cmd_ensure)

    lv_ = sub.add_parser("liveness", help="watcher liveness verdict (exit 0 live, 1 not-live, 2 absent)")
    lv_.add_argument("--json", action="store_true")
    lv_.set_defaults(func=cmd_liveness)

    la_ = sub.add_parser("latency", help="send→RECEIVED and send→HANDED_OVER per message "
                         "(median, p95, max), from the ledgers")
    la_.add_argument("--json", action="store_true")
    la_.set_defaults(func=cmd_latency)

    rf_ = sub.add_parser("receipts-flush", help=argparse.SUPPRESS)
    rf_.add_argument("path")
    rf_.set_defaults(func=lambda a: (receipts.flush(a.path), 0)[1])

    rc_ = sub.add_parser("receipts", help="hub-path delivery receipts: received for what we "
                         "sent, and sent for what we took off the topic (T-3684)")
    rc_.add_argument("--json", action="store_true")
    rc_.set_defaults(func=cmd_receipts)

    tk_ = sub.add_parser("tick", help="run one watcher tick now, in the foreground")
    tk_.set_defaults(func=cmd_tick)

    wt_ = sub.add_parser("waiting", help="messages waiting for a recipient, both directions, "
                         "until handed over, replied or dropped (T-3782)")
    wt_.add_argument("--json", action="store_true")
    wt_.set_defaults(func=cmd_waiting)

    for name, func, hlp in (
            ("recover", cmd_recover, "operator: start this project's agent (claude-fw "
             "--termlink) with a waiting message as its first prompt (T-3782)"),
            ("drop", cmd_drop, "operator: close a waiting message unhandled, with a reason; "
             "the sender is told (T-3782)")):
        op = sub.add_parser(name, help=hlp)
        op.add_argument("id", help="client_msg_id (or a unique prefix of 8+ characters)")
        if name == "drop":
            op.add_argument("--reason", required=True)
        op.add_argument("--json", action="store_true")
        op.add_argument("--i-am-human", action="store_true", dest="i_am_human")
        op.add_argument("--from-watchtower", action="store_true", dest="from_watchtower")
        op.set_defaults(func=func)

    rfz_ = sub.add_parser("recover-finalize", help=argparse.SUPPRESS)
    rfz_.add_argument("id")
    rfz_.add_argument("--token", required=True)
    rfz_.set_defaults(func=cmd_recover_finalize)

    return parser


def main(argv=None) -> int:
    args = build_parser().parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
