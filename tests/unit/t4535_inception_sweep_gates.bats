#!/usr/bin/env bats
# T-4535: `fw inception sweep` must close a GO/NO-GO-recorded inception through
# update-task.sh's close gates, never by editing `status:` in place.
#
# Origin: 832 msg 2cc0100a (their T-1065). The sweep's class-2 recovery
# (started-work + GO recorded) rewrote `status: started-work` to
# `status: work-completed` with sed and mv'd the file to completed/, so a task
# whose close a gate was still holding (P-010 unticked Agent AC, P-011, RCA …)
# was closed past the gate. A captured + GO task was skipped outright.
#
# Every test runs in a throwaway PROJECT_ROOT; none touches this repo's tasks.

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
    local task_id="$1" status="$2" box="$3"
    local f="$TEST_TEMP_DIR/.tasks/active/$task_id-sweep-test.md"
    cat > "$f" <<EOF
---
id: $task_id
name: "T-4535 sweep test"
status: $status
workflow_type: inception
owner: agent
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

# A stub update-task.sh that records its argv and exits with $1.
_stub_update_task() {
    export AGENTS_DIR="$TEST_TEMP_DIR/agents"
    mkdir -p "$AGENTS_DIR/task-create"
    cat > "$AGENTS_DIR/task-create/update-task.sh" <<STUB
#!/usr/bin/env bash
echo "\$*" >> "$TEST_TEMP_DIR/update-task.calls"
[ "$1" -ne 0 ] && echo "stub: close refused by a gate" >&2
exit $1
STUB
    chmod +x "$AGENTS_DIR/task-create/update-task.sh"
}

@test "T-4535: gate-held GO inception is NOT closed past the real P-010 gate" {
    local f
    f=$(_make_task T-9701 started-work " ")

    run do_inception_sweep
    [ "$status" -ne 0 ]
    # Untouched: still in active/, still started-work
    [ -f "$f" ]
    [ ! -f "$TEST_TEMP_DIR/.tasks/completed/T-9701-sweep-test.md" ]
    grep -q '^status: started-work$' "$f"
    [[ "$output" == *"T-9701"* ]]
    [[ "$output" == *"held=1"* ]]
    # The refusal is P-010's (the unticked Agent AC), surfaced to the operator
    [[ "$output" == *"Cannot complete"*"unchecked"* ]]
}

@test "T-4535: started-work + GO closes through update-task, not sed" {
    _stub_update_task 0
    local f
    f=$(_make_task T-9702 started-work x)

    run do_inception_sweep
    [ "$status" -eq 0 ]
    grep -q -- 'T-9702 --status work-completed' "$TEST_TEMP_DIR/update-task.calls"
    # The sweep itself must not have written the status line
    grep -q '^status: started-work$' "$f"
}

@test "T-4535: update-task refusal is reported, exits non-zero, file untouched" {
    _stub_update_task 7
    local f
    f=$(_make_task T-9703 started-work x)

    run do_inception_sweep
    [ "$status" -ne 0 ]
    [[ "$output" == *"close refused by a gate"* ]]
    [[ "$output" == *"held=1"* ]]
    [ -f "$f" ]
    grep -q '^status: started-work$' "$f"
}

@test "T-4535: captured + GO is recovered via started-work then work-completed" {
    _stub_update_task 0
    _make_task T-9704 captured x >/dev/null

    run do_inception_sweep
    [ "$status" -eq 0 ]
    run cat "$TEST_TEMP_DIR/update-task.calls"
    [ "${lines[0]%% *}" = "T-9704" ]
    [[ "${lines[0]}" == *"--status started-work"* ]]
    [[ "${lines[1]}" == *"--status work-completed"* ]]
}

@test "T-4535: real update-task closes a clean started-work + GO inception" {
    local f
    f=$(_make_task T-9705 started-work x)

    run do_inception_sweep
    [ "$status" -eq 0 ]
    [ ! -f "$f" ]
    [ -f "$TEST_TEMP_DIR/.tasks/completed/T-9705-sweep-test.md" ]
    grep -q '^status: work-completed$' "$TEST_TEMP_DIR/.tasks/completed/T-9705-sweep-test.md"
}
