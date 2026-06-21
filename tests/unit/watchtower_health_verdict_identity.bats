#!/usr/bin/env bats
# T-2445 (F9, T-2442 batch): Watchtower HEALTH-VERDICT call-sites must gate on
# the identity-verified resolver, never on a default-port `/health` curl.
#
# Regression origin: T-2441 onboarding dogfood. `fw doctor` and `fw audit`
# reported the Watchtower healthy when a FOREIGN service held the default port
# and the project's own dashboard never started. T-1803 had already hardened the
# resolver (`_watchtower_url` verifies /api/_identity and fails loud), but two
# consumers kept a pre-T-1803 fallback —
#   _watchtower_url 2>/dev/null || echo "http://localhost:<PORT>"
# — then curled /health (an endpoint ANY server answers 200). When the resolver
# correctly failed, the `|| echo` re-substituted the foreign port and the verdict
# went green. These tests fail with the old fallback and pass once both call-sites
# gate on resolver success.

load ../test_helper

setup() {
    unset PROJECT_ROOT  # L-456: avoid project-root leak from the parent shell
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    STUB_PID=""
}

teardown() {
    [ -n "${STUB_PID:-}" ] && kill "$STUB_PID" 2>/dev/null
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# ------------------------------------------------------------- contract: doctor
@test "F9: fw doctor smoke verdict has no default-port fallback and guards the curl" {
    # The pre-T-1803 fallback must be gone on the resolver line.
    local rc=0
    grep -nE '_doctor_wt_url=.*\|\| echo "http://localhost' "$FRAMEWORK_ROOT/bin/fw" || rc=$?
    [ "$rc" -ne 0 ]

    # The /health smoke curl must be guarded by a non-empty URL check (i.e. only
    # runs when the identity-verified resolver returned a URL).
    grep -qE '\[ -n "\$_doctor_wt_url" \][[:space:]]*&&[[:space:]]*curl' "$FRAMEWORK_ROOT/bin/fw"
}

# -------------------------------------------------------------- contract: audit
@test "F9: audit deploy-gate health has no default-port fallback and guards the curl" {
    local rc=0
    grep -nE '_wt_url=.*\|\| echo "http://localhost' "$FRAMEWORK_ROOT/agents/audit/audit.sh" || rc=$?
    [ "$rc" -ne 0 ]

    grep -qE '\[ -n "\$_wt_url" \][[:space:]]*&&[[:space:]]*curl' "$FRAMEWORK_ROOT/agents/audit/audit.sh"
}

# ------------------------------------------------------------------- e2e: chain
# A FOREIGN server answering /health 200 but identifying as a DIFFERENT project
# via /api/_identity must NOT pass the identity handshake. That handshake
# (_watchtower_identity_matches) is the single check both hardened call-sites'
# resolver depends on (T-1803); if a foreign /health-200 server fails it, the
# false-positive verdict cannot occur. Tested directly — no multi-layer probing,
# deterministic.
@test "F9: identity handshake rejects a foreign /health-200 server (no false match)" {
    command -v python3 >/dev/null || skip "python3 required for stub server"

    # Foreign stub: 200 on /health (the trap a bare curl fell for), and
    # /api/_identity claims a DIFFERENT project_root.
    local stub="$TEST_TEMP_DIR/stub.py"
    cat > "$stub" <<'PY'
import json
from http.server import BaseHTTPRequestHandler, HTTPServer
class H(BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def do_GET(self):
        if self.path == "/api/_identity":
            body = json.dumps({"service": "watchtower",
                               "project_root": "/some/OTHER/project"}).encode()
        else:  # /health and everything else answers 200 like any live server
            body = b'{"app":"ok"}'
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)
srv = HTTPServer(("127.0.0.1", 0), H)
print(srv.server_address[1], flush=True)
srv.serve_forever()
PY

    # Background the stub with stdout to a FILE (not a pipe inherited by the test
    # shell — that inheritance is what makes bats `run` hang). Poll for the port.
    python3 "$stub" > "$TEST_TEMP_DIR/port.txt" 2>/dev/null &
    STUB_PID=$!
    local port="" i
    for i in $(seq 1 25); do
        port="$(cat "$TEST_TEMP_DIR/port.txt" 2>/dev/null)"
        [ -n "$port" ] && break
        sleep 0.2
    done
    [ -n "$port" ]

    # Sanity: the stub really answers /health 200 — the exact trap the old
    # `curl .../health` verdict fell into.
    run curl -sf "http://127.0.0.1:${port}/health"
    [ "$status" -eq 0 ]

    # The identity handshake (PROJECT_ROOT = an unrelated temp dir) must REJECT the
    # foreign server: its /api/_identity reports a different project_root.
    run env -u WATCHTOWER_URL PROJECT_ROOT="$TEST_TEMP_DIR/proj" \
        FRAMEWORK_ROOT="$FRAMEWORK_ROOT" bash -c '
            source "$FRAMEWORK_ROOT/lib/watchtower.sh"
            _watchtower_identity_matches "http://127.0.0.1:'"$port"'"
        '
    [ "$status" -ne 0 ]
}
