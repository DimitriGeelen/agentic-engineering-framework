#!/usr/bin/env bats
# T-4907: the active-task hook refuses source writes under a non-inception task whose
# ## Context does not state Background / trigger, Problem / hypothesis, Goal and Expected
# outcome (operator ruling 2026-10-29, "before work starts"). The task file stays writable.

load ../test_helper

setup() {
    unset FW_TEST_SKIP_TASK_CONTEXT_GATE   # this file tests the gate itself
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    export CLAUDECODE=1
    mkdir -p "$TEST_TEMP_DIR/.context/working" "$TEST_TEMP_DIR/.tasks/active" "$TEST_TEMP_DIR/lib"
    echo "framework_root: $FRAMEWORK_ROOT" > "$TEST_TEMP_DIR/.framework.yaml"
    TASK="$TEST_TEMP_DIR/.tasks/active/T-1300-x.md"
    printf 'current_task: T-1300\nfocus_session: S-t4907\n' > "$TEST_TEMP_DIR/.context/working/focus.yaml"
    HOOK="$FRAMEWORK_ROOT/agents/context/check-active-task.sh"
}

teardown() { rm -rf "$TEST_TEMP_DIR"; }

_task() {   # <workflow_type> <context body>
    printf -- '---\nid: T-1300\nstatus: started-work\nworkflow_type: %s\n---\n# T-1300\n\n## Context\n\n%s\n\n## Acceptance Criteria\n\n### Agent\n- [ ] real criterion\n' "$1" "$2" > "$TASK"
}

_write() {   # <path>
    local json
    json=$(python3 -c "import json,sys; print(json.dumps({'tool_name':'Write','tool_input':{'file_path':sys.argv[1],'content':'x'}}))" "$1")
    echo "$json" | bash "$HOOK"
}

FULL='**Background / trigger:** a report came in.
**Problem / hypothesis:** the thing breaks.
**Goal:** make it work.
**Expected outcome:** it works.'

@test "empty context: a source write is refused and the missing parts are named" {
    _task build "<!-- One sentence for small tasks. -->"
    run _write "$TEST_TEMP_DIR/lib/a.sh"
    [ "$status" -eq 2 ]
    [[ "$output" == *"has no human-readable context"* ]]
    [[ "$output" == *"Background / trigger"* ]]
    [[ "$output" == *"Expected outcome"* ]]
    [[ "$output" == *"T-4907"* ]]
}

@test "partial context: only the missing parts are named" {
    _task build "**Background / trigger:** a report came in.
**Problem / hypothesis:** the thing breaks."
    run _write "$TEST_TEMP_DIR/lib/a.sh"
    [ "$status" -eq 2 ]
    [[ "$output" == *"missing: Goal, Expected outcome"* ]]
}

@test "complete context: the same source write passes this gate" {
    _task build "$FULL"
    run _write "$TEST_TEMP_DIR/lib/a.sh"
    [ "$status" -eq 0 ]
}

@test "the task file itself stays writable while its context is empty (the remedy)" {
    _task build ""
    run _write "$TASK"
    [ "$status" -eq 0 ]
}

@test "inception tasks are exempt" {
    _task inception ""
    run _write "$TEST_TEMP_DIR/lib/a.sh"
    [[ "$output" != *"has no human-readable context"* ]]
}

@test "the test-only opt-out does nothing outside bats" {
    _task build ""
    local json
    json=$(python3 -c "import json,sys; print(json.dumps({'tool_name':'Write','tool_input':{'file_path':sys.argv[1],'content':'x'}}))" "$TEST_TEMP_DIR/lib/a.sh")
    run env -u BATS_TEST_FILENAME FW_TEST_SKIP_TASK_CONTEXT_GATE=1 bash -c "echo '$json' | bash '$HOOK'"
    [ "$status" -eq 2 ]
    [[ "$output" == *"has no human-readable context"* ]]
}
