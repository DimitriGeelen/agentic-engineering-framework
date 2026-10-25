#!/usr/bin/env bats
# T-4698: the T-3694 self-deferral gate must not look up another project's task
# ids locally. ring20 T-2494 was refused because its AC named "AEF's T-4690/T-4694"
# next to "follow-up message"; the gate searched ring20's .tasks/ for them.
#
# A foreign qualifier (lib/design_register.py FOREIGN_QUALIFIERS) is one of:
#   AEF T-X / TermLink T-X / framework T-X / upstream T-X  (optionally 's)
#   <project>#T-X
# and a /-chained id after a qualified one ("AEF's T-4690/T-4694") inherits it.
# A bare id is still a local deferral target and is still refused when missing.
#
# Every test runs in a throwaway PROJECT_ROOT (a consumer shape: no FRAMEWORK.md).

load ../test_helper

UPDATE_TASK="$FRAMEWORK_ROOT/agents/task-create/update-task.sh"
MOD="$FRAMEWORK_ROOT/lib/design_register.py"

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    guard_project_root
    unset CLAUDECODE
    mkdir -p "$PROJECT_ROOT/.tasks/active" "$PROJECT_ROOT/.tasks/completed" \
             "$PROJECT_ROOT/.tasks/templates" "$PROJECT_ROOT/.context/working" \
             "$PROJECT_ROOT/.context/episodic"
    echo "framework_root: $FRAMEWORK_ROOT" > "$PROJECT_ROOT/.framework.yaml"
    echo "# template" > "$PROJECT_ROOT/.tasks/templates/default.md"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# _task ID BODY — minimal closeable build task
_task() {
    cat > "$PROJECT_ROOT/.tasks/active/$1-fixture.md" <<EOF
---
id: $1
name: "fixture $1"
description: "T-4698 fixture"
status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
created: 2026-10-01T00:00:00Z
last_update: 2026-10-01T00:00:00Z
date_finished: null
---

# $1

## Acceptance Criteria

### Agent
$2

## Verification

test -d "\$PROJECT_ROOT/.tasks/active"

## Recommendation

**Recommendation:** GO

**Rationale:** fixture.
EOF
}

_check() {
    run python3 "$MOD" self-deferral "$PROJECT_ROOT/.tasks/active/$1-fixture.md" --root "$PROJECT_ROOT"
}

@test "ring20 shape: AEF's T-4690/T-4694 next to 'follow-up message' closes" {
    _task T-2494 "- [x] Reported to AEF's T-4690/T-4694 owner in a follow-up message"
    run "$UPDATE_TASK" T-2494 --status work-completed
    echo "$output"
    [ "$status" -eq 0 ]
    [ -f "$PROJECT_ROOT/.tasks/completed/T-2494-fixture.md" ]
}

@test "qualified-but-local-looking id is not looked up locally" {
    _task T-0100 "- [x] Remaining work deferred to AEF T-0001"
    _check T-0100
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "every qualifier form passes: TermLink, framework, upstream, project#" {
    _task T-0100 "- [x] Follow-up filed as TermLink T-0002, framework T-0003, upstream T-0004 and ring20#T-0005"
    _check T-0100
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "unqualified missing id is still refused, with the qualify hint" {
    _task T-0100 "- [x] Remaining work deferred to T-0404"
    run "$UPDATE_TASK" T-0100 --status work-completed
    [ "$status" -ne 0 ]
    [[ "$output" == *"T-0404 does not exist"* ]]
    [[ "$output" == *"another project's task"* ]]
    [[ "$output" == *"AEF T-0404"* ]]
    [ -f "$PROJECT_ROOT/.tasks/active/T-0100-fixture.md" ]
}

@test "a bare id beside a qualified one is still a local target" {
    _task T-0100 "- [x] Follow-up: AEF T-0001 upstream, local part deferred to T-0404"
    _check T-0100
    [ "$status" -eq 1 ]
    [[ "$output" == *"T-0404 does not exist"* ]]
    [[ "$output" != *"T-0001 does not exist"* ]]
}

@test "inside the framework repo an AEF-qualified id is local again" {
    touch "$PROJECT_ROOT/FRAMEWORK.md"
    mkdir -p "$PROJECT_ROOT/bin" && touch "$PROJECT_ROOT/bin/fw"
    _task T-0100 "- [x] Remaining work deferred to AEF T-0001"
    _check T-0100
    [ "$status" -eq 1 ]
    [[ "$output" == *"T-0001 does not exist"* ]]
}
