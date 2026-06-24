#!/usr/bin/env bats
# T-2490 / OBS-089: the `fw doctor` litellm reachability check curled `/health`,
# which litellm serves as an AUTH-REQUIRED endpoint (HTTP 401). `curl -sf` (the
# -f flag) treats 4xx as failure, so the check emitted a false "litellm-proxy not
# reachable" WARN even when the proxy was fully up. The fix uses the
# unauthenticated liveness probe `/health/liveliness` (HTTP 200).
#
# Two guards: (1) structural — bin/fw's litellm check targets /health/liveliness,
# not bare /health; (2) functional — against a stub that mirrors litellm's auth
# behaviour, `curl -sf .../health/liveliness` succeeds where `curl -sf .../health`
# fails, proving the endpoint choice IS the bug.

load ../test_helper

@test "t2490: bin/fw litellm doctor check targets /health/liveliness (not bare /health)" {
    local fw="$FRAMEWORK_ROOT/bin/fw"
    # the litellm liveness curl must be present
    run grep -F 'health/liveliness' "$fw"
    [ "$status" -eq 0 ]
    # the buggy bare-/health curl against the litellm port must be gone
    run grep -E 'curl -sf --max-time 2 "?http://localhost:[^/]*/health"? ' "$fw"
    [ "$status" -ne 0 ]
}

@test "t2490: stub mirrors litellm auth — /health=401, /health/liveliness=200; -sf distinguishes" {
    # Pick a port unlikely to collide; start a tiny stub HTTP server that mirrors
    # litellm's auth behaviour (/health -> 401, /health/liveliness -> 200).
    local port=4731
    python3 -c '
import sys, http.server
port = int(sys.argv[1])
class H(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/health/liveliness":
            self.send_response(200); self.end_headers(); self.wfile.write(b"OK")
        elif self.path == "/health":
            self.send_response(401); self.end_headers(); self.wfile.write(b"auth required")
        else:
            self.send_response(404); self.end_headers()
    def log_message(self, *a): pass
http.server.HTTPServer(("127.0.0.1", port), H).serve_forever()
' "$port" &
    local pid=$!
    # wait for listen
    for _ in $(seq 1 20); do
        curl -s --max-time 1 "http://127.0.0.1:$port/health/liveliness" >/dev/null 2>&1 && break
        sleep 0.2
    done

    # the corrected endpoint succeeds under -sf
    run curl -sf --max-time 2 "http://127.0.0.1:$port/health/liveliness"
    local live_status=$status
    # the old endpoint (401) fails under -sf — this is the false-negative the WARN hit
    run curl -sf --max-time 2 "http://127.0.0.1:$port/health"
    local health_status=$status

    kill "$pid" 2>/dev/null || true

    [ "$live_status" -eq 0 ]      # /health/liveliness -> reachable
    [ "$health_status" -ne 0 ]    # /health -> -sf fails (the bug)
}

@test "t2490: systemd unit ships with Restart and the liveliness probe" {
    local unit="$FRAMEWORK_ROOT/deploy/litellm-proxy.service"
    [ -f "$unit" ]
    grep -q '^Restart=on-failure' "$unit"
    grep -q 'health/liveliness' "$unit"
    grep -q 'litellm-config.yaml' "$unit"
}
