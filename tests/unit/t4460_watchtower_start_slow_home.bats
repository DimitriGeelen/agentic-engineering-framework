#!/usr/bin/env bats
# T-4460 — under load the home page (GET /) took 68 s, the start's 5 s health
# check on / timed out, and the start only warned: the server kept running with
# watchtower.pid and watchtower.port but no watchtower.url, so every URL reader
# (the reviewer judge among them) reported "no running Watchtower".
#
# The start now polls /api/_identity for WATCHTOWER_START_TIMEOUT seconds and,
# on expiry, stops the server it launched and clears the triple.
#
# A python3 shim on PATH replaces `python3 -m web.app` with a stub server whose
# /api/_identity answers at once and whose / sleeps; every other python3 call
# goes to the real interpreter. ufw is stubbed so start cannot touch the host
# firewall. Teardown kills only the pid this test's project names.

bats_require_minimum_version 1.5.0

ROOT() { cd "$BATS_TEST_DIRNAME/../.." && pwd; }

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    PROJ="$TEST_TEMP_DIR/proj"
    mkdir -p "$PROJ/.context/working" "$PROJ/.tasks/active" "$PROJ/.tasks/completed" "$TEST_TEMP_DIR/bin"
    printf 'project_name: t4460\nversion: 1.0\n' > "$PROJ/.framework.yaml"
    printf '#!/bin/sh\necho "Status: inactive"\n' > "$TEST_TEMP_DIR/bin/ufw"
    chmod +x "$TEST_TEMP_DIR/bin/ufw"

    local real_py
    real_py=$(command -v python3)
    cat > "$TEST_TEMP_DIR/stub_server.py" <<'PY'
import json, os, sys, time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

port = int(sys.argv[sys.argv.index("--port") + 1])
mode = os.environ.get("T4460_STUB_MODE", "ours")
slow = float(os.environ.get("T4460_HOME_DELAY", "30"))

class H(BaseHTTPRequestHandler):
    def log_message(self, *a):
        pass
    def do_GET(self):
        if self.path == "/api/_identity" and mode == "ours":
            body = json.dumps({"service": "watchtower",
                               "project_root": os.environ["PROJECT_ROOT"]}).encode()
        elif self.path == "/api/_identity":
            self.send_response(404); self.end_headers(); return
        else:
            time.sleep(slow)
            body = b"<html>home</html>"
        self.send_response(200)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

ThreadingHTTPServer(("0.0.0.0", port), H).serve_forever()
PY
    cat > "$TEST_TEMP_DIR/bin/python3" <<SH
#!/bin/bash
if [ "\${1:-}" = "-m" ] && [ "\${2:-}" = "web.app" ]; then
    shift 2
    exec "$real_py" "$TEST_TEMP_DIR/stub_server.py" "\$@"
fi
exec "$real_py" "\$@"
SH
    chmod +x "$TEST_TEMP_DIR/bin/python3"
    PORT=$("$real_py" -c 'import socket;s=socket.socket();s.bind(("127.0.0.1",0));print(s.getsockname()[1]);s.close()')
    W="$PROJ/.context/working"
}

teardown() {
    local p
    p=$(cat "$PROJ/.context/working/watchtower.pid" 2>/dev/null || true)
    [ -n "$p" ] && kill -KILL "$p" 2>/dev/null || true
    # Only stubs launched from this test's own mktemp dir.
    for p in $(pgrep -f "$TEST_TEMP_DIR/stub_server.py" 2>/dev/null); do
        kill -KILL "$p" 2>/dev/null || true
    done
    rm -rf "${TEST_TEMP_DIR:?}"
}

_start() {
    env PATH="$TEST_TEMP_DIR/bin:$PATH" PROJECT_ROOT="$PROJ" FRAMEWORK_ROOT="$(ROOT)" \
        FW_HOST=0.0.0.0 NO_COLOR=1 "$@" \
        "$(ROOT)/bin/watchtower.sh" start --port "$PORT"
}

@test "slow home page, fast identity: start succeeds within 20 s and writes the url" {
    # / takes 60 s; readiness must not wait on it.
    run timeout 20 bash -c "$(declare -f ROOT _start); TEST_TEMP_DIR='$TEST_TEMP_DIR' PROJ='$PROJ' PORT='$PORT' BATS_TEST_DIRNAME='$BATS_TEST_DIRNAME' _start T4460_HOME_DELAY=60"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Health check passed"* ]]
    [ -s "$W/watchtower.url" ]
    [ "$(tr -d '[:space:]' < "$W/watchtower.port")" = "$PORT" ]
    kill -0 "$(cat "$W/watchtower.pid")"
}

@test "never identifies: start stops its server, clears the triple, exits 1" {
    run _start T4460_STUB_MODE=silent FW_WATCHTOWER_START_TIMEOUT=3
    [ "$status" -eq 1 ]
    [[ "$output" == *"did not answer /api/_identity within 3s"* ]]
    [ ! -e "$W/watchtower.url" ]
    [ ! -e "$W/watchtower.port" ]
    [ ! -e "$W/watchtower.pid" ]
    sleep 1
    ! pgrep -f "$TEST_TEMP_DIR/stub_server.py" >/dev/null || false
}
