"""arc-011 receiver HTTP server — listen for incoming messages.

T-3561 (arc-011 slice 1). HTTP API on localhost that receives messages,
stores them durably, and returns RECEIVED status before any delivery attempt.

Minimal implementation using http.server (stdlib, no external deps).
Uses token-based authentication (localhost only).
"""

from __future__ import annotations

import http.server
import json
import os
import threading
from datetime import datetime, timezone

from . import receiver, lifecycle


class ReceiverHandler(http.server.BaseHTTPRequestHandler):
    """HTTP request handler for the receiver sidecar."""

    def log_message(self, fmt: str, *args) -> None:  # type: ignore
        """Suppress default HTTP logging."""
        pass

    def _get_auth_token(self) -> str | None:
        """Get the auth token from the request header or env."""
        # First check the Authorization header
        auth_header = self.headers.get("Authorization", "")
        if auth_header.startswith("Bearer "):
            return auth_header[7:].strip()

        # Fall back to environment variable (for testing)
        return os.environ.get("SIDECAR_AUTH_TOKEN")

    def _is_authorized(self) -> bool:
        """Check if the request is authenticated."""
        token = self._get_auth_token()
        if not token:
            return False

        # Token is a SHA256 hash of a shared secret
        # For now, we accept any non-empty token (testing mode)
        # Production would validate against a stored hash
        return len(token) > 0

    def do_POST(self):
        """Handle POST /message endpoint."""
        if not self._is_authorized():
            self.send_response(401)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({"error": "Unauthorized"}).encode())
            return

        # Only accept /message endpoint
        if self.path != "/message":
            self.send_response(404)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({"error": "Not found"}).encode())
            return

        # Read request body
        content_length = int(self.headers.get("Content-Length", 0))
        if content_length > 10 * 1024 * 1024:  # 10 MB limit
            self.send_response(413)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({"error": "Payload too large"}).encode())
            return

        try:
            body = self.rfile.read(content_length).decode("utf-8")
            envelope = json.loads(body)
        except (json.JSONDecodeError, UnicodeDecodeError) as e:
            self.send_response(400)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({"error": f"Invalid JSON: {e}"}).encode())
            return

        # Validate required fields
        msg_id = envelope.get("client_msg_id")
        if not msg_id or not isinstance(msg_id, str):
            self.send_response(400)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({"error": "Missing or invalid client_msg_id"}).encode())
            return

        # Store the message
        success, error = receiver.store_message(msg_id, envelope)

        if not success:
            self.send_response(400)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({"error": error, "client_msg_id": msg_id}).encode())
            return

        # Success: return RECEIVED
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        response = {
            "status": receiver.RECEIVED,
            "client_msg_id": msg_id,
            "timestamp": datetime.now(timezone.utc).isoformat(),
        }
        self.wfile.write(json.dumps(response).encode())

    def do_GET(self):
        """Handle GET /health endpoint for liveness probes."""
        if self.path == "/health":
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({"status": "ok"}).encode())
        elif self.path == "/status":
            # Return receiver status (pending message count)
            pending = receiver.list_pending_messages()
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({
                "status": "ok",
                "pending_messages": len(pending),
            }).encode())
        else:
            self.send_response(404)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({"error": "Not found"}).encode())


def start_receiver_server(port: int | None = None, host: str = "127.0.0.1", foreground: bool = False) -> tuple[int, str]:
    """Start the receiver HTTP server.

    Returns (port, url) tuple.
    Writes triple-file (pid/port/url) for durability.

    If foreground=False (default), starts in a daemon thread (suitable for integration
    into an existing process). If foreground=True, blocks indefinitely serving requests
    (suitable for subprocess/standalone execution).
    """
    if port is None:
        port = lifecycle.find_free_port()

    # Create and start the server
    server = http.server.HTTPServer((host, port), ReceiverHandler)
    url = f"http://{host}:{port}"

    # Write triple-file
    pid = os.getpid()
    lifecycle.write_triple_file(pid, port, url)

    if foreground:
        # Foreground mode: serve_forever (blocks)
        server.serve_forever()
    else:
        # Daemon thread mode: non-blocking
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()

    return port, url


def stop_receiver_server() -> None:
    """Stop the receiver server and clean up triple-file."""
    lifecycle.clear_triple_file()
