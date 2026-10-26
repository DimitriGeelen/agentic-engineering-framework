#!/usr/bin/env bats
# T-4777 (peer 832, their T-1313): closing a task in a project dir that has no
# .git of its own but sits inside another repo staged the task and episodic in
# the ENCLOSING repo. `git -C "$PROJECT_ROOT"` walks upward, so every git write
# in the archive path (git mv, the T-2864 reconcile `add -A`, the T-4094
# `add`) landed in the outer index. 832's sandboxes under .context/st/ put 138
# synthetic files into 11 of their pathspec-free commits.
#
# Pinned here: with PROJECT_ROOT nested in an outer repo, the close still moves
# the file and the outer index stays empty; in a project that IS its own repo
# the close stages exactly as before (control).

load ../test_helper
load ../git_fence

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    OUTER="$TEST_TEMP_DIR/outer"
    export PROJECT_ROOT="$OUTER/sandbox"
    guard_project_root
    mkdir -p "$PROJECT_ROOT/.tasks/active" "$PROJECT_ROOT/.tasks/completed" \
             "$PROJECT_ROOT/.context/working" "$PROJECT_ROOT/.context/episodic"
    : > "$PROJECT_ROOT/.framework.yaml"
    git -C "$OUTER" init -q
    git -C "$OUTER" config user.email "test@test"
    git -C "$OUTER" config user.name "test"
    : > "$OUTER/README"
    git -C "$OUTER" add README
    git -C "$OUTER" commit -qm "init"
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
# verification: none — fixture: this test exercises the close staging scope (T-4024 declaration)
EOF
}

_close() {
    run env PROJECT_ROOT="$PROJECT_ROOT" FRAMEWORK_ROOT="$FRAMEWORK_ROOT" \
        bash "$FRAMEWORK_ROOT/agents/task-create/update-task.sh" "$1" \
        --status work-completed --skip-render-review "test fixture" 2>&1
}

@test "T-4777: fixture — the sandbox resolves to the enclosing repo (the 832 shape)" {
    run git -C "$PROJECT_ROOT" rev-parse --show-toplevel
    [ "$status" -eq 0 ]
    [ "$(realpath "$output")" = "$(realpath "$OUTER")" ]
}

@test "T-4777: untracked task closed in a nested sandbox stages nothing in the enclosing repo" {
    _mk_task "T-9770"
    _close "T-9770"
    [ -f "$PROJECT_ROOT/.tasks/completed/T-9770-test.md" ]
    [ ! -e "$PROJECT_ROOT/.tasks/active/T-9770-test.md" ]
    run git -C "$OUTER" diff --cached --name-only
    [ -z "$output" ]
}

@test "T-4777: task tracked by the enclosing repo is moved on disk, not git-mv'd there" {
    _mk_task "T-9771"
    git -C "$OUTER" add sandbox/.tasks/active/T-9771-test.md
    git -C "$OUTER" commit -qm "832 committed the sandbox once"
    _close "T-9771"
    [ -f "$PROJECT_ROOT/.tasks/completed/T-9771-test.md" ]
    [ ! -e "$PROJECT_ROOT/.tasks/active/T-9771-test.md" ]
    run git -C "$OUTER" diff --cached --name-only
    [ -z "$output" ]
}

@test "T-4777: control — a project that is its own repo still stages the close" {
    git -C "$PROJECT_ROOT" init -q
    git -C "$PROJECT_ROOT" config user.email "test@test"
    git -C "$PROJECT_ROOT" config user.name "test"
    _mk_task "T-9772"
    git -C "$PROJECT_ROOT" add .tasks/active/T-9772-test.md
    git -C "$PROJECT_ROOT" commit -qm "add T-9772"
    _close "T-9772"
    git -C "$PROJECT_ROOT" ls-files --error-unmatch -- .tasks/completed/T-9772-test.md
    git -C "$PROJECT_ROOT" ls-files --error-unmatch -- .context/episodic/T-9772.yaml
    ! git -C "$PROJECT_ROOT" ls-files --error-unmatch -- .tasks/active/T-9772-test.md 2>/dev/null || false
    run git -C "$OUTER" diff --cached --name-only
    [ -z "$output" ]
}
