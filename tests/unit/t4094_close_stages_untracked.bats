#!/usr/bin/env bats
# T-4094 (peer dimitri-mint-dev G-012): a task created and closed between two
# commits was never committed. The archive move uses `git mv` only for a TRACKED
# file; an untracked one falls back to plain `mv` and nothing staged the
# completed/ file or its episodic, so both stayed untracked for weeks.
#
# Postcondition pinned here: after --status work-completed moves a task into
# completed/, that file and its episodic are in the index, whatever their
# tracking state before the close.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    guard_project_root
    mkdir -p "$PROJECT_ROOT/.tasks/active" "$PROJECT_ROOT/.tasks/completed" \
             "$PROJECT_ROOT/.context/working" "$PROJECT_ROOT/.context/episodic"
    git -C "$PROJECT_ROOT" init -q
    git -C "$PROJECT_ROOT" config user.email "test@test"
    git -C "$PROJECT_ROOT" config user.name "test"
    # An initial commit so HEAD exists (the dimitri-mint-dev shape: a live repo).
    : > "$PROJECT_ROOT/README"
    git -C "$PROJECT_ROOT" add README
    git -C "$PROJECT_ROOT" commit -qm "init"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

_mk_task() {
    local id="$1"
    cat > "$PROJECT_ROOT/.tasks/active/${id}-test.md" <<EOF
---
id: $id
name: "test task"
status: started-work
workflow_type: build
owner: claude-code
horizon: now
tags: []
created: 2026-06-01T00:00:00Z
last_update: 2026-06-01T00:00:00Z
---

# $id: test task

## Acceptance Criteria

### Agent
- [x] Done

## Verification
# verification: none — fixture: this test exercises the close staging postcondition (T-4024 declaration)
EOF
}

_close() {
    run env PROJECT_ROOT="$PROJECT_ROOT" FRAMEWORK_ROOT="$FRAMEWORK_ROOT" \
        bash "$FRAMEWORK_ROOT/agents/task-create/update-task.sh" "$1" \
        --status work-completed --skip-render-review "test fixture" 2>&1
}

_staged() {
    git -C "$PROJECT_ROOT" ls-files --error-unmatch -- "$1" >/dev/null 2>&1
}

@test "T-4094: never-committed task is staged in completed/ after close" {
    _mk_task "T-9400"
    _close "T-9400"
    [ -f "$PROJECT_ROOT/.tasks/completed/T-9400-test.md" ]
    _staged ".tasks/completed/T-9400-test.md"
    # Nothing untracked left under .tasks/ for this task
    run git -C "$PROJECT_ROOT" ls-files --others --exclude-standard -- .tasks/
    [ -z "$output" ]
}

@test "T-4094: episodic generated at close is staged" {
    _mk_task "T-9401"
    _close "T-9401"
    [ -f "$PROJECT_ROOT/.context/episodic/T-9401.yaml" ]
    _staged ".context/episodic/T-9401.yaml"
}

@test "T-4094: hint names a pathspec commit with the completed file, not the never-tracked active path" {
    _mk_task "T-9402"
    _close "T-9402"
    [[ "$output" == *"git commit -m 'T-9402: close"* ]]
    [[ "$output" == *"-- .tasks/completed/T-9402-test.md .context/episodic/T-9402.yaml"* ]]
    [[ "$output" != *"-- .tasks/active/T-9402"* ]]
    [[ "$output" != *"rename staged in index"* ]]
}

@test "T-4094: control — tracked task closes with rename staged and the old path in the hint" {
    _mk_task "T-9403"
    git -C "$PROJECT_ROOT" add .tasks/active/T-9403-test.md
    git -C "$PROJECT_ROOT" commit -qm "add T-9403"
    _close "T-9403"
    _staged ".tasks/completed/T-9403-test.md"
    ! _staged ".tasks/active/T-9403-test.md" || false
    _staged ".context/episodic/T-9403.yaml"
    [[ "$output" == *".tasks/active/T-9403-test.md"* ]]
    # The suggested commit actually works as printed (pathspec matches)
    git -C "$PROJECT_ROOT" commit -qm "T-9403: close" -- \
        .tasks/completed/T-9403-test.md .tasks/active/T-9403-test.md .context/episodic/T-9403.yaml
    run git -C "$PROJECT_ROOT" status --porcelain -- .tasks/ .context/episodic/
    [ -z "$output" ]
}
