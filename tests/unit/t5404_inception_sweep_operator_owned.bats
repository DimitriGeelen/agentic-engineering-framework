#!/usr/bin/env bats
# T-5404: `fw inception sweep` under agent control and an operator-owned inception.
#
# Origin: 150-skills-manager C-010 (2026-11-24). After a half-done decide, Watchtower
# said "the agent session can recover this (fw inception sweep)". For an
# `owner: human` task the sweep's close passes --skip-sovereignty, which update-task.sh
# refuses under CLAUDECODE=1 (T-3586) — and before refusing, the sweep had already
# ticked the ### Human box and written its provenance row under agent control.
#
# Pinned: under CLAUDECODE=1 an operator-owned decided inception is left byte-for-byte
# untouched and the operator's one line is printed; outside an agent session the same
# task closes; an agent-owned one still closes under the agent; task ids scope the sweep.
# Every test runs in a throwaway PROJECT_ROOT.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export FRAMEWORK_ROOT
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    export AGENTS_DIR="$FRAMEWORK_ROOT/agents"
    export FW_LIB_DIR="$FRAMEWORK_ROOT/lib"
    export TASKS_DIR="$TEST_TEMP_DIR/.tasks"
    export CONTEXT_DIR="$TEST_TEMP_DIR/.context"
    export NO_COLOR=1
    unset CLAUDECODE
    export WATCHTOWER_URL="http://test.invalid:3000"

    mkdir -p "$TEST_TEMP_DIR/.tasks/active" \
             "$TEST_TEMP_DIR/.tasks/completed" \
             "$TEST_TEMP_DIR/.context/working" \
             "$TEST_TEMP_DIR/.context/episodic" \
             "$TEST_TEMP_DIR/.context/project"
    echo "id: TEST" > "$TEST_TEMP_DIR/.framework.yaml"

    source "$FRAMEWORK_ROOT/lib/colors.sh"
    source "$FRAMEWORK_ROOT/lib/paths.sh"
    source "$FRAMEWORK_ROOT/lib/errors.sh" 2>/dev/null || true
    source "$FRAMEWORK_ROOT/lib/tasks.sh"
    source "$FRAMEWORK_ROOT/lib/inception.sh"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# $1 task id, $2 status, $3 Agent AC box ("x" or " ")
_make_task() {
    local task_id="$1" status="$2" box="$3" owner="${4:-agent}"
    local f="$TEST_TEMP_DIR/.tasks/active/$task_id-sweep-test.md"
    cat > "$f" <<EOF
---
id: $task_id
name: "T-5404 sweep test"
status: $status
workflow_type: inception
owner: $owner
horizon: now
created: 2026-10-21T00:00:00Z
last_update: 2026-10-21T00:00:00Z
---

# $task_id: sweep test

## Recommendation

**Recommendation:** GO
**Rationale:** test
**Evidence:** test

## Acceptance Criteria

### Agent
- [$box] Exploration findings written up

### Human
- [ ] [REVIEW] Review exploration findings and approve go/no-go decision

## Decision

**Decision**: GO

## Updates
EOF
    echo "$f"
}

_stub_update_task() {
    export AGENTS_DIR="$TEST_TEMP_DIR/agents"
    mkdir -p "$AGENTS_DIR/task-create"
    cat > "$AGENTS_DIR/task-create/update-task.sh" <<STUB
#!/usr/bin/env bash
echo "\$*" >> "$TEST_TEMP_DIR/update-task.calls"
exit 0
STUB
    chmod +x "$AGENTS_DIR/task-create/update-task.sh"
}

@test "T-5404: agent sweep leaves an operator-owned decided inception untouched and prints the operator line" {
    local f before
    f=$(_make_task T-9811 started-work x human)
    before=$(sha256sum "$f")
    export CLAUDECODE=1

    run do_inception_sweep
    [ "$status" -eq 1 ]
    [[ "$output" == *"T-9811: decision recorded, but the task is operator-owned"* ]]
    [[ "$output" == *"Operator, from your own terminal:"* ]]
    [[ "$output" == *"cd $TEST_TEMP_DIR && "*"inception sweep T-9811"* ]]
    # Untouched: same bytes (Human box not ticked), still in active/, no tick ledger row
    [ "$(sha256sum "$f")" = "$before" ]
    grep -q '^- \[ \] \[REVIEW\]' "$f"
    [ ! -f "$TEST_TEMP_DIR/.context/reviews/human-ac-ticks.jsonl" ]
    # The refused --skip-sovereignty attempt never happened
    [[ "$output" != *"refused in an agent session"* ]]
}

@test "T-5404: the same task closes when the operator runs the sweep (no CLAUDECODE)" {
    _stub_update_task
    _make_task T-9812 started-work x human >/dev/null
    unset CLAUDECODE

    run do_inception_sweep T-9812
    [ "$status" -eq 0 ]
    grep -q -- 'T-9812 --status work-completed --skip-sovereignty' "$TEST_TEMP_DIR/update-task.calls"
    [[ "$output" != *"Operator, from your own terminal"* ]]
}

@test "T-5404: an agent-owned decided inception still closes under the agent" {
    _stub_update_task
    _make_task T-9813 started-work x agent >/dev/null
    export CLAUDECODE=1

    run do_inception_sweep
    [ "$status" -eq 0 ]
    grep -q -- 'T-9813 --status work-completed' "$TEST_TEMP_DIR/update-task.calls"
}

@test "T-5404: agent sweep does not claim to park an operator-owned DEFER" {
    _stub_update_task
    local f before
    f=$(_make_task T-9814 started-work x human)
    sed -i 's/^\*\*Decision\*\*: GO$/**Decision**: DEFER/' "$f"
    before=$(sha256sum "$f")
    export CLAUDECODE=1

    run do_inception_sweep
    [ "$status" -eq 1 ]
    [[ "$output" != *"parked"* ]]
    [[ "$output" == *"inception sweep T-9814"* ]]
    [ "$(sha256sum "$f")" = "$before" ]
    [ ! -f "$TEST_TEMP_DIR/update-task.calls" ]
}

@test "T-5404: named task ids scope the sweep" {
    _stub_update_task
    _make_task T-9815 started-work x agent >/dev/null
    _make_task T-9816 started-work x agent >/dev/null

    run do_inception_sweep T-9816
    [ "$status" -eq 0 ]
    [[ "$output" == *"scanned=1"* ]]
    grep -q 'T-9816' "$TEST_TEMP_DIR/update-task.calls"
    ! grep -q 'T-9815' "$TEST_TEMP_DIR/update-task.calls"
}

@test "T-5404: the printed operator line really closes the task (real update-task.sh)" {
    _make_task T-9817 started-work x human >/dev/null
    export CLAUDECODE=1
    run do_inception_sweep
    [ "$status" -eq 1 ]
    [ -f "$TEST_TEMP_DIR/.tasks/active/T-9817-sweep-test.md" ]

    # The operator runs the printed line from their own terminal.
    unset CLAUDECODE
    run do_inception_sweep T-9817
    echo "$output"
    [ "$status" -eq 0 ]
    [ ! -f "$TEST_TEMP_DIR/.tasks/active/T-9817-sweep-test.md" ]
    [ -f "$TEST_TEMP_DIR/.tasks/completed/T-9817-sweep-test.md" ]
}
