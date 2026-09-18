#!/usr/bin/env python3
"""A Watchtower stand-in whose `/` is SLOW but whose `/api/_identity` is fast
(T-3382 fixture, OBS-437).

Binds an ephemeral port, writes the port number to argv[1], and answers
/api/_identity with `project_root` = argv[2] in about a millisecond. Every
other path sleeps for argv[3] seconds (default 3) before answering 200 — longer
than the 2-second budget the old liveness probe gave the root page. That is the
measured shape of the real server on 2026-09-17 (4.47s and 2.37s on `/`,
~1ms on the identity endpoint), reproduced so the false negative can be shown
red before the fix is shown green.

Sibling of foreign_watchtower.py; kept as a file for the same reason (L-408).
"""
import http.server
import json
import socketserver
import sys
import time


def main():
    port_file = sys.argv[1]
    project_root = sys.argv[2]
    slow_seconds = float(sys.argv[3]) if len(sys.argv) > 3 else 3.0

    class Handler(http.server.BaseHTTPRequestHandler):
        def do_GET(self):  # noqa: N802 (stdlib naming)
            if self.path.startswith("/api/_identity"):
                body = json.dumps(
                    {
                        "service": "watchtower",
                        "project_root": project_root,
                        "version": "slow-fixture",
                    }
                ).encode()
                ctype = "application/json"
            else:
                time.sleep(slow_seconds)
                body = b"<html>slow root page</html>"
                ctype = "text/html"
            self.send_response(200)
            self.send_header("Content-Type", ctype)
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def log_message(self, *args):
            pass

    socketserver.TCPServer.allow_reuse_address = True
    with socketserver.ThreadingTCPServer(("127.0.0.1", 0), Handler) as srv:
        with open(port_file, "w") as fh:
            fh.write(str(srv.server_address[1]))
        srv.serve_forever()


if __name__ == "__main__":
    main()
