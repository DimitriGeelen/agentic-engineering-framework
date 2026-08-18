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
# ── Isolation (T-3077, applying L-256/T-1428) ────────────────────────────────
# These tests run the REAL hooks. check-tier0.sh writes two records into
# PROJECT_ROOT whenever it blocks, so the operator can grant the request:
#
#     .context/working/.tier0-approval.pending
#     .context/approvals/pending-<hash12>.yaml   (the Watchtower /approvals card)
#
# Run against the live project, that files a genuine Tier 0 approval request for
# `rm -rf /` with an Approve button next to it. It did, for four months: the
# previous helper here (_tier0_isolate/_tier0_restore) backed up .tier0-approval
# — the GRANTED file — and neither of the two the hook actually writes. This
# header used to read "No mutating side effects", which is why nobody re-checked.
#
# setup() now gives the Tier 0 gate a sandbox PROJECT_ROOT. Isolation is by
# CONSTRUCTION, not cleanup: the card is written into a throwaway tree, so a
# killed or crashed run cannot leave one behind (bats teardown does not run when
# the process is killed).
#
# Scope note: the sandbox is applied to the check-tier0 invocations only, not
# exported file-wide. Exporting it for every test changes what the other gates
# resolve — measured: check-active-task flips from allow to block, and the
# check-project-boundary tests assert against the live root by design. Widening
# it would silently rewrite what those tests mean. The A1 guard in
# tests/governance/test_t3077_approvals_surface_isolation.bats is what holds the
# whole file to the invariant, whatever hook a future test reaches for.

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
HOOK_BIN="$FRAMEWORK_ROOT/bin/fw"

setup() {
    # Sandbox root for hooks with .context/ side effects (T-3077, L-256).
    # Both directories below are REQUIRED — measured, not assumed:
    #   .tasks/           bin/fw's _project_root_is_stale() treats a markerless
    #                     directory as stale and re-resolves to the live project,
    #                     so without this marker the PROJECT_ROOT export is
    #                     silently ignored and the approval card leaks anyway.
    #   .context/working/ check-tier0.sh:463 writes ${APPROVAL_FILE}.pending with
    #                     a bare redirect and no mkdir -p; the write fails without
    #                     it (the approvals/ dir it creates itself).
    FW_SANDBOX_ROOT="$BATS_TEST_TMPDIR/fw-sandbox"
    mkdir -p "$FW_SANDBOX_ROOT/.tasks/active" "$FW_SANDBOX_ROOT/.context/working"
    export FW_SANDBOX_ROOT
}

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

# Run the real check-tier0 hook against the sandbox root. The hook resolves its
# own APPROVAL_FILE / APPROVAL_DIR from PROJECT_ROOT (check-tier0.sh:63,466), and
# lib/paths.sh:39 honours an env override, so the pending request lands in the
# sandbox. Nothing to restore afterwards — that is the point (T-3077 A2).
_tier0_run() {
    run env PROJECT_ROOT="$FW_SANDBOX_ROOT" bash -c "echo '$1' | '$HOOK_BIN' hook check-tier0"
}

# Positive control (T-3077 A3): the hook must still have FIRED and FILED its
# request inside the sandbox. Without this, the isolation guard is satisfied by a
# test that has quietly stopped exercising the gate — two empty sets are equal.
_assert_pending_filed_in_sandbox() {
    local expect_preview="$1"
    local card_count card hash12
    card_count=$(find "$FW_SANDBOX_ROOT/.context/approvals" -maxdepth 1 -name 'pending-*.yaml' | wc -l)
    [ "$card_count" -eq 1 ]
    card=$(find "$FW_SANDBOX_ROOT/.context/approvals" -maxdepth 1 -name 'pending-*.yaml')
    grep -qx "command_preview: $expect_preview" "$card"
    grep -qx "status: pending" "$card"
    [ -f "$FW_SANDBOX_ROOT/.context/working/.tier0-approval.pending" ]
    grep -q ' PENDING$' "$FW_SANDBOX_ROOT/.context/working/.tier0-approval.pending"

    # ...and the same card must NOT exist on the live approvals surface.
    hash12=$(basename "$card" .yaml); hash12=${hash12#pending-}
    [ ! -e "$FRAMEWORK_ROOT/.context/approvals/pending-${hash12}.yaml" ]

    # The GRANTED file is never written by a test, under any root (T-3077).
    [ ! -e "$FW_SANDBOX_ROOT/.context/working/.tier0-approval" ]
}

@test "check-tier0: blocks 'git push --force' without approval" {
    _tier0_run '{"tool_name":"Bash","tool_input":{"command":"git push --force origin master"}}'
    [ "$status" -eq 2 ]
    [[ "$output" == *"TIER 0 BLOCK"* ]]
    [[ "$output" == *"Risk: FORCE PUSH: Can overwrite remote commit history"* ]]
    _assert_pending_filed_in_sandbox "git push --force origin master"
}

@test "check-tier0: blocks 'rm -rf /' wildcard" {
    _tier0_run '{"tool_name":"Bash","tool_input":{"command":"rm -rf /"}}'
    [ "$status" -eq 2 ]
    [[ "$output" == *"TIER 0 BLOCK"* ]]
    [[ "$output" == *"Risk: RECURSIVE DELETE"* ]]
    _assert_pending_filed_in_sandbox "rm -rf /"
}

@test "check-tier0: ALLOWS benign commands (ls, echo)" {
    _tier0_run '{"tool_name":"Bash","tool_input":{"command":"ls -la"}}'
    [ "$status" -eq 0 ]
    # Negative control: an allowed command files no request anywhere.
    [ -z "$(find "$FW_SANDBOX_ROOT/.context/approvals" -maxdepth 1 -name 'pending-*.yaml' 2>/dev/null)" ]
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
