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
# A FOREIGN server answering /health 200 but identifying as a different project
# via /api/_identity must NOT be resolved as ours. _watchtower_url is the contract
# both verdict call-sites now gate on; if it returns non-zero (no leaked URL), the
# false-positive cannot occur downstream.
@test "F9: _watchtower_url returns non-zero against a foreign /health-200 server" {
    command -v python3 >/dev/null || skip "python3 required for stub server"

    # Foreign stub: 200 on /health, and /api/_identity claims a DIFFERENT project.
    local stub="$TEST_TEMP_DIR/stub.py"
    cat > "$stub" <<'PY'
import sys, json
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

    # Launch and read back the chosen port.
    exec 3< <(python3 "$stub")
    STUB_PID=$!
    local port
    read -r port <&3
    [ -n "$port" ]

    # Sanity: the stub really is answering /health 200 (the trap the old code fell
    # into — a bare curl /health would go green here).
    run curl -sf "http://127.0.0.1:${port}/health"
    [ "$status" -eq 0 ]

    # Our project root is an empty temp dir (no triple files of ours); point the
    # configured port at the foreign stub. NB: we do NOT source paths.sh — it could
    # reset PROJECT_ROOT and let a live worktree Watchtower satisfy Layer 1.
    # watchtower.sh sources config.sh itself; FW_PORT feeds fw_config "PORT".
    mkdir -p "$TEST_TEMP_DIR/proj/.context/working"

    run env -u WATCHTOWER_URL PROJECT_ROOT="$TEST_TEMP_DIR/proj" FW_PORT="$port" \
        FRAMEWORK_ROOT="$FRAMEWORK_ROOT" bash -c '
            source "$FRAMEWORK_ROOT/lib/watchtower.sh"
            _watchtower_url
        '

    # The resolver must NOT have leaked the foreign URL: non-zero exit, and the
    # foreign port must not appear in any URL it printed to stdout.
    [ "$status" -ne 0 ]
    [[ "$output" != *":${port}"* ]]
}
