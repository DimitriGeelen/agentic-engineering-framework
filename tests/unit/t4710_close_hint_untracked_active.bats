#!/usr/bin/env bats
# T-4710 (1023, sidecar 274b30db): the close hint
#   next: git commit -m '<id>: close ...' -- <paths> && git push
# named .tasks/active/<file> even when that file was never committed (task
# created and closed between two commits), so the printed command failed with
# "pathspec did not match". The active path belongs in the hint only when git
# has it at HEAD (then it is the rename source and must be named, or HEAD
# keeps it). Either way the printed line must run verbatim.
#
# End to end: a real close through update-task.sh in a throwaway project, the
# printed line extracted verbatim and run.

load ../test_helper

setup() {
    unset FW_SESSION_SCOPED_FOCUS FW_FOCUS_SESSION_KEY FW_QUIET_NEXT_HINT
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    export PROJECT_ROOT="$TEST_TEMP_DIR/proj"
    guard_project_root
    mkdir -p "$PROJECT_ROOT/.tasks/active" "$PROJECT_ROOT/.tasks/completed" \
             "$PROJECT_ROOT/.context/working" "$PROJECT_ROOT/.context/episodic"
    git init -q --bare "$TEST_TEMP_DIR/remote.git"
    git -C "$PROJECT_ROOT" init -q -b main
    git -C "$PROJECT_ROOT" config user.email "test@test"
    git -C "$PROJECT_ROOT" config user.name "test"
    git -C "$PROJECT_ROOT" remote add origin "$TEST_TEMP_DIR/remote.git"
    : > "$PROJECT_ROOT/README"
    git -C "$PROJECT_ROOT" add README
    git -C "$PROJECT_ROOT" commit -qm "T-9471: init"
    git -C "$PROJECT_ROOT" push -q -u origin main 2>/dev/null
    TASK_REL=".tasks/active/T-9471-fixture.md"
    cat > "$PROJECT_ROOT/$TASK_REL" <<'EOF'
---
id: T-9471
name: "fixture"
status: started-work
workflow_type: build
owner: claude-code
horizon: now
tags: []
created: 2026-06-01T00:00:00Z
last_update: 2026-06-01T00:00:00Z
---

# T-9471: fixture

## Acceptance Criteria

### Agent
- [x] Done

## Verification
# verification: none — fixture for the T-4710 close-hint test
EOF
    printf 'current_task: T-9471\n' > "$PROJECT_ROOT/.context/working/focus.yaml"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

_close() {
    env PROJECT_ROOT="$PROJECT_ROOT" FRAMEWORK_ROOT="$FRAMEWORK_ROOT" \
        bash "$FRAMEWORK_ROOT/agents/task-create/update-task.sh" T-9471 \
        --status work-completed --skip-render-review "test fixture" 2>&1
}

_hint() {
    printf '%s\n' "$1" | sed -n 's/^.*next: \(git commit .*\)$/\1/p' | head -1
}

_assert_landed() {
    local tree
    tree=$(git -C "$PROJECT_ROOT" ls-tree -r --name-only HEAD)
    [[ "$tree" == *".tasks/completed/T-9471-fixture.md"* ]]
    [[ "$tree" == *".context/episodic/T-9471.yaml"* ]]
    [[ "$tree" != *"$TASK_REL"* ]]
    [ "$(git -C "$PROJECT_ROOT" rev-parse HEAD)" = "$(git -C "$TEST_TEMP_DIR/remote.git" rev-parse main)" ]
}

@test "T-4710: never-committed active file — hint omits the active path and runs verbatim" {
    local out cmd
    out=$(_close)
    cmd=$(_hint "$out")
    echo "hint: $cmd"
    [ -n "$cmd" ]
    [[ "$cmd" == *".tasks/completed/T-9471-fixture.md"* ]]
    [[ "$cmd" != *"$TASK_REL"* ]]
    run bash -c "cd '$PROJECT_ROOT' && $cmd"
    echo "$output"
    [ "$status" -eq 0 ]
    _assert_landed
}

@test "T-4710: active file staged but never committed — hint omits it and runs verbatim" {
    git -C "$PROJECT_ROOT" add "$TASK_REL"
    local out cmd
    out=$(_close)
    cmd=$(_hint "$out")
    echo "hint: $cmd"
    [ -n "$cmd" ]
    [[ "$cmd" != *"$TASK_REL"* ]]
    run bash -c "cd '$PROJECT_ROOT' && $cmd"
    echo "$output"
    [ "$status" -eq 0 ]
    _assert_landed
}

@test "T-4710: committed active file — hint names the rename source and runs verbatim" {
    git -C "$PROJECT_ROOT" add "$TASK_REL"
    git -C "$PROJECT_ROOT" commit -qm "T-9471: capture"
    local out cmd
    out=$(_close)
    cmd=$(_hint "$out")
    echo "hint: $cmd"
    [ -n "$cmd" ]
    [[ "$cmd" == *"$TASK_REL"* ]]
    run bash -c "cd '$PROJECT_ROOT' && $cmd"
    echo "$output"
    [ "$status" -eq 0 ]
    _assert_landed
}

@test "T-4710: project root reached through a symlink — hint still runs verbatim" {
    ln -s "$PROJECT_ROOT" "$TEST_TEMP_DIR/link"
    local real="$PROJECT_ROOT" out cmd
    PROJECT_ROOT="$TEST_TEMP_DIR/link"
    out=$(_close)
    PROJECT_ROOT="$real"
    cmd=$(_hint "$out")
    echo "hint: $cmd"
    [ -n "$cmd" ]
    [[ "$cmd" != *"$TASK_REL"* ]]
    [[ "$cmd" != *"$TEST_TEMP_DIR"* ]]
    run bash -c "cd '$PROJECT_ROOT' && $cmd"
    echo "$output"
    [ "$status" -eq 0 ]
    _assert_landed
}
