#!/usr/bin/env bats
# T-4323: firewall rules Watchtower opened are removed on stop, and fw doctor
# flags framework-labelled rules for ports nothing listens on.
# Field finding (dimitri-mint-dev T-128): on .107, 65 of 78 'Agentic Framework' /
# 'Watchtower' / 'fw serve' ALLOW rules were for ports with no listener.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d -t t4323-XXXXXX)"
    STUB="$TEST_TEMP_DIR/bin"
    mkdir -p "$STUB"
    CALLS="$TEST_TEMP_DIR/ufw.calls"
    STATE="$TEST_TEMP_DIR/watchtower.firewall"
    # ufw stub: status prints $UFW_STATUS_FILE (default: active, nothing allowed);
    # allow/delete are recorded; delete fails when UFW_DELETE_FAIL=1.
    printf 'Status: active\n' > "$TEST_TEMP_DIR/status"
    cat > "$STUB/ufw" <<EOF
#!/bin/bash
case "\$1" in
    status) cat "\${UFW_STATUS_FILE:-$TEST_TEMP_DIR/status}" ;;
    allow) echo "\$*" >> "$CALLS" ;;
    delete) echo "\$*" >> "$CALLS"; [ "\${UFW_DELETE_FAIL:-0}" = 1 ] && exit 1 ;;
esac
exit 0
EOF
    # ss stub: a port listed in $TEST_TEMP_DIR/listening has a listener.
    cat > "$STUB/ss" <<EOF
#!/bin/bash
port="\${@: -1}"; port="\${port##*:}"
grep -qx "\$port" "$TEST_TEMP_DIR/listening" 2>/dev/null && echo "LISTEN 0 128 0.0.0.0:\$port 0.0.0.0:*"
exit 0
EOF
    chmod +x "$STUB/ufw" "$STUB/ss"
    : > "$TEST_TEMP_DIR/listening"
}

teardown() { rm -rf "$TEST_TEMP_DIR"; }

_lib() {
    run env PATH="$STUB:$PATH" "$@" bash -c "source '$FRAMEWORK_ROOT/lib/firewall.sh'; $FW_CALL"
}

@test "T-4323: an opted-in open records the port it added" {
    FW_CALL="ensure_firewall_open 3011 'Agentic Framework' 0.0.0.0 '$STATE'"
    _lib FW_WATCHTOWER_OPEN_FIREWALL=1
    [ "$status" -eq 0 ]
    grep -q "allow 3011/tcp" "$CALLS"
    [ "$(cat "$STATE")" = "3011" ]
}

@test "T-4323: nothing is recorded when the rule was not added by this call" {
    FW_CALL="ensure_firewall_open 3011 'Agentic Framework' 0.0.0.0 '$STATE'"
    _lib                                        # no opt-in
    [ ! -e "$STATE" ]
    FW_CALL="ensure_firewall_open 3011 'Agentic Framework' 127.0.0.1 '$STATE'"
    _lib FW_WATCHTOWER_OPEN_FIREWALL=1          # loopback
    [ ! -e "$STATE" ]
    printf 'Status: active\n3011/tcp                   ALLOW       Anywhere\n' > "$TEST_TEMP_DIR/status"
    FW_CALL="ensure_firewall_open 3011 'Agentic Framework' 0.0.0.0 '$STATE'"
    _lib FW_WATCHTOWER_OPEN_FIREWALL=1          # already allowed (not ours)
    [ ! -e "$STATE" ]
}

@test "T-4323: close removes only recorded rules and clears the record" {
    echo 3011 > "$STATE"
    FW_CALL="close_recorded_firewall_rules '$STATE'"
    _lib
    [ "$status" -eq 0 ]
    [ "$(cat "$CALLS")" = "delete allow 3011/tcp" ]
    [ ! -e "$STATE" ]
}

@test "T-4323: a failed delete keeps the record and prints the exact command" {
    echo 3011 > "$STATE"
    FW_CALL="close_recorded_firewall_rules '$STATE'"
    _lib UFW_DELETE_FAIL=1
    [ "$status" -eq 0 ]
    [ "$(cat "$STATE")" = "3011" ]
    echo "$output" | grep -q "sudo ufw delete allow 3011/tcp"
}

@test "T-4323: close with no record touches nothing" {
    FW_CALL="close_recorded_firewall_rules '$STATE'"
    _lib
    [ "$status" -eq 0 ]
    [ ! -s "$CALLS" ]
}

@test "T-4323: watchtower.sh stop (stale pid) removes the recorded rule" {
    local proj="$TEST_TEMP_DIR/proj"
    mkdir -p "$proj/.context/working"
    # A pid that is not running: start a short process and reap it.
    sleep 0 & local dead=$!; wait "$dead"
    echo "$dead" > "$proj/.context/working/watchtower.pid"
    echo 3011 > "$proj/.context/working/watchtower.firewall"
    run env PATH="$STUB:$PATH" PROJECT_ROOT="$proj" bash "$FRAMEWORK_ROOT/bin/watchtower.sh" stop
    [ "$status" -eq 0 ]
    grep -qx "delete allow 3011/tcp" "$CALLS"
    [ ! -e "$proj/.context/working/watchtower.firewall" ]
}

@test "T-4323: watchtower.sh start passes the state file to ensure_firewall_open" {
    grep -qE 'ensure_firewall_open "\$port" "Agentic Framework" "\$\{FW_HOST:-0\.0\.0\.0\}" "\$FIREWALL_STATE_FILE"' "$FRAMEWORK_ROOT/bin/watchtower.sh"
}

@test "T-4323: orphan scan lists labelled rules with no listener, once per port" {
    cat > "$TEST_TEMP_DIR/status" <<'EOF'
Status: active

To                         Action      From
--                         ------      ----
3000/tcp                   ALLOW       Anywhere                   # Agentic Framework
3001/tcp                   ALLOW       Anywhere                   # Watchtower
3002/tcp                   ALLOW       Anywhere                   # fw serve
5021/tcp                   ALLOW       Anywhere                   # Sprechloop development
8080/tcp                   ALLOW       Anywhere
3000/tcp (v6)              ALLOW       Anywhere (v6)              # Agentic Framework
EOF
    echo 3001 > "$TEST_TEMP_DIR/listening"
    FW_CALL="firewall_orphan_rules"
    _lib
    [ "$status" -eq 0 ]
    [ "$output" = "$(printf '3000\n3002')" ]
}

@test "T-4323: orphan scan is silent when ufw is inactive" {
    printf 'Status: inactive\n3000/tcp ALLOW Anywhere # Agentic Framework\n' > "$TEST_TEMP_DIR/status"
    FW_CALL="firewall_orphan_rules"
    _lib
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "T-4323: fw doctor WARNs on orphan rules with the delete command" {
    grep -q 'firewall_orphan_rules' "$FRAMEWORK_ROOT/bin/fw"
    grep -q 'sudo ufw delete allow ' "$FRAMEWORK_ROOT/bin/fw"
}
