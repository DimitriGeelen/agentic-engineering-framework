"""govd_holder — the privileged state-holder daemon `aef-govd` (arc-013 / T-2430).

The keystone of the payload-mediation arc (design doc §4e). It owns the
authoritative governance state; on-disk files become read-only projections of the
holder's record (the inversion principle). The agent submits PROPOSALS over a unix
socket and may commit only WITHIN the sovereign-authored envelope
(lib/govd_envelope); everything else queues for the human, whose commits arrive on
the same socket but are authenticated by SO_PEERCRED (peer uid == sovereign uid).

FIRST REVIEWABLE CUT (T-2430): the decision logic, the append-only audit, the
state store, and the socket principal-check are real and tested. The hard security
boundary — running as a dedicated non-agent uid with the envelope + state on RO
bind-mounts so the agent uid gets EPERM — is Lock-1 Part 1 (root install), emitted
by `agents/govd/govd.sh emit-install` and NEVER run by the agent.

  request  = {"op": "propose"|"commit"|"query", "decision": {...}, "payload": {...}}
  response = {"ok": bool, "commit": "agent"|"human", "tier_log": int,
              "reason": str, "audit_id": str}
"""
from __future__ import annotations

import json
import os
import socket
import socketserver
import struct
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from lib import govd_envelope  # noqa: E402


class AppendOnlyAudit:
    """JSONL audit log. App-level append-only; in deployment the file is `chattr +a`
    on an RO-to-the-agent mount (Lock-1 Part 1) so it is truly tamper-evident."""

    def __init__(self, path: str | Path):
        self.path = Path(path)
        self.path.parent.mkdir(parents=True, exist_ok=True)

    def append(self, event: dict) -> str:
        audit_id = "A-%d-%d" % (int(time.time() * 1000), os.getpid())
        rec = {"audit_id": audit_id, "ts": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()), **event}
        with open(self.path, "a") as f:           # append mode only — never truncate/rewrite
            f.write(json.dumps(rec) + "\n")
        return audit_id


class StateStore:
    """Authoritative governance state (focus, approvals, …). The on-disk projection
    is whatever the holder writes here; agent-side files mirror it read-only."""

    def __init__(self, path: str | Path):
        self.path = Path(path)
        self.path.parent.mkdir(parents=True, exist_ok=True)
        if not self.path.exists():
            self.path.write_text("{}")

    def read(self) -> dict:
        try:
            return json.loads(self.path.read_text() or "{}")
        except json.JSONDecodeError:
            return {}

    def commit(self, key: str, value) -> None:
        st = self.read()
        st[key] = value
        tmp = self.path.with_suffix(".tmp")
        tmp.write_text(json.dumps(st, indent=2))
        os.replace(tmp, self.path)               # atomic


class Holder:
    """Decision broker. `handle()` is pure of sockets so it is directly testable."""

    # which decision types mutate state, and under which state key
    STATE_KEYS = {
        "focus_change": "focus",
        "inception_go": "last_inception_decision",
        "dispatch_approve": "last_dispatch_approval",
    }

    def __init__(self, envelope_path, audit_path, state_path, sovereign_uid: int):
        self.envelope_path = envelope_path
        self.audit = AppendOnlyAudit(audit_path)
        self.state = StateStore(state_path)
        self.sovereign_uid = sovereign_uid

    def handle(self, request: dict, peer_uid: int) -> dict:
        op = request.get("op", "propose")
        decision = request.get("decision") or {}
        payload = request.get("payload") or {}

        if op == "query":
            return {"ok": True, "state": self.state.read()}

        # commit: sovereign-only path for human-approved (previously queued) items
        if op == "commit":
            if peer_uid != self.sovereign_uid:
                aid = self.audit.append({"event": "commit_denied", "peer_uid": peer_uid,
                                         "decision": decision, "reason": "not sovereign"})
                return {"ok": False, "reason": "commit requires sovereign principal",
                        "audit_id": aid}
            return self._apply(decision, payload, committer="sovereign")

        # propose: evaluate against the envelope (fail closed on load error)
        try:
            envelope = govd_envelope.load_envelope(self.envelope_path)
        except Exception as e:  # noqa: BLE001 — fail closed, route to human
            aid = self.audit.append({"event": "envelope_error", "error": repr(e),
                                     "decision": decision})
            return {"ok": False, "commit": "human", "tier_log": 0,
                    "reason": f"envelope unavailable: {e}", "audit_id": aid}

        verdict = govd_envelope.evaluate(envelope, decision)
        if verdict["commit"] == "agent":
            res = self._apply(decision, payload, committer="agent",
                              tier_log=verdict["tier_log"], reason=verdict["reason"])
            return res
        # human: queue it (record only; the actual commit comes later via op=commit)
        aid = self.audit.append({"event": "queued_for_human", "peer_uid": peer_uid,
                                 "decision": decision, "tier_log": verdict["tier_log"],
                                 "reason": verdict["reason"]})
        return {"ok": True, "commit": "human", "tier_log": verdict["tier_log"],
                "reason": verdict["reason"], "audit_id": aid}

    def _apply(self, decision, payload, committer, tier_log=2, reason="sovereign commit"):
        dtype = decision.get("type", "")
        key = self.STATE_KEYS.get(dtype)
        if key is not None:
            self.state.commit(key, payload or decision)
        aid = self.audit.append({"event": "committed", "committer": committer,
                                 "decision": decision, "tier_log": tier_log, "reason": reason})
        return {"ok": True, "commit": committer, "tier_log": tier_log,
                "reason": reason, "audit_id": aid}


def _peer_uid(conn: socket.socket) -> int:
    """uid of the connecting process via SO_PEERCRED (Linux). The principal check."""
    creds = conn.getsockopt(socket.SOL_SOCKET, socket.SO_PEERCRED, struct.calcsize("3i"))
    _pid, uid, _gid = struct.unpack("3i", creds)
    return uid


def serve(socket_path: str, holder: Holder) -> None:
    if os.path.exists(socket_path):
        os.unlink(socket_path)

    class Handler(socketserver.StreamRequestHandler):
        def handle(self):
            try:
                line = self.rfile.readline()
                request = json.loads(line or b"{}")
                resp = holder.handle(request, _peer_uid(self.connection))
            except Exception as e:  # noqa: BLE001
                resp = {"ok": False, "reason": f"bad request: {e}"}
            self.wfile.write((json.dumps(resp) + "\n").encode())

    class Server(socketserver.ThreadingMixIn, socketserver.UnixStreamServer):
        daemon_threads = True

    srv = Server(socket_path, Handler)
    os.chmod(socket_path, 0o660)  # group-reachable; the agent uid is in the group
    srv.serve_forever()


def _main(argv) -> int:
    import argparse
    ap = argparse.ArgumentParser(prog="govd_holder")
    ap.add_argument("--envelope", default=os.environ.get("AEF_ENVELOPE", "policy/authority-envelope.yaml"))
    ap.add_argument("--audit", default=os.environ.get("AEF_AUDIT", ".context/govd/audit.jsonl"))
    ap.add_argument("--state", default=os.environ.get("AEF_STATE", ".context/govd/state.json"))
    ap.add_argument("--socket", default=os.environ.get("AEF_SOCKET", ".context/govd/aef-govd.sock"))
    ap.add_argument("--sovereign-uid", type=int, default=int(os.environ.get("AEF_SOVEREIGN_UID", "0")))
    ap.add_argument("--serve", action="store_true", help="run the socket server (else one-shot eval on --request)")
    ap.add_argument("--request", help="one-shot: JSON request, evaluated as the current uid")
    args = ap.parse_args(argv[1:])

    holder = Holder(args.envelope, args.audit, args.state, args.sovereign_uid)
    if args.serve:
        serve(args.socket, holder)
        return 0
    if args.request:
        resp = holder.handle(json.loads(args.request), os.getuid())
        print(json.dumps(resp, indent=2))
        return 0 if resp.get("ok") else 1
    ap.print_help()
    return 2


if __name__ == "__main__":
    raise SystemExit(_main(sys.argv))
