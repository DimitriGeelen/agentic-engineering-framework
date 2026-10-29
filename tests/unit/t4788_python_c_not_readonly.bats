#!/usr/bin/env bats
# T-4788 (OBS-200): `python3 -c` is not read-only. With no active task, inline Python that
# writes a file through forms a text blocklist cannot see (Path.write_text/write_bytes,
# os.replace, subprocess, exec) used to pass every gate. Now any python3 -c is judged
# like any other command that may write: refused with no task, allowed with a ready one.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    export CLAUDECODE=1
    mkdir -p "$TEST_TEMP_DIR/.context/working" "$TEST_TEMP_DIR/.tasks/active"
    echo "framework_root: $FRAMEWORK_ROOT" > "$TEST_TEMP_DIR/.framework.yaml"
    HOOK="$FRAMEWORK_ROOT/agents/context/check-active-task.sh"
}

teardown() { rm -rf "$TEST_TEMP_DIR"; }

_no_task()    { printf 'current_task: null\n' > "$TEST_TEMP_DIR/.context/working/focus.yaml"; }
_ready_task() {
    cat > "$TEST_TEMP_DIR/.tasks/active/T-1300-x.md" <<'EOF'
---
id: T-1300
status: started-work
workflow_type: build
---
# T-1300

## Context

**Background / trigger:** a report came in.
**Problem / hypothesis:** the thing breaks.
**Goal:** make it work.
**Expected outcome:** it works.

## Acceptance Criteria

### Agent
- [ ] real criterion
EOF
    printf 'current_task: T-1300\nfocus_session: S-t4788\n' > "$TEST_TEMP_DIR/.context/working/focus.yaml"
}

_bash() {
    local json
    json=$(python3 -c "import json,sys; print(json.dumps({'tool_name':'Bash','tool_input':{'command':sys.argv[1]}}))" "$1")
    echo "$json" | bash "$HOOK"
}

@test "no active task: Path.write_text is refused" {
    _no_task
    run _bash "python3 -c \"import pathlib; pathlib.Path('$TEST_TEMP_DIR/x').write_text('a')\""
    [ "$status" -eq 2 ]
}

@test "no active task: Path.write_bytes is refused" {
    _no_task
    run _bash "python3 -c \"import pathlib; pathlib.Path('$TEST_TEMP_DIR/x').write_bytes(b'a')\""
    [ "$status" -eq 2 ]
}

@test "no active task: os.replace is refused" {
    _no_task
    run _bash "python3 -c \"import os; os.replace('$TEST_TEMP_DIR/a','$TEST_TEMP_DIR/b')\""
    [ "$status" -eq 2 ]
}

@test "no active task: subprocess is refused" {
    _no_task
    run _bash "python3 -c \"import subprocess; subprocess.run(['touch','$TEST_TEMP_DIR/y'])\""
    [ "$status" -eq 2 ]
}

@test "no active task: exec of a built string is refused" {
    _no_task
    run _bash "python -c \"exec('op' + 'en(1)')\""
    [ "$status" -eq 2 ]
}

@test "active task with its gates passing: an ordinary python3 -c runs" {
    _ready_task
    run _bash "python3 -c \"import json; print(json.dumps({'a': 1}))\""
    [ "$status" -eq 0 ]
}

@test "control: a shell redirect with no task is refused as before" {
    _no_task
    run _bash "echo hi > $TEST_TEMP_DIR/r"
    [ "$status" -eq 2 ]
}
