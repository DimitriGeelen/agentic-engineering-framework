#!/usr/bin/env bats
# T-5218: fw_id_allocate must work when called "cold" — before keylock.sh is sourced — under
# `set -euo pipefail`. objectives-seed (fw upgrade) calls it that way; T-5217's own tests ran
# the allocator without `set -u` and missed `task: unbound variable` at idalloc.sh's lock check.

load ../git_fence

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
IDALLOC="$FRAMEWORK_ROOT/lib/idalloc.sh"

setup() {
    T="$(mktemp -d "${BATS_RUN_TMPDIR:-/tmp}/t5218.XXXXXX")"
    MAIN="$T/main"
    mkdir -p "$MAIN/.tasks/active" "$MAIN/.tasks/completed"
    : > "$MAIN/.tasks/active/T-004-seed.md"
    git -C "$MAIN" init -q
    git -C "$MAIN" add -A
    git -C "$MAIN" -c user.email=t@t -c user.name=t commit -qm seed
    export PROJECT_ROOT="$MAIN"
    unset FW_ID_CHECK FW_ID_BLOCK_MAX FW_ID_QUARANTINE_GAP _FW_PATHS_DERIVED_BY
}

teardown() {
    rm -rf "$T"
}

@test "cold call under set -euo pipefail allocates (no keylock.sh sourced first)" {
    run env -i PATH="$PATH" HOME="$T" PROJECT_ROOT="$MAIN" TASKS_DIR="$MAIN/.tasks" \
        bash -euo pipefail -c 'source "$0"; fw_id_allocate 1 cold-test' "$IDALLOC"
    [ "$status" -eq 0 ]
    [ "$output" = "T-005" ]
}

@test "cold call in a project that is not a git repository allocates (consumer before git init)" {
    rm -rf "$MAIN/.git"
    run env -i PATH="$PATH" HOME="$T" PROJECT_ROOT="$MAIN" TASKS_DIR="$MAIN/.tasks" \
        bash -euo pipefail -c 'source "$0"; fw_id_allocate 1 cold-test' "$IDALLOC"
    [ "$status" -eq 0 ]
    [ "$output" = "T-005" ]
}

@test "a hold already taken by the caller is reused (create-task path unchanged)" {
    run env -i PATH="$PATH" HOME="$T" PROJECT_ROOT="$MAIN" TASKS_DIR="$MAIN/.tasks" \
        bash -euo pipefail -c '
            source "$0"
            source "$(dirname "$0")/keylock.sh"
            KEYLOCK_DIR="$PROJECT_ROOT/.context/locks"; mkdir -p "$KEYLOCK_DIR"
            keylock_acquire task-id-allocation
            fw_id_allocate 2 held
            keylock_release task-id-allocation' "$IDALLOC"
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "T-005" ]
    [ "${lines[1]}" = "T-006" ]
}
