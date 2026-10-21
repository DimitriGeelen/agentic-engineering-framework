#!/usr/bin/env bats
# T-4230 — handover.sh's _resolve_commit_task must not label the handover
# commit with whichever task happens to have "handover" in its slug. 1023 got
# T-122/T-116 while focus was T-126; AEF got a different handover bug-report
# task on every handover. Only the dedicated "Session handover maintenance"
# task (the slug the auto-create branch produces) may be reused.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    export NO_COLOR=1
    # Run the real function, extracted from the source, not a re-implementation.
    sed -n '/^_resolve_commit_task() {/,/^}/p' "$FRAMEWORK_ROOT/agents/handover/handover.sh" \
        > "$TEST_TEMP_DIR/fn.sh"
    [ -s "$TEST_TEMP_DIR/fn.sh" ]
    mkdir -p "$TEST_TEMP_DIR/proj/.tasks/active" "$TEST_TEMP_DIR/proj/.tasks/completed"
    # Decoys: real tasks whose titles merely mention handover.
    touch "$TEST_TEMP_DIR/proj/.tasks/active/T-122-fix-handover-push-timeout.md"
    touch "$TEST_TEMP_DIR/proj/.tasks/completed/T-116-handover-digest-section.md"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# FRAMEWORK_ROOT points at an empty dir so the auto-create branch is skipped
# and the function falls through to the T-000 placeholder.
_resolve() {
    bash -c '
        source "$1"
        TASKS_DIR="$2/.tasks"; FRAMEWORK_ROOT="$2/nofw"; PROJECT_ROOT="$2"
        COMMIT_TASK="${3:-}"
        _resolve_commit_task
        echo "$COMMIT_TASK"
    ' _ "$TEST_TEMP_DIR/fn.sh" "$TEST_TEMP_DIR/proj" "${1:-}"
}

@test "decoy tasks with 'handover' in the slug are never chosen (T-4230)" {
    run _resolve
    [ "$status" -eq 0 ]
    [ "$output" = "T-000" ]
}

@test "the dedicated session-handover-maintenance task in active/ is reused (T-4230)" {
    touch "$TEST_TEMP_DIR/proj/.tasks/active/T-200-session-handover-maintenance.md"
    run _resolve
    [ "$output" = "T-200" ]
}

@test "a closed session-handover-maintenance task is not reused (T-1477 rule, T-4230)" {
    touch "$TEST_TEMP_DIR/proj/.tasks/completed/T-201-session-handover-maintenance.md"
    run _resolve
    [ "$output" = "T-000" ]
}

@test "--task override still wins (T-4230)" {
    run _resolve T-555
    [ "$output" = "T-555" ]
}
