#!/usr/bin/env bats
# Unit tests for lib/watchtower.sh — _watchtower_url 3-layer discovery (T-1284, T-1291).
#
# Locks in the regression fix: the pre-T-1290 implementation matched any
# service that answered task-specific paths on a probed port, which picked
# Open WebUI on :8080 during the T-1284 incident. These tests spin up a
# tiny Python HTTP server to play the masquerade role and assert that
# _watchtower_url never returns a URL it cannot positively identify.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    mkdir -p "$TEST_TEMP_DIR/.context/working"

    # Pick a random high port to avoid collisions with a real Watchtower.
    # 35000–39999 range — unlikely to be in use.
    MASQ_PORT=$((RANDOM % 5000 + 35000))
    export MASQ_PORT
    MASQ_PID=""

    # Clean watchtower env for deterministic tests
    unset WATCHTOWER_URL
    unset _FW_WATCHTOWER_LOADED _FW_CONFIG_LOADED _FW_PATHS_LOADED

    # Make fw_config return our masquerader port as the "configured port"
    # so Layer 2 probes it by default.
    export FW_PORT="$MASQ_PORT"
}

teardown() {
    if [ -n "${MASQ_PID:-}" ] && kill -0 "$MASQ_PID" 2>/dev/null; then
        kill "$MASQ_PID" 2>/dev/null || true
        sleep 0.3
        kill -9 "$MASQ_PID" 2>/dev/null || true
    fi
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# Start a tiny python HTTP server that answers 200 with a JSON identity
# claiming project_root=$1 (a path that is NOT our PROJECT_ROOT).
_start_masquerader() {
    local fake_root="${1:-/opt/some-other-project}"
    python3 - "$MASQ_PORT" "$fake_root" >/dev/null 2>&1 &
    MASQ_PID=$!
    # Wait up to 3s for listener to come up
    local i=0
    while [ $i -lt 30 ]; do
        if curl -sf --max-time 1 "http://127.0.0.1:$MASQ_PORT/" >/dev/null 2>&1; then
            return 0
        fi
        sleep 0.1
        i=$((i + 1))
    done
    return 1
}

# heredoc attached to _start_masquerader via stdin replacement — bats doesn't
# allow it cleanly, so inline the server script via a temp file instead.
_write_masq_server() {
    cat > "$TEST_TEMP_DIR/masq.py" <<'PYEOF'
import sys, json, http.server, socketserver
port = int(sys.argv[1])
fake_root = sys.argv[2]
class H(http.server.BaseHTTPRequestHandler):
    def log_message(self, *a, **kw): pass
    def do_GET(self):
        if self.path == "/api/_identity":
            body = json.dumps({
                "service": "watchtower",  # even the right service name
                "project_root": fake_root,  # but wrong project
                "version": "fake",
                "started_at": "1970-01-01T00:00:00Z",
            }).encode()
        else:
            body = b"<html>open webui masquerade</html>"
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)
socketserver.TCPServer.allow_reuse_address = True
with socketserver.TCPServer(("127.0.0.1", port), H) as s:
    s.serve_forever()
PYEOF
}

@test "WATCHTOWER_URL env override returns verbatim (fast path)" {
    export WATCHTOWER_URL="http://example.invalid:9999"
    source "$FRAMEWORK_ROOT/lib/watchtower.sh"
    run _watchtower_url
    [ "$status" -eq 0 ]
    [ "$output" = "http://example.invalid:9999" ]
}

@test "No Watchtower anywhere — exits non-zero with stderr message" {
    source "$FRAMEWORK_ROOT/lib/watchtower.sh"
    run _watchtower_url
    [ "$status" -ne 0 ]
    [[ "$output" == *"No Watchtower reachable"* ]]
}

@test "Masquerader (wrong project_root) on configured port — fails loud, no url returned" {
    _write_masq_server
    python3 "$TEST_TEMP_DIR/masq.py" "$MASQ_PORT" "/opt/some-other-project" >/dev/null 2>&1 &
    MASQ_PID=$!
    # Wait for listener
    local i=0
    while [ $i -lt 30 ]; do
        curl -sf --max-time 1 "http://127.0.0.1:$MASQ_PORT/" >/dev/null 2>&1 && break
        sleep 0.1; i=$((i + 1))
    done
    source "$FRAMEWORK_ROOT/lib/watchtower.sh"
    run _watchtower_url
    [ "$status" -ne 0 ]
    [[ "$output" == *"No Watchtower reachable"* ]]
    # Must NOT return the masquerader's URL
    [[ "$output" != *":$MASQ_PORT"* ]] || fail "returned masquerader url: $output"
}

@test "Stale triple (dead pid) + masquerader on same port — still fails loud" {
    _write_masq_server
    python3 "$TEST_TEMP_DIR/masq.py" "$MASQ_PORT" "/opt/some-other-project" >/dev/null 2>&1 &
    MASQ_PID=$!
    local i=0
    while [ $i -lt 30 ]; do
        curl -sf --max-time 1 "http://127.0.0.1:$MASQ_PORT/" >/dev/null 2>&1 && break
        sleep 0.1; i=$((i + 1))
    done
    # Write a stale triple (dead PID, matching port)
    echo "999999999" > "$PROJECT_ROOT/.context/working/watchtower.pid"
    echo "$MASQ_PORT"  > "$PROJECT_ROOT/.context/working/watchtower.port"
    echo "http://127.0.0.1:$MASQ_PORT" > "$PROJECT_ROOT/.context/working/watchtower.url"

    source "$FRAMEWORK_ROOT/lib/watchtower.sh"
    run _watchtower_url
    [ "$status" -ne 0 ]
    [[ "$output" != *":$MASQ_PORT"* ]] || fail "returned masquerader url via stale triple: $output"
}

@test "Valid triple + real identity match — returns triple url" {
    _write_masq_server
    # Make the "masquerader" claim our project_root this time — it becomes
    # a legitimate Watchtower responder for this test.
    python3 "$TEST_TEMP_DIR/masq.py" "$MASQ_PORT" "$PROJECT_ROOT" >/dev/null 2>&1 &
    MASQ_PID=$!
    local i=0
    while [ $i -lt 30 ]; do
        curl -sf --max-time 1 "http://127.0.0.1:$MASQ_PORT/" >/dev/null 2>&1 && break
        sleep 0.1; i=$((i + 1))
    done

    # Write triple pointing at our test server; use $$ (this shell's pid) as
    # the "alive" pid so kill -0 succeeds.
    echo "$$" > "$PROJECT_ROOT/.context/working/watchtower.pid"
    echo "$MASQ_PORT" > "$PROJECT_ROOT/.context/working/watchtower.port"
    echo "http://127.0.0.1:$MASQ_PORT" > "$PROJECT_ROOT/.context/working/watchtower.url"

    source "$FRAMEWORK_ROOT/lib/watchtower.sh"
    run _watchtower_url
    [ "$status" -eq 0 ]
    [ "$output" = "http://127.0.0.1:$MASQ_PORT" ]
}
