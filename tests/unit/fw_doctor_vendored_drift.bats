#!/usr/bin/env bats
# T-1434: fw doctor must detect drift between framework source
# (lib/*.sh, agents/context/*.sh, agents/task-create/*.sh) and the
# vendored copies under .agentic-framework/. This prevents the class
# of bug that T-1432 and T-1433 hit: source edits that consumers miss
# because the vendored copy stayed stale.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    # We don't override PROJECT_ROOT/FRAMEWORK_ROOT here — we want doctor
    # to run in the real framework repo. Tests mutate-then-restore a single
    # vendored file to drive the drift check.
    SENTINEL="$FRAMEWORK_ROOT/.agentic-framework/lib/colors.sh"
    [ -f "$SENTINEL" ] || skip ".agentic-framework/lib/colors.sh missing"
    BACKUP="$TEST_TEMP_DIR/colors.sh.orig"
    cp "$SENTINEL" "$BACKUP"
}

teardown() {
    # Restore the sentinel no matter what.
    [ -f "$BACKUP" ] && cp "$BACKUP" "$SENTINEL"
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

@test "fw doctor: reports 'No vendored-source drift' when in sync" {
    # Baseline: vendored and source match (tests/setup restored any prior drift)
    run bash -c "cd '$FRAMEWORK_ROOT' && bin/fw doctor 2>&1"
    [ "$status" -eq 0 ] || [ "$status" -eq 1 ]  # warnings are allowed
    [[ "$output" == *"No vendored-source drift"* ]]
}

@test "fw doctor: reports 'Vendored-source drift' when a vendored file diverges" {
    # Introduce synthetic drift by appending a harmless comment.
    echo "# T-1434 drift sentinel — should be detected" >> "$SENTINEL"
    run bash -c "cd '$FRAMEWORK_ROOT' && bin/fw doctor 2>&1"
    [[ "$output" == *"Vendored-source drift"* ]]
    [[ "$output" == *"file(s) out of sync"* ]]
    [[ "$output" == *"lib/colors.sh"* ]]
}

@test "fw doctor: drift output names Run: fw vendor" {
    echo "# T-1434 drift sentinel" >> "$SENTINEL"
    run bash -c "cd '$FRAMEWORK_ROOT' && bin/fw doctor 2>&1"
    [[ "$output" == *"Run: fw vendor"* ]]
}
