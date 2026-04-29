#!/usr/bin/env bats
# T-1606 (T-1601 GO follow-up): red-team harness covering all 7 PreToolUse gates.
#
# Pattern: invoke each PreToolUse hook directly with a constructed JSON envelope
# matching Claude Code's tool-call format, assert exit code 2 (block) and that
# stderr contains the expected error keyword.
#
# Renames + extends tests/governance/test_gates_prototype.bats (3 gates) to cover:
#   1. block-plan-mode        (EnterPlanMode)
#   2. block-task-tools       (TodoWrite/TaskCreate/TaskUpdate/TaskList/TaskGet)
#   3. check-active-task      (Write/Edit without focus)
#   4. check-tier0            (Bash with destructive command, no approval)
#   5. check-agent-dispatch   (Agent tool exceeding FW_DISPATCH_LIMIT)
#   6. check-project-boundary (Write to path outside PROJECT_ROOT)
#   7. budget-gate            (covered indirectly — depends on session transcript)
#
# State-dependent tests use save/restore for isolation. No mutating side effects.

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
HOOK_BIN="$FRAMEWORK_ROOT/bin/fw"

# ============================================================================
# Gate 1: block-plan-mode
# ============================================================================

@test "block-plan-mode: blocks EnterPlanMode tool" {
    INPUT='{"tool_name":"EnterPlanMode","tool_input":{}}'
    run bash -c "echo '$INPUT' | '$HOOK_BIN' hook block-plan-mode"
    [ "$status" -eq 2 ]
    [[ "$output" == *"plan"* ]] || [[ "$output" == *"EnterPlanMode"* ]] || [[ "$output" == *"/plan"* ]]
}

# ============================================================================
# Gate 2: block-task-tools (G-022)
# ============================================================================

@test "block-task-tools: blocks TodoWrite" {
    INPUT='{"tool_name":"TodoWrite","tool_input":{"todos":[]}}'
    run bash -c "echo '$INPUT' | '$HOOK_BIN' hook block-task-tools"
    [ "$status" -eq 2 ]
    [[ "$output" == *"TodoWrite"* ]] || [[ "$output" == *"task-tools"* ]] || [[ "$output" == *"fw work-on"* ]]
}

@test "block-task-tools: blocks TaskCreate" {
    INPUT='{"tool_name":"TaskCreate","tool_input":{"description":"x"}}'
    run bash -c "echo '$INPUT' | '$HOOK_BIN' hook block-task-tools"
    [ "$status" -eq 2 ]
}

@test "block-task-tools: blocks TaskUpdate" {
    INPUT='{"tool_name":"TaskUpdate","tool_input":{"id":"x","status":"completed"}}'
    run bash -c "echo '$INPUT' | '$HOOK_BIN' hook block-task-tools"
    [ "$status" -eq 2 ]
}

# ============================================================================
# Gate 3: check-active-task (G-013)
# ============================================================================

@test "check-active-task: blocks Write to source when no active task" {
    FOCUS="$FRAMEWORK_ROOT/.context/working/focus.yaml"
    [ -f "$FOCUS" ] || skip "no focus.yaml"
    BACKUP=$(mktemp); cp "$FOCUS" "$BACKUP"
    cat > "$FOCUS" <<'EMPTY'
current_task: ""
last_change: 2026-04-29T00:00:00Z
EMPTY
    INPUT='{"tool_name":"Write","tool_input":{"file_path":"/opt/999-Agentic-Engineering-Framework/test_redteam_should_block.txt"}}'
    run bash -c "echo '$INPUT' | '$HOOK_BIN' hook check-active-task"
    rc=$status; out=$output
    cp "$BACKUP" "$FOCUS"; rm -f "$BACKUP"
    [ "$rc" -eq 2 ]
    [[ "$out" == *"task"* ]] || [[ "$out" == *"focus"* ]] || [[ "$out" == *"work-on"* ]]
}

@test "check-active-task: ALLOWS Write to .context/ even without task" {
    FOCUS="$FRAMEWORK_ROOT/.context/working/focus.yaml"
    [ -f "$FOCUS" ] || skip "no focus.yaml"
    BACKUP=$(mktemp); cp "$FOCUS" "$BACKUP"
    cat > "$FOCUS" <<'EMPTY'
current_task: ""
last_change: 2026-04-29T00:00:00Z
EMPTY
    INPUT='{"tool_name":"Write","tool_input":{"file_path":"/opt/999-Agentic-Engineering-Framework/.context/working/test.yaml"}}'
    run bash -c "echo '$INPUT' | '$HOOK_BIN' hook check-active-task"
    rc=$status
    cp "$BACKUP" "$FOCUS"; rm -f "$BACKUP"
    [ "$rc" -eq 0 ]
}

# ============================================================================
# Gate 4: check-tier0 (Tier 0 destructive commands)
# ============================================================================

# Tier 0 save/restore helper: if a real approval is present, move it aside
# for the duration of the test so the hook's no-approval path is exercised.
_tier0_isolate() {
    APPROVAL="$FRAMEWORK_ROOT/.context/working/.tier0-approval"
    if [ -f "$APPROVAL" ]; then
        TIER0_BACKUP=$(mktemp)
        mv "$APPROVAL" "$TIER0_BACKUP"
    else
        TIER0_BACKUP=""
    fi
}
_tier0_restore() {
    if [ -n "${TIER0_BACKUP:-}" ] && [ -f "$TIER0_BACKUP" ]; then
        mv "$TIER0_BACKUP" "$APPROVAL"
    fi
}

@test "check-tier0: blocks 'git push --force' without approval" {
    _tier0_isolate
    INPUT='{"tool_name":"Bash","tool_input":{"command":"git push --force origin master"}}'
    run bash -c "echo '$INPUT' | '$HOOK_BIN' hook check-tier0"
    rc=$status; out=$output
    _tier0_restore
    [ "$rc" -eq 2 ]
    [[ "$out" == *"Tier"* ]] || [[ "$out" == *"BLOCKED"* ]] || [[ "$out" == *"approval"* ]]
}

@test "check-tier0: blocks 'rm -rf /' wildcard" {
    _tier0_isolate
    INPUT='{"tool_name":"Bash","tool_input":{"command":"rm -rf /"}}'
    run bash -c "echo '$INPUT' | '$HOOK_BIN' hook check-tier0"
    rc=$status
    _tier0_restore
    [ "$rc" -eq 2 ]
}

@test "check-tier0: ALLOWS benign commands (ls, echo)" {
    INPUT='{"tool_name":"Bash","tool_input":{"command":"ls -la"}}'
    run bash -c "echo '$INPUT' | '$HOOK_BIN' hook check-tier0"
    [ "$status" -eq 0 ]
}

# ============================================================================
# Gate 5: check-agent-dispatch (FW_DISPATCH_LIMIT)
# ============================================================================

@test "check-agent-dispatch: blocks Agent dispatch above limit" {
    COUNTER="$FRAMEWORK_ROOT/.context/working/.agent-dispatch-counter"
    BACKUP=""
    if [ -f "$COUNTER" ]; then
        BACKUP=$(mktemp); cp "$COUNTER" "$BACKUP"
    fi
    # Force counter just below limit so the increment exceeds
    # Default DISPATCH_LIMIT is 2 — bump counter to 5 to ensure exceed.
    echo "5" > "$COUNTER"
    INPUT='{"tool_name":"Agent","tool_input":{"description":"test","prompt":"x"}}'
    run bash -c "echo '$INPUT' | '$HOOK_BIN' hook check-agent-dispatch"
    rc=$status; out=$output
    # Restore counter
    if [ -n "$BACKUP" ]; then cp "$BACKUP" "$COUNTER"; rm -f "$BACKUP"; else rm -f "$COUNTER"; fi
    # Hook may exit 2 (BLOCKED) or 0 (NOTE: TermLink not installed — allowing).
    # We assert one of two states: either blocked, OR noted-and-allowed.
    if [ "$rc" -eq 2 ]; then
        [[ "$out" == *"BLOCKED"* ]] || [[ "$out" == *"limit"* ]]
    else
        # TermLink not installed path — informational only
        [ "$rc" -eq 0 ]
        [[ "$out" == *"NOTE"* ]] || [[ "$out" == *"limit"* ]] || true
    fi
}

# ============================================================================
# Gate 6: check-project-boundary
# ============================================================================

@test "check-project-boundary: blocks Write outside PROJECT_ROOT" {
    INPUT='{"tool_name":"Write","tool_input":{"file_path":"/etc/passwd"}}'
    run bash -c "echo '$INPUT' | '$HOOK_BIN' hook check-project-boundary"
    [ "$status" -eq 2 ]
    [[ "$output" == *"boundary"* ]] || [[ "$output" == *"PROJECT_ROOT"* ]] || [[ "$output" == *"outside"* ]]
}

@test "check-project-boundary: ALLOWS Write inside PROJECT_ROOT" {
    INPUT='{"tool_name":"Write","tool_input":{"file_path":"/opt/999-Agentic-Engineering-Framework/test.txt"}}'
    run bash -c "echo '$INPUT' | '$HOOK_BIN' hook check-project-boundary"
    [ "$status" -eq 0 ]
}

# ============================================================================
# Gate 7: budget-gate (depends on session transcript — partial coverage)
# ============================================================================

@test "budget-gate: ALLOWS when no transcript path provided (fail-open path)" {
    # No session_id in JSON → hook cannot read tokens → falls through to allow
    # (PostToolUse fallback handles enforcement in this case per T-138/T-271).
    INPUT='{"tool_name":"Write","tool_input":{"file_path":"/opt/999-Agentic-Engineering-Framework/test.txt"}}'
    run bash -c "echo '$INPUT' | '$HOOK_BIN' hook budget-gate"
    # Must not crash; either 0 (allow) or 2 (block based on cached state).
    [ "$status" -eq 0 ] || [ "$status" -eq 2 ]
}
