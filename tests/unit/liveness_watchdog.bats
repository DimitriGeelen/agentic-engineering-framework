#!/usr/bin/env bats
# T-100140: Watchtower watchdog in liveness-check.sh
#
# 2026-07-04 outage: the server hung for 3+ hours while liveness-check.sh
# logged `watchtower: stopped` every minute — detection without remediation.
# These tests pin the self-heal contract: pid-file present + N consecutive
# probe failures => one `watchtower.sh restart`, logged, counter reset.

load ../test_helper

setup() {
    export WD_TMP="$BATS_TMPDIR/t100140_wd_$$"
    mkdir -p "$WD_TMP/.context/working" "$WD_TMP/.context/monitors" "$WD_TMP/bin"
    # Probe target that always refuses connections (curl -sf fails fast)
    echo "http://127.0.0.1:1" > "$WD_TMP/.context/working/watchtower.url"
    # Stub restart handler that records each invocation
    cat > "$WD_TMP/bin/watchtower.sh" <<'EOF'
#!/bin/bash
echo "$@" >> "$(dirname "$0")/../.context/monitors/.restart-invocations"
echo "stub restarted"
EOF
    chmod +x "$WD_TMP/bin/watchtower.sh"
    SCRIPT="$FRAMEWORK_ROOT/agents/monitor/liveness-check.sh"
}

teardown() {
    rm -rf "$WD_TMP"
}

_run_check() {
    PROJECT_ROOT="$WD_TMP" WATCHTOWER_WATCHDOG_THRESHOLD=3 run bash "$SCRIPT"
}

@test "watchdog: restarts after threshold consecutive failures when pid file present" {
    touch "$WD_TMP/.context/working/watchtower.pid"
    _run_check; [ "$status" -eq 0 ]
    _run_check; [ "$status" -eq 0 ]
    [ ! -f "$WD_TMP/.context/monitors/.restart-invocations" ]
    [ "$(cat "$WD_TMP/.context/monitors/.watchtower-probe-failures")" = "2" ]
    _run_check; [ "$status" -eq 0 ]
    [ -f "$WD_TMP/.context/monitors/.restart-invocations" ]
    [ "$(wc -l < "$WD_TMP/.context/monitors/.restart-invocations")" -eq 1 ]
    grep -q "restart" "$WD_TMP/.context/monitors/.restart-invocations"
    # Counter reset after the restart attempt (spaces restarts >= threshold minutes)
    [ ! -f "$WD_TMP/.context/monitors/.watchtower-probe-failures" ]
    # Event logged to the liveness JSONL
    grep -q "watchtower-watchdog-restart" "$WD_TMP/.context/monitors/liveness.jsonl"
}

@test "watchdog: no restart without pid file (deliberate stop is respected)" {
    _run_check; _run_check; _run_check
    [ ! -f "$WD_TMP/.context/monitors/.restart-invocations" ]
}

@test "watchdog: WATCHTOWER_WATCHDOG=0 disables self-heal" {
    touch "$WD_TMP/.context/working/watchtower.pid"
    for _ in 1 2 3 4; do
        PROJECT_ROOT="$WD_TMP" WATCHTOWER_WATCHDOG=0 WATCHTOWER_WATCHDOG_THRESHOLD=3 run bash "$SCRIPT"
        [ "$status" -eq 0 ]
    done
    [ ! -f "$WD_TMP/.context/monitors/.restart-invocations" ]
}

@test "watchdog: successful probe resets the failure counter" {
    touch "$WD_TMP/.context/working/watchtower.pid"
    _run_check; _run_check
    [ "$(cat "$WD_TMP/.context/monitors/.watchtower-probe-failures")" = "2" ]
    # Point probe at something that answers: spin a one-shot HTTP responder
    python3 -u -c "
import http.server, socketserver, threading
srv = socketserver.TCPServer(('127.0.0.1', 0), http.server.SimpleHTTPRequestHandler)
print(srv.server_address[1], flush=True)
threading.Thread(target=srv.handle_request, daemon=True).start()
import time; time.sleep(15)
" > "$WD_TMP/.port" &
    # Wait until the responder has published its port
    for _ in $(seq 1 20); do
        port=$(head -1 "$WD_TMP/.port" 2>/dev/null)
        [ -n "$port" ] && break
        sleep 0.5
    done
    [ -n "$port" ]
    echo "http://127.0.0.1:$port" > "$WD_TMP/.context/working/watchtower.url"
    _run_check; [ "$status" -eq 0 ]
    [ ! -f "$WD_TMP/.context/monitors/.watchtower-probe-failures" ]
    [ ! -f "$WD_TMP/.context/monitors/.restart-invocations" ]
    wait
}
