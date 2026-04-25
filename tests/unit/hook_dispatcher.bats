#!/usr/bin/env bats
# T-1360 / G-053-B: Hook dispatcher degrades gracefully on missing script.
#
# The `fw hook <name>` dispatcher used to exit 2 when the hook script didn't
# exist. Exit 2 in PreToolUse HARD-BLOCKS the tool call, so configuration drift
# (missing script, typo, stuck CWD) cascaded across every Bash/Write/Edit,
# rendering the session unrecoverable via native tools.
#
# This test asserts the new behavior: exit 0 + stderr warning + crash log entry.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_PROJECT="$TEST_TEMP_DIR/proj"
    mkdir -p "$TEST_PROJECT/.context/working" "$TEST_PROJECT/.tasks/active"
    touch "$TEST_PROJECT/.framework.yaml"
    # T-1457: pin PROJECT_ROOT to TEST_PROJECT so the dispatcher's missing-hook
    # write lands in TEST_PROJECT/.context/working/.hook-crashes.log, not the
    # framework's. Without this, parent-shell PROJECT_ROOT leaks in via bats `run`
    # and pollutes the framework crash log (surfaced as phantom warnings in fw doctor).
    export PROJECT_ROOT="$TEST_PROJECT"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

@test "hook dispatcher: unknown hook exits 0 (not 2)" {
    cd "$TEST_PROJECT"
    run "$FRAMEWORK_ROOT/bin/fw" hook __definitely_not_a_real_hook_xyz__
    [ "$status" -eq 0 ]
}

@test "hook dispatcher: unknown hook prints stderr warning" {
    cd "$TEST_PROJECT"
    run "$FRAMEWORK_ROOT/bin/fw" hook __another_fake_hook_xyz__
    # stderr merges into $output in bats `run`
    echo "$output" | grep -qE "WARNING.*Hook script not found"
    echo "$output" | grep -q "degrading to allow"
}

@test "hook dispatcher: unknown hook appends to .hook-crashes.log" {
    cd "$TEST_PROJECT"
    "$FRAMEWORK_ROOT/bin/fw" hook __logged_miss_xyz__ 2>/dev/null
    [ -f "$TEST_PROJECT/.context/working/.hook-crashes.log" ]
    grep -q "missing-hook __logged_miss_xyz__" "$TEST_PROJECT/.context/working/.hook-crashes.log"
}

@test "hook dispatcher: known hook still runs (non-regression)" {
    # check-project-boundary is always present — if this breaks, the fix regressed
    cd "$TEST_PROJECT"
    run "$FRAMEWORK_ROOT/bin/fw" hook check-project-boundary
    [ "$status" -eq 0 ]
}

@test "hook dispatcher: hook usage with no arg still exits 1 (unchanged)" {
    cd "$TEST_PROJECT"
    run "$FRAMEWORK_ROOT/bin/fw" hook
    [ "$status" -eq 1 ]
    echo "$output" | grep -q "Usage: fw hook"
}
