#!/usr/bin/env bats
# Unit tests for lib/inception.sh
#
# Tests do_inception routing, show_inception_help, argument validation

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export FRAMEWORK_ROOT
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    export AGENTS_DIR="$FRAMEWORK_ROOT/agents"
    export FW_LIB_DIR="$FRAMEWORK_ROOT/lib"
    export NO_COLOR=1
    # T-1259: tests must be deterministic w.r.t. parent shell's CLAUDECODE.
    # Individual tests opt back in via `CLAUDECODE=1 run ...` when needed.
    unset CLAUDECODE
    source "$FRAMEWORK_ROOT/lib/colors.sh"
    source "$FRAMEWORK_ROOT/lib/errors.sh"
    source "$FRAMEWORK_ROOT/lib/tasks.sh"
    source "$FRAMEWORK_ROOT/lib/inception.sh"

    # Create task directory structure
    mkdir -p "$TEST_TEMP_DIR/.tasks/active"
    mkdir -p "$TEST_TEMP_DIR/.tasks/completed"
    mkdir -p "$TEST_TEMP_DIR/.context/working"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

@test "inception: show_inception_help shows commands" {
    run show_inception_help
    [ "$status" -eq 0 ]
    [[ "$output" == *"fw inception"* ]]
    [[ "$output" == *"start"* ]]
    [[ "$output" == *"status"* ]]
    [[ "$output" == *"decide"* ]]
}

@test "inception: do_inception routes help" {
    run do_inception --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"fw inception"* ]]
}

@test "inception: do_inception routes empty to help" {
    run do_inception ""
    [ "$status" -eq 0 ]
    [[ "$output" == *"fw inception"* ]]
}

@test "inception: do_inception rejects unknown subcommand" {
    run do_inception bogus
    [ "$status" -eq 1 ]
    [[ "$output" == *"Unknown inception subcommand"* ]]
}

@test "inception: do_inception_start requires name" {
    run do_inception_start ""
    [ "$status" -eq 1 ]
}

@test "inception: do_inception_decide requires task_id and decision" {
    run do_inception_decide
    [ "$status" -eq 1 ]
}

@test "inception: do_inception_decide requires valid decision value" {
    run do_inception_decide T-999 invalid
    [ "$status" -eq 1 ]
    [[ "$output" == *"go, no-go, or defer"* ]]
}

@test "inception: do_inception_decide requires rationale" {
    run do_inception_decide T-999 go
    [ "$status" -eq 1 ]
    [[ "$output" == *"Rationale required"* ]]
}

@test "inception: do_inception_decide fails for missing task" {
    run do_inception_decide T-999 go --rationale "test"
    [ "$status" -eq 1 ]
    [[ "$output" == *"not found"* ]]
}

@test "inception: do_inception_decide fails for non-inception task" {
    # Create a build task (not inception)
    cat > "$TEST_TEMP_DIR/.tasks/active/T-999-test.md" <<EOF
---
id: T-999
name: "Test task"
workflow_type: build
status: started-work
---
# T-999: Test task
## Decision
EOF
    run do_inception_decide T-999 go --rationale "test"
    [ "$status" -eq 1 ]
    [[ "$output" == *"not an inception task"* ]]
}

@test "inception: do_inception_status runs without error" {
    run do_inception_status
    [ "$status" -eq 0 ]
    # Should show "no inception tasks" or a list
    [[ "$output" == *"Inception"* ]] || [[ "$output" == *"inception"* ]]
}

@test "inception: do_inception_status finds inception task" {
    cat > "$TEST_TEMP_DIR/.tasks/active/T-888-test-inception.md" <<EOF
---
id: T-888
name: "Test inception"
workflow_type: inception
status: started-work
---
# T-888: Test inception
## Decision
EOF
    run do_inception_status
    [ "$status" -eq 0 ]
    [[ "$output" == *"T-888"* ]]
    [[ "$output" == *"Test inception"* ]]
}

# === T-1259: CLAUDECODE guard tests ===

@test "inception: CLAUDECODE=1 without --i-am-human is blocked (T-1259)" {
    CLAUDECODE=1 run do_inception_decide T-999 go --rationale "test"
    [ "$status" -ne 0 ]
    [[ "$output" == *"T-1259"* ]] || [[ "$output" == *"T-679"* ]]
    [[ "$output" == *"Watchtower"* ]] || [[ "$output" == *"task review"* ]]
}

@test "inception: CLAUDECODE=1 with --i-am-human bypasses guard (T-1259)" {
    # Guard passes; next failure should be "task not found" (different error path)
    CLAUDECODE=1 run do_inception_decide T-999 go --rationale "test" --i-am-human
    [ "$status" -ne 0 ]
    # Must NOT be the CLAUDECODE block message
    [[ "$output" != *"T-1259"* ]]
    # Must be the not-found path instead
    [[ "$output" == *"not found"* ]]
}

@test "inception: CLAUDECODE unset passes guard (T-1259)" {
    # Guard passes when env var not set; next failure is task-not-found
    unset CLAUDECODE
    run do_inception_decide T-999 go --rationale "test"
    [ "$status" -ne 0 ]
    [[ "$output" != *"T-1259"* ]]
    [[ "$output" == *"not found"* ]]
}
