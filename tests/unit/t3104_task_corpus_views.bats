#!/usr/bin/env bats
# fw_task_view_dirs — the shared task-corpus view set (T-3104).
#
# A git worktree checks out its own snapshot of .tasks/, so "the corpus" is the
# UNION of every worktree's .tasks/ plus the local view. Scanning one view
# computes a stale max and mints duplicate IDs (L-506 leg 2, origin T-100202:
# T-2505/T-2506/T-2428 each minted twice on 2026-07-01 across two worktrees).
#
# These tests use REAL fixture git repos with REAL `git worktree add` — the
# failure class lives in git's view semantics, so a mocked `git worktree list`
# would only prove the mock works.

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

setup() {
    export TEST_DIR="${BATS_TMPDIR:-/tmp}/fw_t3104_$$_${BATS_TEST_NUMBER}"
    mkdir -p "$TEST_DIR"
    export STDERR_FILE="$TEST_DIR/stderr.txt"
}

teardown() {
    # Worktree admin files live in the fixture repo itself; plain rm suffices.
    rm -rf "$TEST_DIR" 2>/dev/null || true
}

# Call fw_task_view_dirs in a clean subshell with an explicit TASKS_DIR.
# Hermeticity (T-2289 invariant): _FW_PATHS_DERIVED_BY must be unset so the
# explicit TASKS_DIR survives paths.sh's re-derivation guard.
views() {
    local tasks_dir="$1"
    env -u _FW_PATHS_DERIVED_BY -u _FW_PATHS_LOADED -u FRAMEWORK_ROOT \
        PROJECT_ROOT="$(dirname "$tasks_dir")" TASKS_DIR="$tasks_dir" \
        bash -c 'source "$0/lib/paths.sh"; fw_task_view_dirs' \
        "$FRAMEWORK_ROOT" 2>"$STDERR_FILE"
}

# Fixture: a git repo at $1 with a committed .tasks/ tree.
make_repo() {
    local root="$1"
    mkdir -p "$root/.tasks/active" "$root/.tasks/completed"
    git -C "$root" init -q
    git -C "$root" config user.email t3104@test.local
    git -C "$root" config user.name t3104
    : > "$root/.tasks/active/.keep"
    git -C "$root" add -A
    git -C "$root" commit -qm "T-3104: fixture"
}

@test "main-only repo returns exactly the one .tasks view" {
    make_repo "$TEST_DIR/main"
    run views "$TEST_DIR/main/.tasks"
    [ "$status" -eq 0 ]
    [ "${#lines[@]}" -eq 1 ]
    [ "${lines[0]}" = "$TEST_DIR/main/.tasks" ]
}

@test "repo with 2 worktrees returns all three views" {
    make_repo "$TEST_DIR/main"
    git -C "$TEST_DIR/main" worktree add -q -b wt1 "$TEST_DIR/wt1"
    git -C "$TEST_DIR/main" worktree add -q -b wt2 "$TEST_DIR/wt2"

    run views "$TEST_DIR/main/.tasks"
    [ "$status" -eq 0 ]
    [ "${#lines[@]}" -eq 3 ]
    printf '%s\n' "${lines[@]}" | grep -qx "$TEST_DIR/main/.tasks"
    printf '%s\n' "${lines[@]}" | grep -qx "$TEST_DIR/wt1/.tasks"
    printf '%s\n' "${lines[@]}" | grep -qx "$TEST_DIR/wt2/.tasks"
}

@test "non-git directory falls back to TASKS_DIR alone, no crash, no stderr" {
    mkdir -p "$TEST_DIR/plain/.tasks/active"
    run views "$TEST_DIR/plain/.tasks"
    [ "$status" -eq 0 ]
    [ "${#lines[@]}" -eq 1 ]
    [ "${lines[0]}" = "$TEST_DIR/plain/.tasks" ]
    # No stderr spew: git must never be heard complaining about a non-repo.
    [ ! -s "$STDERR_FILE" ]
}

@test "worktree with no .tasks dir is skipped, other views still returned" {
    make_repo "$TEST_DIR/main"
    git -C "$TEST_DIR/main" worktree add -q -b wt1 "$TEST_DIR/wt1"
    git -C "$TEST_DIR/main" worktree add -q -b wt2 "$TEST_DIR/wt2"
    rm -rf "$TEST_DIR/wt1/.tasks"

    run views "$TEST_DIR/main/.tasks"
    [ "$status" -eq 0 ]
    [ "${#lines[@]}" -eq 2 ]
    printf '%s\n' "${lines[@]}" | grep -qx "$TEST_DIR/main/.tasks"
    printf '%s\n' "${lines[@]}" | grep -qx "$TEST_DIR/wt2/.tasks"
    ! printf '%s\n' "${lines[@]}" | grep -qx "$TEST_DIR/wt1/.tasks"
}

# Scope item 3 decision: DE-DUPLICATE, first-occurrence order preserved.
# Pre-lift the local view was emitted twice (once from `git worktree list`,
# once from the unconditional trailing append) and the sole consumer piped
# through `sort -u`. De-duplicating changes the multiset, never the SET.
@test "output is de-duplicated: the local view appears exactly once" {
    make_repo "$TEST_DIR/main"
    git -C "$TEST_DIR/main" worktree add -q -b wt1 "$TEST_DIR/wt1"

    run views "$TEST_DIR/main/.tasks"
    [ "$status" -eq 0 ]
    local count
    count=$(printf '%s\n' "${lines[@]}" | grep -cx "$TEST_DIR/main/.tasks")
    [ "$count" -eq 1 ]
    # No duplicates anywhere: total lines == unique lines.
    [ "${#lines[@]}" -eq "$(printf '%s\n' "${lines[@]}" | sort -u | wc -l)" ]
}

@test "worktree with an EMPTY .tasks dir is still returned (a view, just empty)" {
    make_repo "$TEST_DIR/main"
    git -C "$TEST_DIR/main" worktree add -q -b wt1 "$TEST_DIR/wt1"
    rm -rf "$TEST_DIR/wt1/.tasks"
    mkdir -p "$TEST_DIR/wt1/.tasks"   # exists, contains nothing

    run views "$TEST_DIR/main/.tasks"
    [ "$status" -eq 0 ]
    [ "${#lines[@]}" -eq 2 ]
    printf '%s\n' "${lines[@]}" | grep -qx "$TEST_DIR/wt1/.tasks"
}

@test "local view is emitted even when git's listing does not supply it" {
    # Main checkout inside a git repo but with NO .tasks/ on disk: the -d guard
    # skips it in the loop, so only the unconditional trailing append keeps the
    # local view in the corpus. This is the load-bearing guarantee.
    make_repo "$TEST_DIR/main"
    git -C "$TEST_DIR/main" worktree add -q -b wt1 "$TEST_DIR/wt1"
    rm -rf "$TEST_DIR/main/.tasks"

    run views "$TEST_DIR/main/.tasks"
    [ "$status" -eq 0 ]
    [ "${#lines[@]}" -eq 2 ]
    printf '%s\n' "${lines[@]}" | grep -qx "$TEST_DIR/main/.tasks"
    printf '%s\n' "${lines[@]}" | grep -qx "$TEST_DIR/wt1/.tasks"
}
