#!/usr/bin/env bats
# T-3179: partial-complete commit deadlock — the residual half of T-2054.
#
# T-2054 allows `git commit` when focus is NULL, which is what a FULLY
# completed task leaves behind (moved active/→completed/, focus nulled).
#
# A PARTIAL-complete task never reaches that state. An unchecked ### Human AC
# flips status to work-completed while the file STAYS in active/ and focus
# keeps pointing at it — so CURRENT_TASK is non-empty, the status switch is
# reached, and the task's own verified work cannot be committed under its own
# ID. That is the common case, not an edge one: P-013 steers every
# render-touching build task into partial-complete by design.
#
# The allowance must be SCOPED. Three things have to stay true, and each has
# its own test below, because "allows git commit" and "allows everything"
# are the same diff without them:
#   1. --no-verify / -n stays blocked (it would skip the commit-msg hook that
#      makes the allowance sound in the first place).
#   2. Non-commit writes stay blocked (the task is still completed).
#   3. The focus-drift gate (T-1730) still fires — the allowance sits AFTER
#      it in the file, so it must not be reachable for a drifting commit.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    export CLAUDECODE=1  # hook enforces (vs advisory) under agent control
    mkdir -p "$TEST_TEMP_DIR/.context/working" "$TEST_TEMP_DIR/.tasks/active"
    echo "framework_root: $FRAMEWORK_ROOT" > "$TEST_TEMP_DIR/.framework.yaml"

    # THE PARTIAL-COMPLETE SHAPE: status work-completed, file still in active/,
    # focus still pointing at it. This is what an unchecked Human AC produces.
    cat > "$TEST_TEMP_DIR/.tasks/active/T-1100-partial.md" <<'EOF'
---
id: T-1100
status: work-completed
---
# T-1100
## Acceptance Criteria
### Human
- [ ] [REVIEW] unchecked, which is why this stayed in active/
EOF
    cat > "$TEST_TEMP_DIR/.context/working/focus.yaml" <<'EOF'
current_task: T-1100
focus_session: S-test-t3179
EOF

    # A second, ordinary task — drift target for the control leg.
    cat > "$TEST_TEMP_DIR/.tasks/active/T-1200-other.md" <<'EOF'
---
id: T-1200
status: started-work
---
# T-1200
EOF

    HOOK="$FRAMEWORK_ROOT/agents/context/check-active-task.sh"
}

teardown() {
    rm -rf "$TEST_TEMP_DIR"
}

_run_hook_bash() {
    local cmd="$1"
    local json
    json=$(python3 -c "import json,sys; print(json.dumps({'tool_name':'Bash','tool_input':{'command': sys.argv[1]}}))" "$cmd")
    echo "$json" | bash "$HOOK"
}

_run_hook_write() {
    local path="$1"
    local json
    json=$(python3 -c "import json,sys; print(json.dumps({'tool_name':'Write','tool_input':{'file_path': sys.argv[1], 'content':'x'}}))" "$path")
    echo "$json" | bash "$HOOK"
}

# ── The deadlock itself ──────────────────────────────────────────────────

@test "partial-complete task CAN commit its own work under its own ID" {
    run _run_hook_bash "git commit -m 'T-1100: checkpoint the verified work'"
    [ "$status" -eq 0 ]
}

@test "the allowance announces itself so the agent knows why it passed" {
    run _run_hook_bash "git commit -m 'T-1100: checkpoint'"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "T-3179" ]]
}

# ── Scope leg 1: --no-verify stays blocked ───────────────────────────────

@test "SCOPE: --no-verify stays BLOCKED (it would skip the hook that makes this sound)" {
    run _run_hook_bash "git commit --no-verify -m 'T-1100: sneak past commit-msg'"
    [ "$status" -eq 2 ]
}

@test "SCOPE: -n short form stays BLOCKED too" {
    run _run_hook_bash "git commit -n -m 'T-1100: sneak past commit-msg'"
    [ "$status" -eq 2 ]
}

# ── Scope leg 2: the task is still completed for everything else ─────────

@test "SCOPE: a Write to a source file is still BLOCKED" {
    run _run_hook_write "$TEST_TEMP_DIR/lib/some_source.sh"
    [ "$status" -eq 2 ]
}

@test "SCOPE: a non-commit shell write is still BLOCKED" {
    run _run_hook_bash "echo mutate > lib/some_source.sh"
    [ "$status" -eq 2 ]
}

# ── Scope leg 3: THE CONTROL LEG ─────────────────────────────────────────
# Without this, "allows the focused task's commit" and "allows any commit"
# are indistinguishable. The allowance sits AFTER the drift gate in the file;
# this proves that ordering actually holds at runtime rather than on paper.

@test "CONTROL LEG: a commit targeting a DIFFERENT task is still blocked by drift" {
    run _run_hook_bash "git commit -m 'T-1200: wrong task, must not slip through'"
    [ "$status" -eq 2 ]
    [[ "$output" =~ "FOCUS-DRIFT" ]]
}

@test "CONTROL LEG: the drifting commit is refused by DRIFT, not by the status block" {
    # If the status block caught it, the allowance would be dead code for
    # drifting commits and this test would pass for the wrong reason.
    run _run_hook_bash "git commit -m 'T-1200: wrong task'"
    [ "$status" -eq 2 ]
    [[ ! "$output" =~ "has status 'work-completed'" ]]
}

# ── Baseline: ordinary work is unaffected ────────────────────────────────

@test "BASELINE: a started-work task commits as it always did" {
    cat > "$TEST_TEMP_DIR/.context/working/focus.yaml" <<'EOF'
current_task: T-1200
focus_session: S-test-t3179
EOF
    run _run_hook_bash "git commit -m 'T-1200: ordinary commit'"
    [ "$status" -eq 0 ]
}

@test "the block message tells a stuck agent that commit is allowed" {
    run _run_hook_bash "echo mutate > lib/some_source.sh"
    [ "$status" -eq 2 ]
    [[ "$output" =~ "git commit" ]]
}

# ── AC1 other half: git add was already allowed via the safe-command fast
# path (T-2054 kept it in is_bash_safe_command as task-agnostic). Pinned so a
# future narrowing of that list cannot silently re-open the deadlock.

@test "partial-complete task can stage (git add was already safe-listed)" {
    run _run_hook_bash "git add -A"
    [ "$status" -eq 0 ]
}
