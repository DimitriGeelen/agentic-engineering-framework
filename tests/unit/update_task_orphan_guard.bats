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

# --- T-2864: the disk-vs-index population gap -------------------------------
#
# The archive move prefers `git mv` and falls back to a plain `mv`. That
# fallback removes the source from DISK but leaves it tracked in the INDEX.
# The T-1863 post-move guard tests `[ -e "$source" ]` — disk — so it passes,
# while dup-task-scan.sh reads `git ls-files --cached` — index — and refuses
# the commit. Two populations; the guard watched the one where the violation
# cannot appear.
#
# `_t2864_reconcile_index` is extracted from the shipped update-task.sh rather
# than reimplemented here, so the test fails if that function is edited away.

_load_reconcile_fn() {
    local src="$FRAMEWORK_ROOT/agents/task-create/update-task.sh"
    [ -f "$src" ] || return 1
    local fn
    fn=$(awk '/^_t2864_reconcile_index\(\) \{/{f=1} f{print} f&&/^\}/{exit}' "$src")
    [ -n "$fn" ] || return 1
    eval "$fn"
}

# Reproduce the fallback state: source gone from disk, still in the index,
# destination present and staged.
_mk_fallback_orphan() {
    local id="$1" base="$2"
    _mk_task ".tasks/active/$base" started-work "$id"
    git -C "$PROJECT_ROOT" add .tasks/active/"$base"
    git -C "$PROJECT_ROOT" commit -qm "seed $id"
    mv "$PROJECT_ROOT/.tasks/active/$base" "$PROJECT_ROOT/.tasks/completed/$base"
    git -C "$PROJECT_ROOT" add .tasks/completed/"$base"
}

@test "T-2864: negative control — the mv fallback really does create a staged duplicate" {
    _mk_fallback_orphan T-9006 "T-9006-fallback.md"
    # Disk is clean: the T-1863 guard's predicate would pass here.
    [ ! -e "$PROJECT_ROOT/.tasks/active/T-9006-fallback.md" ]
    # Index is not: this is the state that refuses the commit.
    run "$SCANNER" scan-staged
    [ "$status" -eq 1 ]
    [[ "$output" == *"T-9006"* ]]
}

@test "T-2864: reconcile stages both sides so the dup scan passes" {
    _mk_fallback_orphan T-9007 "T-9007-fallback.md"
    run "$SCANNER" scan-staged
    [ "$status" -eq 1 ]   # precondition: dirty before

    _load_reconcile_fn
    _t2864_reconcile_index \
        "$PROJECT_ROOT/.tasks/active/T-9007-fallback.md" \
        "$PROJECT_ROOT/.tasks/completed/T-9007-fallback.md"

    run "$SCANNER" scan-staged
    [ "$status" -eq 0 ]
    # The deletion is staged, not merely absent from disk.
    run git -C "$PROJECT_ROOT" diff --cached --name-status
    [[ "$output" == *"T-9007-fallback.md"* ]]
}

@test "T-2864: reconcile is a no-op when git mv already staged the rename" {
    _mk_task ".tasks/active/T-9008-clean.md" started-work T-9008
    git -C "$PROJECT_ROOT" add .tasks/active/T-9008-clean.md
    git -C "$PROJECT_ROOT" commit -qm "seed T-9008"
    git -C "$PROJECT_ROOT" mv .tasks/active/T-9008-clean.md .tasks/completed/T-9008-clean.md

    run "$SCANNER" scan-staged
    [ "$status" -eq 0 ]   # already clean

    _load_reconcile_fn
    run _t2864_reconcile_index \
        "$PROJECT_ROOT/.tasks/active/T-9008-clean.md" \
        "$PROJECT_ROOT/.tasks/completed/T-9008-clean.md"
    [ "$status" -eq 0 ]

    run "$SCANNER" scan-staged
    [ "$status" -eq 0 ]
}

@test "T-2864: reconcile survives a non-git PROJECT_ROOT without erroring" {
    local nogit
    nogit="$(mktemp -d)"
    _load_reconcile_fn
    PROJECT_ROOT="$nogit" run _t2864_reconcile_index "$nogit/a.md" "$nogit/b.md"
    [ "$status" -eq 0 ]
    rm -rf "$nogit"
}
