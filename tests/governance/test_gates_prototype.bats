#!/usr/bin/env bats
# T-1601 Spike 2: prototype red-team harness for governance gates.
#
# Pattern: invoke each PreToolUse hook directly with a constructed JSON envelope
# matching Claude Code's tool-call format, assert exit code 2 (block) and that
# stderr contains the expected error keyword.
#
# This is a PROTOTYPE — it covers 3 representative gates to prove the approach.
# A full harness (T-1601 build follow-up) would cover all 7 PreToolUse gates +
# git hooks + task lifecycle gates.

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
HOOK_BIN="$FRAMEWORK_ROOT/bin/fw"

# --- Gate 1: block-plan-mode ---
@test "plan-mode hook blocks EnterPlanMode tool" {
    INPUT='{"tool_name":"EnterPlanMode","tool_input":{}}'
    run bash -c "echo '$INPUT' | '$HOOK_BIN' hook block-plan-mode"
    [ "$status" -eq 2 ]
    [[ "$output" == *"EnterPlanMode"* ]] || [[ "$output" == *"plan mode"* ]] || [[ "$output" == *"plan-mode"* ]] || [[ "$output" == *"/plan"* ]]
}

# --- Gate 2: block-task-tools (G-022) ---
@test "task-tools hook blocks TodoWrite" {
    INPUT='{"tool_name":"TodoWrite","tool_input":{"todos":[]}}'
    run bash -c "echo '$INPUT' | '$HOOK_BIN' hook block-task-tools"
    [ "$status" -eq 2 ]
    [[ "$output" == *"TodoWrite"* ]] || [[ "$output" == *"task-tools"* ]] || [[ "$output" == *"fw work-on"* ]]
}

@test "task-tools hook blocks TaskCreate" {
    INPUT='{"tool_name":"TaskCreate","tool_input":{"description":"test"}}'
    run bash -c "echo '$INPUT' | '$HOOK_BIN' hook block-task-tools"
    [ "$status" -eq 2 ]
}

# --- Gate 3: check-active-task (no focus.yaml → block) ---
# This test runs in the FRAMEWORK repo itself, where focus.yaml already exists.
# Test pattern: temporarily clear focus, run hook, restore. Skip if cannot
# safely save+restore.
@test "active-task hook blocks Write to source when no active task" {
    FOCUS="$FRAMEWORK_ROOT/.context/working/focus.yaml"
    [ -f "$FOCUS" ] || skip "no focus.yaml — cannot test isolation safely"
    BACKUP=$(mktemp)
    cp "$FOCUS" "$BACKUP"
    # Write a focus with empty current_task
    cat > "$FOCUS" <<'EMPTY'
current_task: ""
last_change: 2026-04-29T00:00:00Z
EMPTY
    INPUT='{"tool_name":"Write","tool_input":{"file_path":"/opt/999-Agentic-Engineering-Framework/test_redteam_should_block.txt"}}'
    run bash -c "echo '$INPUT' | '$HOOK_BIN' hook check-active-task"
    rc=$status
    out=$output
    # Restore focus
    cp "$BACKUP" "$FOCUS"
    rm -f "$BACKUP"
    [ "$rc" -eq 2 ]
    [[ "$out" == *"task"* ]] || [[ "$out" == *"focus"* ]] || [[ "$out" == *"work-on"* ]]
}

# --- Gate 4 (negative): check-active-task allows context paths ---
@test "active-task hook ALLOWS Write to .context/ even with no task" {
    FOCUS="$FRAMEWORK_ROOT/.context/working/focus.yaml"
    [ -f "$FOCUS" ] || skip "no focus.yaml"
    BACKUP=$(mktemp)
    cp "$FOCUS" "$BACKUP"
    cat > "$FOCUS" <<'EMPTY'
current_task: ""
last_change: 2026-04-29T00:00:00Z
EMPTY
    INPUT='{"tool_name":"Write","tool_input":{"file_path":"/opt/999-Agentic-Engineering-Framework/.context/working/test.yaml"}}'
    run bash -c "echo '$INPUT' | '$HOOK_BIN' hook check-active-task"
    rc=$status
    cp "$BACKUP" "$FOCUS"
    rm -f "$BACKUP"
    [ "$rc" -eq 0 ]
}
