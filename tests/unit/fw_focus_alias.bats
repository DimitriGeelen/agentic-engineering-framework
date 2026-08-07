#!/usr/bin/env bats
# T-2860 — `fw focus` is the obvious shortening of the documented
# `fw context focus T-XXX` verb (CLAUDE.md, handover template, session-start
# protocol all say "Set focus: fw context focus T-XXX"). The unaliased command
# used to fail with "Unknown command: focus" and no pointer to the real verb.
#
# This pins that `fw focus` produces byte-identical output and focus.yaml state
# to `fw context focus`, that it routes through context.sh rather than
# duplicating logic, and that a bare `fw focus` never reports false success.

load ../test_helper

FW="$FRAMEWORK_ROOT/bin/fw"

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    PROJECT_ROOT="$TEST_TEMP_DIR/project"
    guard_project_root "$PROJECT_ROOT"
    mkdir -p "$PROJECT_ROOT/.tasks/active" "$PROJECT_ROOT/.context/working"
    echo "framework_root: $FRAMEWORK_ROOT" > "$PROJECT_ROOT/.framework.yaml"
    create_test_task "$PROJECT_ROOT" "T-042" "fix-login"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

run_fw() {   # run_fw <args...>
    run env PROJECT_ROOT="$PROJECT_ROOT" FRAMEWORK_ROOT="$FRAMEWORK_ROOT" "$FW" "$@"
}

# ── identical behaviour to `context focus` ─────────────────────────────────

@test "fw focus T-XXX sets the same focus.yaml as fw context focus T-XXX" {
    run_fw context focus T-042
    [ "$status" -eq 0 ]
    cp "$PROJECT_ROOT/.context/working/focus.yaml" "$TEST_TEMP_DIR/via-context.yaml"
    rm -f "$PROJECT_ROOT/.context/working/focus.yaml"

    run_fw focus T-042
    [ "$status" -eq 0 ]
    diff "$TEST_TEMP_DIR/via-context.yaml" "$PROJECT_ROOT/.context/working/focus.yaml"
}

@test "fw focus T-XXX prints the same confirmation as fw context focus T-XXX" {
    run_fw context focus T-042
    local context_output="$output"
    local context_status="$status"

    rm -f "$PROJECT_ROOT/.context/working/focus.yaml"

    run_fw focus T-042
    [ "$status" -eq "$context_status" ]
    [ "$output" = "$context_output" ]
}

@test "fw focus rejects a nonexistent task exactly like fw context focus" {
    run_fw focus T-999
    [ "$status" -eq 1 ]
    [[ "$output" == *"Task not found: T-999"* ]]
}

# ── no false success on bare `fw focus` ─────────────────────────────────────

@test "fw focus with no argument reports current focus, not a false success" {
    run_fw focus T-042
    [ "$status" -eq 0 ]

    run_fw focus
    [ "$status" -eq 0 ]
    [[ "$output" == *"Current focus: T-042"* ]]
}

@test "fw focus with no argument and no prior focus reports unset, not silent success" {
    run_fw focus
    [ "$status" -eq 0 ]
    [[ "$output" == *"not initialized"* ]] || [[ "$output" == *"No current focus set"* ]]
}

# ── routes through context.sh instead of duplicating logic ─────────────────

@test "fw focus dispatch delegates to context.sh (does not duplicate focus logic)" {
    run grep -A6 '^    focus)' "$FW"
    [[ "$output" == *"context.sh"* ]]
    [[ "$output" == *"focus"* ]]
}

# ── discoverability ──────────────────────────────────────────────────────────

@test "fw help lists the focus verb" {
    run bash -c "'$FW' help 2>&1 | sed 's/\x1b\[[0-9;]*m//g'"
    [ "$status" -eq 0 ]
    echo "$output" | grep -qE '^[[:space:]]*focus[[:space:]]'
}

# ── negative control: proves the assertions above can actually fail ────────

@test "negative control: an unaliased lookalike command is NOT silently accepted" {
    # 'focuss' is not a registered verb -- if the dispatcher matched on prefix
    # or the assertions above were vacuously true, this would also succeed.
    run_fw focuss T-042
    [ "$status" -ne 0 ]
    [[ "$output" == *"Unknown command: focuss"* ]]
}
