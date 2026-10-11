#!/usr/bin/env bats
# T-4041 (GitHub #88) — with FW_HOST bound to one interface, the shell side must
# find Watchtower there, not on localhost, and must never print a link to a
# hard-coded localhost:3000 when the resolver fails.
#
# 127.0.0.2 is a second loopback address: a server bound to it does NOT answer on
# localhost (127.0.0.1), so any probe that still says "localhost" cannot reach it.
# That makes the test portable (no LAN interface needed) and makes it bite.

bats_require_minimum_version 1.5.0

ROOT() { echo "$BATS_TEST_DIRNAME/../.."; }
BOUND=127.0.0.2

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    PROJ="$TEST_TEMP_DIR/proj"
    mkdir -p "$PROJ/.context/working"
    printf 'project_name: t4041\nversion: 1.0\n' > "$PROJ/.framework.yaml"
    STUB_PID=""
    PORT=$(python3 -c 'import socket;s=socket.socket();s.bind(("127.0.0.2",0));print(s.getsockname()[1]);s.close()')
}

teardown() {
    [ -n "${STUB_PID:-}" ] && kill "$STUB_PID" 2>/dev/null
    PROJECT_ROOT="$PROJ" FRAMEWORK_ROOT="$(ROOT)" "$(ROOT)/bin/watchtower.sh" stop >/dev/null 2>&1 || true
    [ -n "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
    return 0
}

# Stub Watchtower bound to $BOUND only, answering /api/_identity as OUR project.
_start_stub() {
    cat > "$TEST_TEMP_DIR/stub.py" <<PY
import http.server, json, sys
root, port = sys.argv[1], int(sys.argv[2])
class H(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        body = json.dumps({"service": "watchtower", "project_root": root}).encode() \
            if self.path == "/api/_identity" else b"ok"
        self.send_response(200); self.send_header("Content-Length", str(len(body))); self.end_headers()
        self.wfile.write(body)
    def log_message(self, *a): pass
http.server.HTTPServer(("$BOUND", port), H).serve_forever()
PY
    python3 "$TEST_TEMP_DIR/stub.py" "$PROJ" "$PORT" </dev/null >/dev/null 2>&1 &
    STUB_PID=$!
    local i
    for i in 1 2 3 4 5 6 7 8 9 10; do
        curl -sf --max-time 1 "http://$BOUND:$PORT/" >/dev/null 2>&1 && return 0
        sleep 0.3
    done
    return 1
}

_resolve() {
    env -i PATH="$PATH" HOME="$TEST_TEMP_DIR" PROJECT_ROOT="$PROJ" FRAMEWORK_ROOT="$(ROOT)" "$@" \
        bash -c 'source "$FRAMEWORK_ROOT/lib/watchtower.sh"; _watchtower_url'
}

@test "FW_HOST is a registered config key defaulting to 0.0.0.0" {
    grep -q '"HOST|0.0.0.0|' "$(ROOT)/lib/config.sh"
}

@test "probe host is localhost when FW_HOST is unset, 0.0.0.0 or ::" {
    for v in "" 0.0.0.0 ::; do
        run env -i PATH="$PATH" HOME="$TEST_TEMP_DIR" PROJECT_ROOT="$PROJ" FRAMEWORK_ROOT="$(ROOT)" FW_HOST="$v" \
            bash -c 'source "$FRAMEWORK_ROOT/lib/watchtower.sh"; _watchtower_probe_host'
        [ "$status" -eq 0 ]
        [ "$output" = "localhost" ]
    done
}

@test "probe host is the FW_HOST address when specific" {
    run env -i PATH="$PATH" HOME="$TEST_TEMP_DIR" PROJECT_ROOT="$PROJ" FRAMEWORK_ROOT="$(ROOT)" FW_HOST=$BOUND \
        bash -c 'source "$FRAMEWORK_ROOT/lib/watchtower.sh"; _watchtower_probe_host'
    [ "$output" = "$BOUND" ]
}

@test "resolver finds a Watchtower bound to FW_HOST (localhost cannot reach it)" {
    _start_stub
    run ! curl -sf --max-time 2 "http://localhost:$PORT/"
    run _resolve FW_HOST=$BOUND FW_PORT=$PORT
    [ "$status" -eq 0 ]
    [ "$output" = "http://$BOUND:$PORT" ]
}

@test "resolver without FW_HOST does not find it and fails loud" {
    _start_stub
    run _resolve FW_PORT=$PORT
    [ "$status" -ne 0 ]
}

@test "start: health check passes, url file holds the FW_HOST address, server gets WATCHTOWER_URL" {
    run env PROJECT_ROOT="$PROJ" FRAMEWORK_ROOT="$(ROOT)" FW_HOST=$BOUND "$(ROOT)/bin/watchtower.sh" start --port "$PORT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Health check passed"* ]]
    [ "$(tr -d '[:space:]' < "$PROJ/.context/working/watchtower.port")" = "$PORT" ]
    [ "$(tr -d '[:space:]' < "$PROJ/.context/working/watchtower.url")" = "http://$BOUND:$PORT" ]
    pid=$(cat "$PROJ/.context/working/watchtower.pid")
    tr '\0' '\n' < /proc/$pid/environ | grep -qx "WATCHTOWER_URL=http://$BOUND:$PORT"
}

@test "no patched caller falls back to a hard-coded localhost:3000" {
    run grep -n 'localhost:3000' \
        "$(ROOT)/agents/context/check-tier0.sh" "$(ROOT)/lib/verify-acs.sh" "$(ROOT)/lib/arc.sh" \
        "$(ROOT)/agents/designer/designer.sh"
    [ "$status" -eq 1 ]
}

@test "designer url with the resolver failing prints no localhost:3000" {
    mkdir -p "$TEST_TEMP_DIR/fw/bin"
    printf '#!/bin/sh\nexit 1\n' > "$TEST_TEMP_DIR/fw/bin/fw"; chmod +x "$TEST_TEMP_DIR/fw/bin/fw"
    run --separate-stderr env FRAMEWORK_ROOT="$TEST_TEMP_DIR/fw" PROJECT_ROOT="$PROJ" \
        bash "$(ROOT)/agents/designer/designer.sh" url
    [ "$status" -ne 0 ]
    [[ "$output$stderr" != *"localhost:3000"* ]]
}

@test "tier0 block with the resolver failing prints no localhost:3000 link" {
    run grep -n 'WT_URL=' "$(ROOT)/agents/context/check-tier0.sh"
    [[ "$output" != *"localhost"* ]]
    [[ "$output" == *"|| true"* ]]
}

@test "watchtower help documents FW_HOST next to FW_PORT" {
    run "$(ROOT)/bin/watchtower.sh" help
    [[ "$output" == *"FW_PORT"* ]]
    [[ "$output" == *"FW_HOST"* ]]
}
