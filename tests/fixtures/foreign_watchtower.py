#!/usr/bin/env python3
"""A stand-in for ANOTHER project's Watchtower (T-2802 fixture).

Binds an ephemeral port, writes the port number to argv[1], and answers every
GET with an /api/_identity payload naming a different project_root. That is
exactly the shape `fw watchtower url` must refuse to adopt as its own.

Kept as a file rather than a heredoc inside the .bats: a heredoc feeding a
backgrounded process wedges bats (L-408).
"""
import http.server
import json
import socketserver
import sys


class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):  # noqa: N802 (stdlib naming)
        body = json.dumps(
            {
                "service": "watchtower",
                "project_root": "/opt/some-other-project",
                "version": "foreign-fixture",
            }
        ).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *args):
        pass


def expire_with_port_file(srv, port_file, max_seconds=600):
    """T-4976: stop when the test's temp dir (and so the port file) is gone, or after
    max_seconds, so a killed bats run cannot leave this server behind for days."""
    import os, threading, time

    def watch():
        end = time.monotonic() + max_seconds
        while time.monotonic() < end and os.path.exists(port_file):
            time.sleep(1)
        srv.shutdown()
    threading.Thread(target=watch, daemon=True).start()


def main():
    port_file = sys.argv[1]
    socketserver.TCPServer.allow_reuse_address = True
    with socketserver.TCPServer(("127.0.0.1", 0), Handler) as srv:
        with open(port_file, "w") as fh:
            fh.write(str(srv.server_address[1]))
        expire_with_port_file(srv, port_file)
        srv.serve_forever()


if __name__ == "__main__":
    main()
