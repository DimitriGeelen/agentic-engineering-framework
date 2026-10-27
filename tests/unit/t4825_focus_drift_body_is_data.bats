#!/usr/bin/env bats
# T-4825: the focus-drift gate (T-1730) reads a `fw sidecar send --body` value as
# data. A task id inside a peer message is not the command's target; the same id
# as a real argument (or in a command chained after the send) still is.
#
# Field report: 055 be.37 field test C (msg 20f79168). Same class as T-4817 (tick
# guard), fixed the same way: lib/shell_write_scan.py:_blank_data_args.

setup() {
    FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-$(cd "$BATS_TEST_DIRNAME/../.." && pwd)}"
    HOOK="$FRAMEWORK_ROOT/agents/context/check-active-task.sh"
    TEST_ROOT="$(mktemp -d)"
    mkdir -p "$TEST_ROOT/.context/working" "$TEST_ROOT/.tasks/active"
    echo "session_id: S-test" > "$TEST_ROOT/.context/working/session.yaml"
    echo "version: test" > "$TEST_ROOT/.framework.yaml"
    echo "completed: 2026-01-01T00:00:00Z" > "$TEST_ROOT/.context/working/.onboarding-complete"
    cat > "$TEST_ROOT/.context/working/focus.yaml" <<YAML
current_task: T-1001
focus_session: S-test
priorities: []
blockers: []
YAML
    for id in T-1001 T-9999; do
        cat > "$TEST_ROOT/.tasks/active/${id}-test.md" <<MD
---
id: $id
name: "test"
status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
---
# $id

## Acceptance Criteria
### Agent
- [ ] Real AC one
MD
    done
    export PROJECT_ROOT="$TEST_ROOT"
    export CLAUDECODE=1
}

teardown() {
    rm -rf "$TEST_ROOT" 2>/dev/null
}

run_hook() {
    local input
    input=$(python3 -c "import json,sys; print(json.dumps({'tool_name':'Bash','tool_input':{'command':sys.argv[1]}}))" "$1")
    run bash "$HOOK" <<< "$input"
}

@test "body naming 'fw task update T-OTHER' is data: the send passes" {
    run_hook "bin/fw sidecar send --to w1 --conversation c1 --body 'next run bin/fw task update T-9999 --status work-completed'"
    [ "$status" -eq 0 ]
    [[ "$output" != *"FOCUS-DRIFT"* ]] || false
}

@test "body quoting a 'git commit -m \"T-OTHER: …\"' is data: the send passes" {
    run_hook "bin/fw sidecar send --to w1 --conversation c1 --body 'I ran git commit -m \"T-9999: fix\" -- lib/x.sh'"
    [ "$status" -eq 0 ]
    [[ "$output" != *"FOCUS-DRIFT"* ]] || false
}

@test "body quoting 'fw context add-learning --task T-OTHER' is data (--body= form)" {
    run_hook "fw sidecar send --to w1 --conversation c1 --body='use fw context add-learning \"x\" --task T-9999'"
    [ "$status" -eq 0 ]
    [[ "$output" != *"FOCUS-DRIFT"* ]] || false
}

@test "body with '\\'' quoting of a command-shaped T-OTHER is data" {
    run_hook "bin/fw sidecar send --to w1 --conversation c1 --body 'it'\\''s bin/fw task update T-9999 --status issues'"
    [ "$status" -eq 0 ]
    [[ "$output" != *"FOCUS-DRIFT"* ]] || false
}

@test "control: a real 'fw task update T-OTHER' still refuses" {
    run_hook "bin/fw task update T-9999 --status issues"
    [ "$status" -eq 2 ]
    [[ "$output" == *"FOCUS-DRIFT"* ]]
}

@test "control: a real command chained after the send still refuses" {
    run_hook "bin/fw sidecar send --to w1 --conversation c1 --body 'done' && bin/fw task update T-9999 --status issues"
    [ "$status" -eq 2 ]
    [[ "$output" == *"FOCUS-DRIFT"* ]]
}

@test "control: --body on a command that is not sidecar send is not blanked" {
    run_hook "bin/fw task update T-9999 --status issues --body 'x'"
    [ "$status" -eq 2 ]
    [[ "$output" == *"FOCUS-DRIFT"* ]]
}
