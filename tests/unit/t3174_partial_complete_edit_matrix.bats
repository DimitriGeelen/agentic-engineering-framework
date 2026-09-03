#!/usr/bin/env bats
# T-3174: partial-complete state revokes a task's authority to commit its own
# closure artefacts — the residual scope T-3179 left open.
#
# T-3179 solved ONE cell (partial-complete x git commit). This pins the full
# matrix {partial-complete, archived} x {governance-path write, source write,
# git commit}, plus the AC5 escape (FW_ALLOW_PARTIAL_COMPLETE_EDIT=1) for a
# further EDIT (not a commit) on a partial-complete task -- the case where
# `fw work-on <same-task>` cannot help because status-transitions.yaml has no
# outgoing edge from work-completed.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    export CLAUDECODE=1
    mkdir -p "$TEST_TEMP_DIR/.context/working" "$TEST_TEMP_DIR/.tasks/active" "$TEST_TEMP_DIR/.tasks/completed"
    echo "framework_root: $FRAMEWORK_ROOT" > "$TEST_TEMP_DIR/.framework.yaml"

    # Partial-complete: status work-completed, file STILL in active/, focus
    # still pointing at it. What an unchecked Human AC produces.
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

    # Genuinely archived: file ONLY in completed/, absent from active/.
    cat > "$TEST_TEMP_DIR/.tasks/completed/T-9000-done.md" <<'EOF'
---
id: T-9000
status: work-completed
---
# T-9000
EOF

    HOOK="$FRAMEWORK_ROOT/agents/context/check-active-task.sh"
}

teardown() {
    rm -rf "$TEST_TEMP_DIR"
}

_focus_on() {
    cat > "$TEST_TEMP_DIR/.context/working/focus.yaml" <<EOF
current_task: $1
focus_session: S-test-t3174
EOF
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

# -- MATRIX: partial-complete ---------------------------------------------

@test "MATRIX partial-complete x governance-path write: allowed (T-441 exemption)" {
    _focus_on T-1100
    run _run_hook_write "$TEST_TEMP_DIR/.context/working/note.yaml"
    [ "$status" -eq 0 ]
}

@test "MATRIX partial-complete x source write: blocked" {
    _focus_on T-1100
    run _run_hook_write "$TEST_TEMP_DIR/lib/some_source.sh"
    [ "$status" -eq 2 ]
    [[ "$output" =~ "has status 'work-completed'" ]]
}

@test "MATRIX partial-complete x git commit: allowed (T-3179, REGRESSION CELL)" {
    _focus_on T-1100
    run _run_hook_bash "git commit -m 'T-1100: checkpoint the verified work'"
    [ "$status" -eq 0 ]
}

# -- MATRIX: archived -------------------------------------------------------

@test "MATRIX archived x governance-path write: allowed (T-441 exemption, task status irrelevant)" {
    _focus_on T-9000
    run _run_hook_write "$TEST_TEMP_DIR/.context/working/note.yaml"
    [ "$status" -eq 0 ]
}

@test "MATRIX archived x source write: blocked as not-active, NOT as work-completed" {
    _focus_on T-9000
    run _run_hook_write "$TEST_TEMP_DIR/lib/some_source.sh"
    [ "$status" -eq 2 ]
    [[ "$output" =~ "is not active" ]]
    [[ ! "$output" =~ "has status 'work-completed'" ]]
}

@test "MATRIX archived x git commit: blocked as not-active (AC6: work-completed branch unreachable)" {
    _focus_on T-9000
    run _run_hook_bash "git commit -m 'T-9000: too late, already archived'"
    [ "$status" -eq 2 ]
    [[ "$output" =~ "is not active" ]]
    [[ ! "$output" =~ "has status 'work-completed'" ]]
}

# -- AC5: graduated edit bypass on a partial-complete task -----------------

@test "AC5: source write on partial-complete is allowed under FW_ALLOW_PARTIAL_COMPLETE_EDIT=1" {
    _focus_on T-1100
    local json
    json=$(python3 -c "import json,sys; print(json.dumps({'tool_name':'Write','tool_input':{'file_path': sys.argv[1], 'content':'x'}}))" "$TEST_TEMP_DIR/lib/some_source.sh")
    run bash -c "echo '$json' | FW_ALLOW_PARTIAL_COMPLETE_EDIT=1 bash '$HOOK'"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "FW_ALLOW_PARTIAL_COMPLETE_EDIT" ]]
}

@test "AC5: the bypass writes a Tier-2 entry to .gate-bypass-log.yaml" {
    _focus_on T-1100
    local json
    json=$(python3 -c "import json,sys; print(json.dumps({'tool_name':'Write','tool_input':{'file_path': sys.argv[1], 'content':'x'}}))" "$TEST_TEMP_DIR/lib/some_source.sh")
    run bash -c "echo '$json' | FW_ALLOW_PARTIAL_COMPLETE_EDIT=1 bash '$HOOK'"
    [ "$status" -eq 0 ]
    [ -f "$TEST_TEMP_DIR/.context/working/.gate-bypass-log.yaml" ]
    grep -q "flag: 'FW_ALLOW_PARTIAL_COMPLETE_EDIT'" "$TEST_TEMP_DIR/.context/working/.gate-bypass-log.yaml"
    grep -q "task: 'T-1100'" "$TEST_TEMP_DIR/.context/working/.gate-bypass-log.yaml"
}

@test "AC5: without the bypass flag, source write stays blocked (control)" {
    _focus_on T-1100
    run _run_hook_write "$TEST_TEMP_DIR/lib/some_source.sh"
    [ "$status" -eq 2 ]
    [[ "$output" =~ "FW_ALLOW_PARTIAL_COMPLETE_EDIT" ]]
}

@test "AC5: FW_SAFE_MODE is NOT what the block message recommends (must not be the only escape)" {
    _focus_on T-1100
    run _run_hook_write "$TEST_TEMP_DIR/lib/some_source.sh"
    [ "$status" -eq 2 ]
    [[ ! "$output" =~ "FW_SAFE_MODE" ]]
}

@test "AC4: block message no longer advertises fw work-on same-task as a working remedy" {
    _focus_on T-1100
    run _run_hook_write "$TEST_TEMP_DIR/lib/some_source.sh"
    [ "$status" -eq 2 ]
    [[ "$output" =~ "will NOT" ]]
    [[ "$output" =~ "no outgoing edge" ]]
}
