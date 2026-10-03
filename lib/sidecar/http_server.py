"""arc-011 receiver HTTP server — the per-agent receiving sidecar's API.

T-3561 / T-3693 (arc-011 slice 1). Localhost HTTP, stdlib only.

    POST /message   store durably, set the flag, answer RECEIVED (CONFIRM-1);
                    then, after the response, inject if the agent is ready
                    (store-then-maybe-inject, T-3397:93-95)
    POST /ack       CONFIRM-2 from a peer's receiver: a message WE sent was
                    handed over to that peer's agent
    GET  /health    liveness
    GET  /status    pending count, injection enabled

Authentication (T-3475): every POST must carry `Authorization: Bearer <token>`
matching .context/sidecar/receiver.token, compared in constant time. The token
is read BEFORE the port is bound; with no token the server refuses to start.
A refused caller gets 401 and its message is never stored, so never injected.
"""

from __future__ import annotations

import argparse
import hmac
import http.server
import json
import os
import sys
import threading
from datetime import datetime, timezone

if __package__ in (None, ""):
    sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
    __package__ = "lib.sidecar"

from . import direct, inject, lifecycle, receipts, receiver  # noqa: E402

MAX_BODY = 10 * 1024 * 1024


class ReceiverHandler(http.server.BaseHTTPRequestHandler):
    """HTTP request handler for the receiver sidecar."""

    token: str = ""            # set by make_server()
    inject_on_store = True     # False in unit tests that drive inject themselves

    def log_message(self, fmt: str, *args) -> None:  # type: ignore[override]
        pass

    def _reply(self, status: int, payload: dict) -> None:
        body = json.dumps(payload).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _is_authorized(self) -> bool:
        header = self.headers.get("Authorization", "")
        if not header.startswith("Bearer ") or not self.token:
            return False
        return hmac.compare_digest(header[7:].strip().encode(), self.token.encode())

    def _read_json(self):
        length = int(self.headers.get("Content-Length", 0) or 0)
        if length > MAX_BODY:
            self._reply(413, {"error": "payload too large"})
            return None
        try:
            return json.loads(self.rfile.read(length).decode("utf-8"))
        except (json.JSONDecodeError, UnicodeDecodeError) as e:
            self._reply(400, {"error": f"invalid JSON: {e}"})
            return None

    def do_POST(self):  # noqa: N802
        if not self._is_authorized():
            receiver.record_event("-", direct.REJECTED, path=self.path,
                                  reason="missing or invalid bearer token")
            self._reply(401, {"error": "unauthorized"})
            return
        if self.path == "/message":
            self._handle_message()
        elif self.path == "/ack":
            self._handle_ack()
        else:
            self._reply(404, {"error": "not found"})

    def _handle_message(self) -> None:
        envelope = self._read_json()
        if envelope is None:
            return
        msg_id = envelope.get("client_msg_id")
        if not msg_id or not isinstance(msg_id, str):
            self._reply(400, {"error": "missing or invalid client_msg_id"})
            return
        ok, error = receiver.store_message(msg_id, envelope)
        if not ok:
            status = 409 if error.startswith("conflict") else 400
            receiver.record_event(msg_id, direct.REJECTED, reason=error)
            self._reply(status, {"error": error, "client_msg_id": msg_id})
            return
        # A stored message may answer one we sent: REPLIED is ours to record.
        direct.note_reply(envelope)
        self._reply(200, {"status": receiver.RECEIVED, "client_msg_id": msg_id,
                          "timestamp": datetime.now(timezone.utc).isoformat()})
        if self.inject_on_store:
            # After the response: the sender's CONFIRM-1 never waits on the
            # agent's state, and a busy agent never loses a stored message.
            threading.Thread(target=inject.deliver_pending,
                             kwargs={"trigger": "on-store"}, daemon=True).start()

    def _handle_ack(self) -> None:
        payload = self._read_json()
        if payload is None:
            return
        cid, state = str(payload.get("client_msg_id", "")), str(payload.get("state", ""))
        note, since = payload.get("note"), payload.get("since")
        ok = direct.confirm_from_peer(cid, state, payload.get("peer"), note=note, since=since)
        if not ok:
            # T-3684: a receipt (RECEIVED / HANDED_OVER / REPLIED) for a
            # consult we sent over the HUB topic — recorded only if our
            # outbox sent that id to that peer.
            ok = receipts.record_from_peer(cid, state, payload.get("peer"), via="direct",
                                           note=note, since=since)
        self._reply(200 if ok else 404,
                    {"recorded": ok, "client_msg_id": payload.get("client_msg_id")})

    def do_GET(self):  # noqa: N802
        if self.path == "/health":
            self._reply(200, {"status": "ok"})
        elif self.path == "/status":
            self._reply(200, {"status": "ok",
                              "pending_messages": len(receiver.awaiting_handover()),
                              "inject_enabled": lifecycle.inject_enabled()})
        else:
            self._reply(404, {"error": "not found"})


def make_server(port: int, token: str, host: str = "127.0.0.1",
                inject_on_store: bool = True) -> http.server.ThreadingHTTPServer:
    """Bind the server. Refuses (ValueError) without a token — auth exists
    before the port opens, never after."""
    if not token:
        raise ValueError("receiver refuses to start without an auth token")
    handler = type("BoundReceiverHandler", (ReceiverHandler,),
                   {"token": token, "inject_on_store": inject_on_store})
    return http.server.ThreadingHTTPServer((host, port), handler)


def serve(port: int, agent: str) -> int:
    """Foreground entry point used by `fw sidecar receiver start`."""
    token = lifecycle.read_token()
    if not token:
        print("receiver: no token at "
              f"{lifecycle.token_path()} — refusing to open a port", file=sys.stderr)
        return 2
    server = make_server(port, token)
    bound = server.server_address[1]
    url = f"http://127.0.0.1:{bound}"
    lifecycle.write_triple_file(os.getpid(), bound, url)
    lifecycle.register(agent, url, os.getpid())

    import signal

    def _stop(*_):
        threading.Thread(target=server.shutdown, daemon=True).start()
    signal.signal(signal.SIGTERM, _stop)
    signal.signal(signal.SIGINT, _stop)
    try:
        server.serve_forever()
    finally:
        server.server_close()
        info = lifecycle.read_triple_file()
        if info and info.get("pid") == os.getpid():
            lifecycle.clear_triple_file()
        lifecycle.unregister(agent, os.getpid())
    return 0


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description="arc-011 receiver sidecar (foreground)")
    ap.add_argument("--port", type=int, default=0)
    ap.add_argument("--agent", required=True)
    args = ap.parse_args(argv)
    return serve(args.port, args.agent)


if __name__ == "__main__":
    sys.exit(main())
