#!/usr/bin/env bats
# T-4297: Watchtower start must not change the host firewall without consent.
# Field finding (dimitri-mint-dev greenfield run 4, F-34): a 127.0.0.1 bind still ran
# `ufw allow <port>`, adding a rule open to Anywhere, with no prompt.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d -t t4297-XXXXXX)"
    STUB="$TEST_TEMP_DIR/bin"
    mkdir -p "$STUB"
    CALLS="$TEST_TEMP_DIR/ufw.calls"
    # A ufw stub: active, port not yet allowed; records every allow.
    cat > "$STUB/ufw" <<EOF
#!/bin/bash
case "\$1" in
    status) echo "Status: active" ;;
    allow) echo "\$*" >> "$CALLS" ;;
esac
exit 0
EOF
    chmod +x "$STUB/ufw"
}

teardown() { rm -rf "$TEST_TEMP_DIR"; }

_open() {
    # $1 = bind host, $2 = opt-in value ("" = unset)
    run env PATH="$STUB:$PATH" ${2:+FW_WATCHTOWER_OPEN_FIREWALL=$2} \
        bash -c "source '$FRAMEWORK_ROOT/lib/firewall.sh'; ensure_firewall_open 3011 'Agentic Framework' '$1'"
}

@test "T-4297: loopback bind never calls ufw allow" {
    for h in 127.0.0.1 localhost ::1; do
        _open "$h" 1
        [ "$status" -eq 0 ]
    done
    [ ! -s "$CALLS" ]
}

@test "T-4297: LAN bind without opt-in changes nothing and prints the exact command" {
    _open 0.0.0.0 ""
    [ "$status" -eq 0 ]
    [ ! -s "$CALLS" ]
    echo "$output" | grep -q "sudo ufw allow 3011/tcp"
    echo "$output" | grep -q "WATCHTOWER_OPEN_FIREWALL"
}

@test "T-4297: LAN bind with opt-in adds the rule" {
    _open 0.0.0.0 1
    [ "$status" -eq 0 ]
    grep -q "allow 3011/tcp" "$CALLS"
}

@test "T-4297: watchtower.sh passes the bind host to ensure_firewall_open" {
    grep -qE 'ensure_firewall_open "\$port" "Agentic Framework" "\$\{FW_HOST' "$FRAMEWORK_ROOT/bin/watchtower.sh"
}
