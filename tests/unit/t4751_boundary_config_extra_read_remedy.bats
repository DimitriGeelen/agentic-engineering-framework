#!/usr/bin/env bats
# T-4751 (010-termlink be.17): the project-boundary block message tells the agent to run
# `fw config set BOUNDARY_EXTRA_READ_PATHS /path/one:/path/two`, and the same hook refused
# that command because its value names outside paths. The value of that one key, in that
# one segment, is now exempt (logged Tier-2); everything else is judged as before.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    HOOK="$FRAMEWORK_ROOT/agents/context/check-project-boundary.sh"
    [ -x "$HOOK" ]
    # A throwaway project root, so the Tier-2 log lands in the temp dir.
    PROJ="$TEST_TEMP_DIR/proj"
    mkdir -p "$PROJ/.context/working"
    export PROJECT_ROOT="$PROJ"
    LOG="$PROJ/.context/working/.gate-bypass-log.yaml"
    unset FW_BOUNDARY_EXTRA_READ_PATHS TERMLINK_RUNTIME_DIR
}

teardown() {
    rm -rf "$TEST_TEMP_DIR"
}

run_bash() {
    local payload
    payload=$(python3 -c "
import json, sys
print(json.dumps({'tool_name': 'Bash', 'tool_input': {'command': sys.argv[1]}, 'cwd': sys.argv[2]}))
" "$1" "${2:-$PROJ}")
    echo "$payload" | bash "$HOOK"
}

# ── allowed forms ────────────────────────────────────────────────────────────

@test "bin/fw config set BOUNDARY_EXTRA_READ_PATHS with outside paths is allowed and logged" {
    run run_bash 'bin/fw config set BOUNDARY_EXTRA_READ_PATHS /srv/tool:/opt/other/bin'
    [ "$status" -eq 0 ]
    grep -q "config-set-BOUNDARY_EXTRA_READ_PATHS" "$LOG"
    grep -q "value: '/srv/tool:/opt/other/bin'" "$LOG"
}

@test ".agentic-framework/bin/fw form is allowed" {
    run run_bash '.agentic-framework/bin/fw config set BOUNDARY_EXTRA_READ_PATHS /srv/tool'
    [ "$status" -eq 0 ]
}

@test "cd PROJECT && fw config set form is allowed" {
    run run_bash "cd $PROJ && .agentic-framework/bin/fw config set BOUNDARY_EXTRA_READ_PATHS /opt/other/bin" /tmp
    [ "$status" -eq 0 ]
}

@test "absolute project fw path is allowed from any cwd" {
    run run_bash "$PROJ/bin/fw config set BOUNDARY_EXTRA_READ_PATHS /srv/tool" /tmp
    [ "$status" -eq 0 ]
}

@test "fw config get BOUNDARY_EXTRA_READ_PATHS is allowed and not logged" {
    run run_bash 'bin/fw config get BOUNDARY_EXTRA_READ_PATHS'
    [ "$status" -eq 0 ]
    [ ! -s "$LOG" ]
}

# ── the exemption is narrow ──────────────────────────────────────────────────

@test "another config key with an outside path is still refused" {
    run run_bash 'bin/fw config set PORT /opt/other/secret'
    [ "$status" -eq 2 ]
    [ ! -s "$LOG" ]
}

@test "a chained read of an outside path is still refused" {
    run run_bash 'bin/fw config set BOUNDARY_EXTRA_READ_PATHS /srv/tool && cat /opt/other/.env'
    [ "$status" -eq 2 ]
}

@test "reading the declared path itself is still refused" {
    run run_bash 'cat /srv/tool/secret'
    [ "$status" -eq 2 ]
}

@test "relative fw after cd elsewhere gets no exemption" {
    run run_bash 'cd /tmp && bin/fw config set BOUNDARY_EXTRA_READ_PATHS /opt/other/x'
    [ "$status" -eq 2 ]
}

@test "relative fw from a session cwd outside the project gets no exemption" {
    run run_bash 'bin/fw config set BOUNDARY_EXTRA_READ_PATHS /opt/other/x' /tmp
    [ "$status" -eq 2 ]
}

@test "extra words, quoting or substitution in the segment get no exemption" {
    run run_bash 'bin/fw config set BOUNDARY_EXTRA_READ_PATHS /opt/other/x /opt/other/y'
    [ "$status" -eq 2 ]
    run run_bash 'bin/fw config set BOUNDARY_EXTRA_READ_PATHS "/opt/other/x"'
    [ "$status" -eq 2 ]
    run run_bash 'bin/fw config set BOUNDARY_EXTRA_READ_PATHS $(cat /opt/other/x)'
    [ "$status" -eq 2 ]
}

@test "a non-fw verb with the same words gets no exemption" {
    run run_bash 'cat config set BOUNDARY_EXTRA_READ_PATHS /opt/other/x'
    [ "$status" -eq 2 ]
}

# ── the block message's remedy round-trips through the hook ─────────────────

@test "the printed remedy line passes the hook verbatim" {
    run run_bash 'cat /srv/tool/secret'
    [ "$status" -eq 2 ]
    remedy=$(printf '%s\n' "$output" | grep 'config set BOUNDARY_EXTRA_READ_PATHS' | sed 's/^ *//')
    [ -n "$remedy" ]
    remedy="${remedy//\/path\/one/\/srv\/tool}"
    remedy="${remedy//\/path\/two/\/opt\/other\/bin}"
    run run_bash "$remedy" /tmp
    [ "$status" -eq 0 ]
    grep -q "value: '/srv/tool:/opt/other/bin'" "$LOG"
}

@test "in the framework repo the remedy uses bin/fw and still passes" {
    export PROJECT_ROOT="$FRAMEWORK_ROOT"
    run run_bash 'cat /srv/tool/secret' "$FRAMEWORK_ROOT"
    [ "$status" -eq 2 ]
    remedy=$(printf '%s\n' "$output" | grep 'config set BOUNDARY_EXTRA_READ_PATHS' | sed 's/^ *//')
    [[ "$remedy" == "cd $FRAMEWORK_ROOT && bin/fw config set"* ]]
}
