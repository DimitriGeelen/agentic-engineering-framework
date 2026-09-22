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

from lib.sidecar import delivery, inbox, outbox, status as status_mod  # noqa: E402
from lib.sidecar import termlink_transport as transport  # noqa: E402


def cmd_whoami(args) -> int:
    payload = {"agent_id": inbox.agent_id(), "inbox_topic": inbox.inbox_topic()}
    if args.json:
        print(json.dumps(payload))
    else:
        print(f"agent_id:    {payload['agent_id']}")
        print(f"inbox topic: {payload['inbox_topic']}")
    return 0


def cmd_send(args) -> int:
    client_msg_id = outbox.write_message(
        from_id=inbox.agent_id(), to=args.to, body=args.body,
        conversation_id=args.conversation or f"consult-{args.to}",
        urgent=args.urgent, hub=args.hub)

    result = delivery.deliver(client_msg_id, transport.termlink_transport,
                              transport.probe_hub)

    payload = {
        "client_msg_id": result.client_msg_id,
        "state": result.state,
        "delivered": result.delivered,
        "reason": result.reason,
        "topic": f"sidecar:{args.to}",
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
    if args.json:
        print(json.dumps(messages, indent=2))
        return 0
    if not messages:
        print(f"no pending consults on {inbox.inbox_topic()}")
        return 0
    for msg in messages:
        sender = msg.get("from") or "unknown"
        print(f"--- consult @{msg.get('offset')} from {sender} "
              f"[{msg.get('conversation_id')}] ---")
        print(msg.get("body", ""))
        print()
    return 0


def cmd_status(args) -> int:
    snap = status_mod.snapshot()
    probe = None
    if args.probe:
        # Kept apart from the file-derived numbers on purpose: the hub's
        # self-report must never be able to overwrite what our own ledger says.
        verdict = transport.probe_hub(None)
        probe = {"ok": verdict.ok, "reason": verdict.reason}
    if args.json:
        payload = dict(snap)
        if probe is not None:
            payload["hub_probe"] = probe
        print(json.dumps(payload, indent=2))
        return 0
    print(status_mod.render(snap))
    if probe is not None:
        print(f"hub probe:        {'ok' if probe['ok'] else 'REFUSED'} — {probe['reason']}")
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

    return parser


def main(argv=None) -> int:
    args = build_parser().parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
