#!/usr/bin/env python3
"""`fw sidecar` — the callable surface of the arc-011 peer-consult sidecar.

T-3406, slice 4. Slices 1-3 shipped three library modules with zero callers
outside their own tests. This is what makes them usable by an agent: a verb
it can run, and a verb it can be TOLD to run in a dispatch prompt.

    fw sidecar whoami
    fw sidecar send --to <agent> --body <text> [--hub host:port] [--conversation ID]
    fw sidecar inbox [--json] [--peek]

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
from lib.sidecar import termlink_transport as transport  # noqa: E402


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


def cmd_send(args) -> int:
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


def cmd_status(args) -> int:
    snap = status_mod.snapshot()
    # T-3442: DM rail summary is queried HERE, separately from
    # status_mod.snapshot() — snapshot()'s one design rule is that it reads
    # only our own durable state and never asks the hub (see status.py's
    # module docstring). Listing which dm:* rails exist has no durable
    # answer of its own, so it is merged in at the CLI boundary instead of
    # folded into the hub-free function.
    dm_rows = dm.summary()
    probe = None
    if args.probe:
        # Kept apart from the file-derived numbers on purpose: the hub's
        # self-report must never be able to overwrite what our own ledger says.
        verdict = transport.probe_hub(None)
        probe = {"ok": verdict.ok, "reason": verdict.reason}
    if args.json:
        payload = dict(snap)
        payload["dm_rails"] = dm_rows
        if probe is not None:
            payload["hub_probe"] = probe
        print(json.dumps(payload, indent=2))
        return 0
    print(status_mod.render(snap))
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
    if args.json:
        print(json.dumps(report, indent=2, sort_keys=True))
        return 0
    print(f"swept: {report['considered']} open row(s), {report['due']} due  ->  "
          f"{report['reposted']} reposted, {report['nudged']} nudged, "
          f"{report['operator']} to operator, {report['answered']} answered, "
          f"{report['deadlettered']} dead-lettered")
    for action in report["actions"]:
        detail = action.get("reason") or action.get("state") or ""
        print(f"  {action['verb']:<22} {action['client_msg_id']}  {detail}")
    return 0


def cmd_e2e(args) -> int:
    """Live end-to-end run against the real hub and a real dispatched worker.

    T-3423. Preflight first so a missing hub never costs a worker; then
    lib/sidecar/e2e.py:run with the real collaborators; JSON record under
    .context/sidecar/e2e/<run>.json; exit 0 only when the blocking hops pass.
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
    return 0 if report["verdict"] == "PASS" else 1


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
    send.add_argument("--urgent", action="store_true")
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

    ds = sub.add_parser("dm-stale", help="dm:* rails addressed to us with an unread "
                        "content post older than --threshold-hours (T-3442, "
                        "fw doctor / fw audit fact source)")
    ds.add_argument("--threshold-hours", type=float, default=24.0)
    ds.add_argument("--json", action="store_true")
    ds.set_defaults(func=cmd_dm_stale)

    return parser


def main(argv=None) -> int:
    args = build_parser().parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
