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


def main():
    port_file = sys.argv[1]
    socketserver.TCPServer.allow_reuse_address = True
    with socketserver.TCPServer(("127.0.0.1", 0), Handler) as srv:
        with open(port_file, "w") as fh:
            fh.write(str(srv.server_address[1]))
        srv.serve_forever()


if __name__ == "__main__":
    main()
