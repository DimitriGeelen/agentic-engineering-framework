#!/usr/bin/env bats
# Unit tests for agents/task-create/update-task.sh
# Origin: T-928

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
UPDATE_TASK="$FRAMEWORK_ROOT/agents/task-create/update-task.sh"
CREATE_TASK="$FRAMEWORK_ROOT/agents/task-create/create-task.sh"

setup() {
    export BATS_TMPDIR="${BATS_TMPDIR:-/tmp}"
    export TEST_DIR="$BATS_TMPDIR/fw_update_task_test_$$"
    mkdir -p "$TEST_DIR/active" "$TEST_DIR/completed" "$TEST_DIR/templates"
    mkdir -p "$TEST_DIR/.context/episodic" "$TEST_DIR/.context/working"

    # Copy templates
    cp "$FRAMEWORK_ROOT/.tasks/templates/default.md" "$TEST_DIR/templates/" 2>/dev/null || true
    cp "$FRAMEWORK_ROOT/.tasks/templates/zzz-default.md" "$TEST_DIR/templates/default.md" 2>/dev/null || true

    export TASKS_DIR="$TEST_DIR"
    export PROJECT_ROOT="$FRAMEWORK_ROOT"
    export CONTEXT_DIR="$TEST_DIR/.context"

    # Create a test task
    "$CREATE_TASK" --name "Test task for update" --description "Testing update-task" --type build --owner agent --start 2>/dev/null

    # Get the created task ID
    TASK_FILE=$(ls "$TEST_DIR/active/T-"*.md 2>/dev/null | head -1)
    TASK_ID=$(grep '^id:' "$TASK_FILE" 2>/dev/null | sed 's/id: *//')
}

teardown() {
    rm -rf "$TEST_DIR" 2>/dev/null || true
}

# --- Help ---

@test "update-task --help shows usage" {
    run "$UPDATE_TASK" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage"* ]]
    [[ "$output" == *"--status"* ]]
    [[ "$output" == *"--owner"* ]]
}

@test "update-task -h shows usage" {
    run "$UPDATE_TASK" -h
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage"* ]]
}

# --- Argument validation ---

@test "update-task fails without task ID" {
    run "$UPDATE_TASK"
    [ "$status" -ne 0 ]
}

@test "update-task fails for nonexistent task" {
    run "$UPDATE_TASK" T-999999
    [ "$status" -ne 0 ]
}

# --- Status updates ---

@test "update-task changes status to issues" {
    run "$UPDATE_TASK" "$TASK_ID" --status issues --reason "Test issue"
    [ "$status" -eq 0 ]
    grep -q "status: issues" "$TASK_FILE"
}

@test "update-task changes owner" {
    run "$UPDATE_TASK" "$TASK_ID" --owner human
    [ "$status" -eq 0 ]
    grep -q "owner: human" "$TASK_FILE"
}

@test "update-task changes horizon" {
    # First set status to captured (not started-work) to test pure horizon change
    "$UPDATE_TASK" "$TASK_ID" --status captured 2>/dev/null
    run "$UPDATE_TASK" "$TASK_ID" --horizon later
    [ "$status" -eq 0 ]
    grep -q "horizon: later" "$TASK_FILE"
}

@test "update-task adds tag" {
    run "$UPDATE_TASK" "$TASK_ID" --add-tag "ui"
    [ "$status" -eq 0 ]
    grep -q "ui" "$TASK_FILE"
}

# --- Horizon-status invariants (T-1068) ---

@test "invariant: started-work auto-promotes horizon to now" {
    # Set horizon to later, status to captured
    "$UPDATE_TASK" "$TASK_ID" --status captured 2>/dev/null
    "$UPDATE_TASK" "$TASK_ID" --horizon later 2>/dev/null
    grep -q "horizon: later" "$TASK_FILE"
    # Now start work — horizon should auto-promote to now
    run "$UPDATE_TASK" "$TASK_ID" --status started-work
    [ "$status" -eq 0 ]
    grep -q "status: started-work" "$TASK_FILE"
    grep -q "horizon: now" "$TASK_FILE"
}

@test "invariant: horizon later auto-demotes started-work to captured" {
    # Task starts as started-work (from setup)
    grep -q "status: started-work" "$TASK_FILE"
    # Set horizon to later — status should auto-demote to captured
    run "$UPDATE_TASK" "$TASK_ID" --horizon later
    [ "$status" -eq 0 ]
    grep -q "horizon: later" "$TASK_FILE"
    grep -q "status: captured" "$TASK_FILE"
}

@test "invariant: horizon next auto-demotes started-work to captured" {
    grep -q "status: started-work" "$TASK_FILE"
    run "$UPDATE_TASK" "$TASK_ID" --horizon next
    [ "$status" -eq 0 ]
    grep -q "horizon: next" "$TASK_FILE"
    grep -q "status: captured" "$TASK_FILE"
}

@test "invariant: horizon later does not demote non-started-work status" {
    # Set to issues first
    "$UPDATE_TASK" "$TASK_ID" --status issues --reason "test" 2>/dev/null
    grep -q "status: issues" "$TASK_FILE"
    # Set horizon to later — status should NOT change (issues is not started-work)
    run "$UPDATE_TASK" "$TASK_ID" --horizon later
    [ "$status" -eq 0 ]
    grep -q "status: issues" "$TASK_FILE"
}

# --- T-1589: shipping-evidence preserves started-work on horizon demotion ---

@test "T-1589: started-work + shipping evidence preserved on horizon next" {
    # Task starts as started-work (from setup). Inject shipping evidence:
    # all Agent ACs checked + ## Recommendation block.
    # Replace the placeholder Agent block + add Recommendation
    cat >> "$TASK_FILE" <<'EVIDENCE'

## Recommendation

**Recommendation:** GO

**Rationale:** Test fixture for T-1589.
EVIDENCE
    # Mark Agent ACs as checked (no `- [ ]` under ### Agent)
    sed -i 's/^- \[ \]/- [x]/' "$TASK_FILE"

    grep -q "status: started-work" "$TASK_FILE"
    run "$UPDATE_TASK" "$TASK_ID" --horizon next
    [ "$status" -eq 0 ]
    grep -q "horizon: next" "$TASK_FILE"
    # Status preserved (NOT demoted to captured)
    grep -q "status: started-work" "$TASK_FILE"
    [[ "$output" == *"preserved at started-work"* ]]
    [[ "$output" == *"T-1589"* ]]
}

@test "T-1589: started-work + shipping evidence preserved on horizon later" {
    cat >> "$TASK_FILE" <<'EVIDENCE'

## Recommendation

**Recommendation:** GO

**Rationale:** Test fixture for T-1589.
EVIDENCE
    sed -i 's/^- \[ \]/- [x]/' "$TASK_FILE"

    run "$UPDATE_TASK" "$TASK_ID" --horizon later
    [ "$status" -eq 0 ]
    grep -q "horizon: later" "$TASK_FILE"
    grep -q "status: started-work" "$TASK_FILE"
}

@test "T-1589: started-work WITHOUT recommendation still demotes (no evidence)" {
    # Task starts as started-work. Mark Agent ACs as checked but DON'T add a
    # Recommendation block. Without the recommendation, no shipping evidence —
    # demote should still fire.
    sed -i 's/^- \[ \]/- [x]/' "$TASK_FILE"
    # Confirm no Recommendation marker exists
    if grep -q "^\*\*Recommendation:\*\*" "$TASK_FILE"; then false; fi

    run "$UPDATE_TASK" "$TASK_ID" --horizon next
    [ "$status" -eq 0 ]
    grep -q "horizon: next" "$TASK_FILE"
    grep -q "status: captured" "$TASK_FILE"
}

@test "T-1589: started-work WITH recommendation but unchecked Agent AC still demotes" {
    # Add Recommendation but leave a `- [ ]` checkbox under ### Agent — partial
    # work, not shipped. Demote should fire.
    cat >> "$TASK_FILE" <<'PARTIAL'

## Recommendation

**Recommendation:** GO

**Rationale:** Test fixture — partial.
PARTIAL
    # Leave Agent ACs unchecked (default state from create-task)

    run "$UPDATE_TASK" "$TASK_ID" --horizon next
    [ "$status" -eq 0 ]
    grep -q "horizon: next" "$TASK_FILE"
    grep -q "status: captured" "$TASK_FILE"
}

# --- Invalid values ---

@test "update-task rejects invalid status" {
    run "$UPDATE_TASK" "$TASK_ID" --status invalid_status
    [ "$status" -ne 0 ]
}

@test "update-task rejects invalid horizon" {
    run "$UPDATE_TASK" "$TASK_ID" --horizon invalid_horizon
    [ "$status" -ne 0 ]
}

# --- Last update ---

@test "update-task sets last_update timestamp" {
    local before
    before=$(grep '^last_update:' "$TASK_FILE" | head -1)
    sleep 1
    "$UPDATE_TASK" "$TASK_ID" --owner human 2>/dev/null
    local after
    after=$(grep '^last_update:' "$TASK_FILE" | head -1)
    [ "$before" != "$after" ]
}
