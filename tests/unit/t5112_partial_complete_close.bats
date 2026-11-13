#!/usr/bin/env bats
# T-5112: a partial-complete task (status work-completed, still in active/, an
# open ### Human box) is closed by re-running `fw task update <id> --status
# work-completed` — that is how a green reviewer verdict gets applied. The task
# gate refused it as an edit under a completed task, so only the operator could
# close (055 T-645, 2026-11-13). The allowance is exactly that command, for
# exactly that task; everything else stays blocked.

load ../test_helper

setup() {
    export FW_TEST_SKIP_TASK_CONTEXT_GATE=1  # T-4907: fixture tasks carry no ## Context
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    export CLAUDECODE=1
    mkdir -p "$TEST_TEMP_DIR/.context/working" "$TEST_TEMP_DIR/.tasks/active"
    echo "framework_root: $FRAMEWORK_ROOT" > "$TEST_TEMP_DIR/.framework.yaml"
    cat > "$TEST_TEMP_DIR/.tasks/active/T-1100-partial.md" <<'EOF'
---
id: T-1100
status: work-completed
---
# T-1100
## Acceptance Criteria
### Human
- [ ] [REVIEW] open, which is why this stayed in active/
EOF
    cat > "$TEST_TEMP_DIR/.tasks/active/T-1200-other.md" <<'EOF'
---
id: T-1200
status: started-work
---
# T-1200
EOF
    _focus T-1100
    HOOK="$FRAMEWORK_ROOT/agents/context/check-active-task.sh"
}

teardown() { rm -rf "$TEST_TEMP_DIR"; }

_focus() {
    if [ -n "$1" ]; then
        printf 'current_task: %s\nfocus_session: S-test-t5112\n' "$1" > "$TEST_TEMP_DIR/.context/working/focus.yaml"
    else
        printf 'current_task:\n' > "$TEST_TEMP_DIR/.context/working/focus.yaml"
    fi
}

_bash() {
    python3 -c "import json,sys; print(json.dumps({'tool_name':'Bash','cwd':sys.argv[2],'tool_input':{'command': sys.argv[1]}}))" "$1" "$PROJECT_ROOT" | bash "$HOOK"
}

_write() {
    python3 -c "import json,sys; print(json.dumps({'tool_name':'Write','tool_input':{'file_path': sys.argv[1], 'content':'x'}}))" "$1" | bash "$HOOK"
}

# ── The fix ──────────────────────────────────────────────────────────────────

@test "focused partial-complete task: its close command passes" {
    run _bash "bin/fw task update T-1100 --status work-completed"
    [ "$status" -eq 0 ]
    [[ "$output" == *"T-5112"* ]]
}

@test "focused partial-complete task: close after cd passes, -s short form too" {
    run _bash "cd $PROJECT_ROOT && bin/fw task update T-1100 -s work-completed"
    [ "$status" -eq 0 ]
}

@test "focus null: the close of a partial-complete task passes" {
    _focus ""
    run _bash "bin/fw task update T-1100 --status work-completed"
    [ "$status" -eq 0 ]
    [[ "$output" == *"partial-complete T-1100"* ]]
}

# ── Scope: everything else stays blocked ─────────────────────────────────────

@test "SCOPE: close with a redirect is blocked" {
    run _bash "bin/fw task update T-1100 --status work-completed > /tmp/t5112-x"
    [ "$status" -eq 2 ]
}

@test "SCOPE: close chained with a write is blocked" {
    run _bash "bin/fw task update T-1100 --status work-completed && touch foo"
    [ "$status" -eq 2 ]
}

@test "SCOPE: any other status, or a skip flag, is blocked" {
    run _bash "bin/fw task update T-1100 --status started-work"
    [ "$status" -eq 2 ]
    run _bash "bin/fw task update T-1100 --status work-completed --skip-verification --reason x"
    [ "$status" -eq 2 ]
    run _bash "bin/fw task update T-1100 --status work-completed --force"
    [ "$status" -eq 2 ]
    run _bash "bin/fw task update T-1100 --add-tag x"
    [ "$status" -eq 2 ]
}

@test "SCOPE: a shell write and a source Write stay blocked" {
    run _bash "touch foo"
    [ "$status" -eq 2 ]
    run _write "$PROJECT_ROOT/lib/x.sh"
    [ "$status" -eq 2 ]
}

@test "SCOPE: closing a DIFFERENT task while focused on this one is blocked (drift)" {
    run _bash "bin/fw task update T-1200 --status work-completed"
    [ "$status" -eq 2 ]
    [[ "$output" == *"FOCUS-DRIFT"* ]]
}

@test "SCOPE: focus null, closing a task that is NOT partial-complete stays blocked" {
    _focus ""
    run _bash "bin/fw task update T-1200 --status work-completed"
    [ "$status" -eq 2 ]
}

@test "SCOPE: a command substitution in the close is blocked" {
    run _bash "bin/fw task update \$(echo T-1100) --status work-completed"
    [ "$status" -eq 2 ]
}
