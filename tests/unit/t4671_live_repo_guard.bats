#!/usr/bin/env bats
# T-4671 — tests/live_repo_guard.bash refuses a test that changed a repo.
#
# The guard is pointed at a scratch repo here, never the framework checkout: the
# three cases reproduce what the leak looked like (a fixture staged into the index
# by the T-4094 close postcondition, then rm'd from disk) and the no-change control.

load ../test_helper
load ../live_repo_guard

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    REPO="$TEST_TEMP_DIR/repo"
    mkdir -p "$REPO"
    git -C "$REPO" init -q
    git -C "$REPO" config user.email t@t
    git -C "$REPO" config user.name t
    echo base > "$REPO/base.txt"
    git -C "$REPO" add base.txt
    git -C "$REPO" commit -qm base --no-verify
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

@test "guard passes when the repo is untouched" {
    live_repo_guard_begin "$REPO"
    run live_repo_guard_end
    [ "$status" -eq 0 ]
}

@test "guard fails when a file was staged and then removed from disk (the a2e53a22a shape)" {
    live_repo_guard_begin "$REPO"
    echo leak > "$REPO/T-9902-redteam.md"
    git -C "$REPO" add T-9902-redteam.md
    rm "$REPO/T-9902-redteam.md"
    run live_repo_guard_end
    [ "$status" -eq 1 ]
    [[ "$output" == *"LIVE REPO GUARD (T-4671)"* ]]
}

@test "scoped guard ignores changes outside its pathspec and catches one inside it" {
    live_repo_guard_begin "$REPO" ':(glob)**/T-99[0-9][0-9]-*'
    echo other-worker > "$REPO/base.txt"
    git -C "$REPO" add base.txt
    run live_repo_guard_end
    [ "$status" -eq 0 ]
    echo leak > "$REPO/T-9905-redteam.md"
    git -C "$REPO" add T-9905-redteam.md
    run live_repo_guard_end
    [ "$status" -eq 1 ]
    [[ "$output" == *"T-9905-redteam.md"* ]]
}

@test "guard fails on a working-tree change with an unchanged index" {
    live_repo_guard_begin "$REPO"
    echo changed > "$REPO/base.txt"
    run live_repo_guard_end
    [ "$status" -eq 1 ]
    [[ "$output" == *"base.txt"* ]]
}
