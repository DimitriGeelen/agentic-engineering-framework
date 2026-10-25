#!/usr/bin/env bats
# T-4722: 055's termlink-hub.service runs with
# TERMLINK_RUNTIME_DIR=/root/.termlink/hub-persist — not the built-in
# /var/lib/termlink literal T-3779's resolver probed — so with the variable
# unset, claude-fw registered in /tmp/termlink-$UID, invisible to peers. The
# resolver now also asks the running hub (systemd unit Environment, then
# `termlink hub status` "Runtime dir:"). Stub systemctl/termlink on PATH;
# fake hubs as in t3779_termlink_runtime.bats.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    FWROOT="${BATS_TEST_DIRNAME}/../.."
    source "$FWROOT/lib/termlink-runtime.sh"
    unset TERMLINK_RUNTIME_DIR TERMLINK_SESSION_ID TERMLINK_RUNTIME_DIR_FALLBACK
    export FW_TERMLINK_DEFAULT_RUNTIME_DIR="$TEST_TEMP_DIR/default"
    export FW_TERMLINK_BUILTIN_RUNTIME_DIR="$TEST_TEMP_DIR/builtin"   # never a hub here
    PERSIST="$TEST_TEMP_DIR/hub-persist"
    mkdir -p "$TEST_TEMP_DIR/default/sessions" "$TEST_TEMP_DIR/builtin" "$PERSIST" "$TEST_TEMP_DIR/bin"
    export STUB_UNIT_DIR="" STUB_STATUS_DIR=""
    cat > "$TEST_TEMP_DIR/bin/systemctl" <<'EOF'
#!/bin/bash
[ "$1 $2" = "show termlink-hub" ] || exit 1
[ -n "$STUB_UNIT_DIR" ] && echo "TERMLINK_RUNTIME_DIR=$STUB_UNIT_DIR TERMLINK_SWEEP_INTERVAL_SECS=3600"
exit 0
EOF
    cat > "$TEST_TEMP_DIR/bin/termlink" <<'EOF'
#!/bin/bash
if [ "$1 $2" = "hub status" ]; then
    [ -n "$STUB_STATUS_DIR" ] || { echo "Hub: not running"; exit 1; }
    printf 'Hub: running (PID 1)\n  Runtime dir: %s\n  Socket: %s/hub.sock\n' "$STUB_STATUS_DIR" "$STUB_STATUS_DIR"
    exit 0
fi
echo "STUB-TERMLINK-ENV TLRD=${TERMLINK_RUNTIME_DIR:-<unset>}"
EOF
    chmod +x "$TEST_TEMP_DIR/bin/systemctl" "$TEST_TEMP_DIR/bin/termlink"
    export PATH="$TEST_TEMP_DIR/bin:$PATH"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

_hub() {   # _hub <dir> live|dead
    python3 -c "import socket,sys; s=socket.socket(socket.AF_UNIX); s.bind(sys.argv[1])" "$1/hub.sock"
    if [ "$2" = live ]; then echo $$ > "$1/hub.pid"; else echo 2147483646 > "$1/hub.pid"; fi
}

@test "t4722: THE FIELD CASE — unset, hub in a non-literal dir named by the systemd unit → supplied, source logged" {
    _hub "$PERSIST" live
    STUB_UNIT_DIR="$PERSIST" run fw_termlink_runtime_resolve
    [[ "$output" == "supplied $PERSIST "* ]]
    [[ "$output" == *"source: systemd-unit"* ]]
}

@test "t4722: unset, no unit env, hub status names the dir → supplied from hub-status" {
    _hub "$PERSIST" live
    STUB_STATUS_DIR="$PERSIST" run fw_termlink_runtime_resolve
    [[ "$output" == "supplied $PERSIST "* ]]
    [[ "$output" == *"source: hub-status"* ]]
}

@test "t4722: unit and hub status naming the same dir is one hub, not ambiguous" {
    _hub "$PERSIST" live
    STUB_UNIT_DIR="$PERSIST" STUB_STATUS_DIR="$PERSIST" run fw_termlink_runtime_resolve
    [[ "$output" == "supplied $PERSIST "* ]]
}

@test "t4722: a set TERMLINK_RUNTIME_DIR always wins over the discovered hub" {
    _hub "$PERSIST" live
    STUB_UNIT_DIR="$PERSIST" TERMLINK_RUNTIME_DIR=/somewhere/else run fw_termlink_runtime_resolve
    [[ "$output" == "set /somewhere/else "* ]]
}

@test "t4722: no hub running → none (behaviour unchanged, nothing exported)" {
    _hub "$PERSIST" dead
    STUB_UNIT_DIR="$PERSIST" STUB_STATUS_DIR="$PERSIST" run fw_termlink_runtime_resolve
    [ "$status" -eq 0 ]
    [[ "$output" == none* ]]
    [ -z "${TERMLINK_RUNTIME_DIR:-}" ]
}

@test "t4722: a live hub in the default dir still wins → default" {
    _hub "$TEST_TEMP_DIR/default" live
    _hub "$PERSIST" live
    STUB_UNIT_DIR="$PERSIST" run fw_termlink_runtime_resolve
    [[ "$output" == "default $TEST_TEMP_DIR/default "* ]]
}

@test "t4722: an explicit TERMLINK_RUNTIME_DIR_FALLBACK list is authoritative (no discovery)" {
    _hub "$PERSIST" live
    STUB_UNIT_DIR="$PERSIST" TERMLINK_RUNTIME_DIR_FALLBACK="$TEST_TEMP_DIR/builtin" run fw_termlink_runtime_resolve
    [[ "$output" == none* ]]
}

@test "t4722: fw termlink exports the discovered dir before calling termlink, and logs it" {
    _hub "$PERSIST" live
    STUB_UNIT_DIR="$PERSIST" run bash "$FWROOT/agents/termlink/termlink.sh" status
    [[ "$output" == *"STUB-TERMLINK-ENV TLRD=$PERSIST"* ]]
    [[ "$output" == *"using the hub's runtime dir $PERSIST (source: systemd-unit) (T-4722)"* ]]
}

@test "t4722: CONTROL — fw termlink with no hub leaves the variable unset" {
    run bash "$FWROOT/agents/termlink/termlink.sh" status
    [[ "$output" == *"STUB-TERMLINK-ENV TLRD=<unset>"* ]]
    ! [[ "$output" == *"(T-4722)"* ]] || false
}

@test "t4722: claude-fw names the resolution source in its warning" {
    grep -q 'registering on the canonical hub at $TERMLINK_RUNTIME_DIR (${_tlrt##\*; })' "$FWROOT/bin/claude-fw"
}
