#!/usr/bin/env bats
# T-4285 (832 OBS-437/T-1199): a Write/Edit whose target is a closed record in
# .tasks/completed/ is judged by THAT task, not by the focused one. Before the fix
# check-active-task.sh exempted all of .tasks/* ahead of reading focus, so a closed
# record was writable under any focus. Sanctioned route: an Edit that only appends
# inside the record's ## Updates section (logged), or FW_ALLOW_CLOSED_RECORD_EDIT=1
# on the hook process (logged Tier-2).

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    mkdir -p "$TEST_TEMP_DIR/.context/working" "$TEST_TEMP_DIR/.tasks/active" "$TEST_TEMP_DIR/.tasks/completed"
    echo "framework_root: $FRAMEWORK_ROOT" > "$TEST_TEMP_DIR/.framework.yaml"
    cat > "$TEST_TEMP_DIR/.tasks/active/T-9001-focused.md" <<'EOF'
---
id: T-9001
name: focused
status: started-work
workflow_type: build
---
# T-9001
EOF
    CLOSED="$TEST_TEMP_DIR/.tasks/completed/T-9002-closed.md"
    cat > "$CLOSED" <<'EOF'
---
id: T-9002
name: closed
status: work-completed
workflow_type: build
---
# T-9002

## Acceptance Criteria

- [x] done

## Updates

### 2026-10-17T00:00:00Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
EOF
    printf 'current_task: T-9001\n' > "$TEST_TEMP_DIR/.context/working/focus.yaml"
    HOOK="$FRAMEWORK_ROOT/agents/context/check-active-task.sh"
    BYPASS_LOG="$TEST_TEMP_DIR/.context/working/.gate-bypass-log.yaml"
    export CLAUDECODE=1
}

teardown() {
    rm -rf "$TEST_TEMP_DIR"
}

_run_hook() {
    # $1 = JSON payload
    echo "$1" | bash "$HOOK"
}

_edit_json() {
    # $1 file, $2 old, $3 new
    python3 -c "import json,sys; print(json.dumps({'tool_name':'Edit','tool_input':{'file_path':sys.argv[1],'old_string':sys.argv[2],'new_string':sys.argv[3]}}))" "$1" "$2" "$3"
}

@test "focus T-9001 started, Write to completed/T-9002 is refused and names the closed task" {
    json=$(python3 -c "import json,sys; print(json.dumps({'tool_name':'Write','tool_input':{'file_path':sys.argv[1],'content':'x'}}))" "$CLOSED")
    run _run_hook "$json"
    [ "$status" -eq 2 ]
    [[ "$output" == *"T-9002"* ]]
    [[ "$output" == *"FW_ALLOW_CLOSED_RECORD_EDIT"* ]]
}

@test "focus T-9001 started, Edit rewriting an AC in completed/T-9002 is refused" {
    run _run_hook "$(_edit_json "$CLOSED" "- [x] done" "- [x] done differently")"
    [ "$status" -eq 2 ]
    [[ "$output" == *"T-9002"* ]]
}

@test "Edit that appends after old_string OUTSIDE ## Updates is refused" {
    run _run_hook "$(_edit_json "$CLOSED" "- [x] done" "- [x] done
- [x] sneaked in")"
    [ "$status" -eq 2 ]
}

@test "append inside ## Updates is allowed and logged" {
    old='- **Change:** status: started-work → work-completed'
    new="$old

### 2026-10-21T00:00:00Z — correction [reporter]
- **Note:** reporter correction"
    run _run_hook "$(_edit_json "$CLOSED" "$old" "$new")"
    [ "$status" -eq 0 ]
    grep -q "closed-record-updates-append" "$BYPASS_LOG"
    grep -q "T-9002" "$BYPASS_LOG"
}

@test "append inside ## Updates that adds a new ## section is refused" {
    old='- **Change:** status: started-work → work-completed'
    new="$old

## Acceptance Criteria
- [x] forged"
    run _run_hook "$(_edit_json "$CLOSED" "$old" "$new")"
    [ "$status" -eq 2 ]
}

@test "replace_all append is refused" {
    old='- **Change:** status: started-work → work-completed'
    json=$(python3 -c "import json,sys; print(json.dumps({'tool_name':'Edit','tool_input':{'file_path':sys.argv[1],'old_string':sys.argv[2],'new_string':sys.argv[2]+'\nmore','replace_all':True}}))" "$CLOSED" "$old")
    run _run_hook "$json"
    [ "$status" -eq 2 ]
}

@test "FW_ALLOW_CLOSED_RECORD_EDIT=1 on the hook process allows and logs Tier-2" {
    json=$(python3 -c "import json,sys; print(json.dumps({'tool_name':'Write','tool_input':{'file_path':sys.argv[1],'content':'x'}}))" "$CLOSED")
    FW_ALLOW_CLOSED_RECORD_EDIT=1 run _run_hook "$json"
    [ "$status" -eq 0 ]
    grep -q "FW_ALLOW_CLOSED_RECORD_EDIT" "$BYPASS_LOG"
}

@test "control: Edit to .tasks/active/ task file stays allowed" {
    run _run_hook "$(_edit_json "$TEST_TEMP_DIR/.tasks/active/T-9001-focused.md" "# T-9001" "# T-9001 edited")"
    [ "$status" -eq 0 ]
}

@test "control: outside agent control the closed-record write is not blocked" {
    json=$(python3 -c "import json,sys; print(json.dumps({'tool_name':'Write','tool_input':{'file_path':sys.argv[1],'content':'x'}}))" "$CLOSED")
    CLAUDECODE= AI_AGENT= run _run_hook "$json"
    [ "$status" -eq 0 ]
}
