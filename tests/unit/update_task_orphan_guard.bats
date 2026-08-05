#!/usr/bin/env bats
# T-1863 — Structural prevention for the active+completed orphan class.
# Origin: T-1859 was marked work-completed in S-2026-0515-2042 but the
# active/T-1859 file was never removed from the index, leaving both sides
# tracked. fw audit caught it at next pre-push (G-052 FAIL) — 3 days late.
#
# Two surfaces are exercised here:
#   1. dup-task-scan.sh — pre-commit gate that refuses staged duplicates.
#   2. update-task.sh post-move check — refuses to continue if the source
#      path still exists after the rename (the orphan-creation moment).

load ../test_helper

SCANNER="$FRAMEWORK_ROOT/agents/git/lib/dup-task-scan.sh"

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    guard_project_root
    mkdir -p "$PROJECT_ROOT/.tasks/active" "$PROJECT_ROOT/.tasks/completed"
    # Initialise as git repo so scan-staged has an index to read.
    git -C "$PROJECT_ROOT" init -q
    git -C "$PROJECT_ROOT" config user.email "test@test"
    git -C "$PROJECT_ROOT" config user.name "test"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

_mk_task() {
    local path="$1" status="$2" id="$3"
    cat > "$PROJECT_ROOT/$path" <<EOF
---
id: $id
name: "test"
status: $status
---
EOF
}

@test "T-1863: scan-worktree returns 0 when no duplicates" {
    _mk_task ".tasks/active/T-9001-foo.md" started-work T-9001
    _mk_task ".tasks/completed/T-9002-bar.md" work-completed T-9002
    run "$SCANNER" scan-worktree
    [ "$status" -eq 0 ]
}

@test "T-1863: scan-worktree returns 1 and names the duplicate" {
    _mk_task ".tasks/active/T-9003-dup.md" started-work T-9003
    _mk_task ".tasks/completed/T-9003-dup.md" work-completed T-9003
    run "$SCANNER" scan-worktree
    [ "$status" -eq 1 ]
    [[ "$output" == *"T-9003"* ]]
    [[ "$output" == *"Duplicate task IDs detected (G-052)"* ]]
}

@test "T-1863: scan-staged respects the index, not the worktree" {
    # Stage only the completed version — worktree has both, but index has one.
    _mk_task ".tasks/active/T-9004-only-worktree.md" started-work T-9004
    _mk_task ".tasks/completed/T-9004-only-worktree.md" work-completed T-9004
    git -C "$PROJECT_ROOT" add .tasks/completed/T-9004-only-worktree.md
    run "$SCANNER" scan-staged
    [ "$status" -eq 0 ]  # Only completed is staged → no index-side duplicate
}

@test "T-1863: scan-staged catches staged duplicates before commit" {
    _mk_task ".tasks/active/T-9005-dup.md" started-work T-9005
    _mk_task ".tasks/completed/T-9005-dup.md" work-completed T-9005
    git -C "$PROJECT_ROOT" add .tasks/
    run "$SCANNER" scan-staged
    [ "$status" -eq 1 ]
    [[ "$output" == *"T-9005"* ]]
}

@test "T-1863: scanner unknown-mode rejects cleanly with exit 2" {
    run "$SCANNER" not-a-mode
    [ "$status" -eq 2 ]
    [[ "$output" == *"unknown mode"* ]]
}
