#!/usr/bin/env bats
# T-1594: Mirror cascade auto-recovery (T-1591 Prevention #3)
#
# Build a self-contained git topology with three local bare repos acting as
# `origin` and two `mirror_*` remotes, then exercise mirror_sync against the
# four cases the auto-recovery contract must distinguish:
#   in-sync, ancestor (fast-forward), diverged, unreachable.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export NO_COLOR=1

    # Local working repo
    PROJECT_ROOT="$TEST_TEMP_DIR/work"
    guard_project_root
    mkdir -p "$PROJECT_ROOT"
    cd "$PROJECT_ROOT"
    git init -q -b master
    git config user.email "t@t"
    git config user.name "t"
    echo c1 > a && git add a && git commit -qm c1
    echo c2 >> a && git add a && git commit -qm c2

    # Bare repos used as remotes
    git init -q --bare "$TEST_TEMP_DIR/origin.git"
    git init -q --bare "$TEST_TEMP_DIR/mirror_synced.git"
    git init -q --bare "$TEST_TEMP_DIR/mirror_behind.git"
    git init -q --bare "$TEST_TEMP_DIR/mirror_diverged.git"

    git remote add origin "$TEST_TEMP_DIR/origin.git"
    git remote add mirror_synced "$TEST_TEMP_DIR/mirror_synced.git"
    git remote add mirror_behind "$TEST_TEMP_DIR/mirror_behind.git"
    git remote add mirror_diverged "$TEST_TEMP_DIR/mirror_diverged.git"
    git remote add mirror_unreachable "$TEST_TEMP_DIR/does-not-exist.git"

    # Push to populate the bare repos (each into the state we want)
    # mirror_behind: stops at c2 (ancestor of origin's HEAD after we add c3)
    git push -q origin master
    git push -q mirror_synced master
    git push -q mirror_behind master

    # Diverged: branch off and push a sibling commit only to mirror_diverged
    git checkout -q -b sidebranch
    echo cD >> a && git add a && git commit -qm cD
    git push -q mirror_diverged sidebranch:master
    git checkout -q master

    # Advance origin and mirror_synced to c3 so mirror_synced=in-sync, mirror_behind<origin
    echo c3 >> a && git add a && git commit -qm c3
    git push -q origin master
    git push -q mirror_synced master

    export PROJECT_ROOT
    source "$FRAMEWORK_ROOT/lib/mirror.sh"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

@test "mirror_sync: in-sync remote logged + reported, no push" {
    # Isolate to one remote
    git remote remove mirror_behind
    git remote remove mirror_diverged
    git remote remove mirror_unreachable

    run mirror_sync
    [ "$status" -eq 0 ]
    [[ "$output" == *"mirror_synced: in sync"* ]]
    grep -q "in-sync" "$PROJECT_ROOT/.context/working/.mirror-sync.log"
}

@test "mirror_sync: behind remote is fast-forwarded up to origin" {
    git remote remove mirror_synced
    git remote remove mirror_diverged
    git remote remove mirror_unreachable

    local before
    before=$(git ls-remote mirror_behind refs/heads/master | awk '{print $1}')
    local origin_head
    origin_head=$(git ls-remote origin HEAD | awk '{print $1}')
    [ "$before" != "$origin_head" ]

    run mirror_sync
    [ "$status" -eq 0 ]
    [[ "$output" == *"mirror_behind: synced"* ]]

    local after
    after=$(git ls-remote mirror_behind refs/heads/master | awk '{print $1}')
    [ "$after" = "$origin_head" ]
    grep -q "synced" "$PROJECT_ROOT/.context/working/.mirror-sync.log"
}

@test "mirror_sync: diverged remote refused, never auto-pushed" {
    git remote remove mirror_synced
    git remote remove mirror_behind
    git remote remove mirror_unreachable

    local before
    before=$(git ls-remote mirror_diverged refs/heads/master | awk '{print $1}')

    run mirror_sync
    [ "$status" -eq 1 ]
    [[ "$output" == *"DIVERGED"* ]]

    local after
    after=$(git ls-remote mirror_diverged refs/heads/master | awk '{print $1}')
    [ "$after" = "$before" ]
    grep -q "diverged" "$PROJECT_ROOT/.context/working/.mirror-sync.log"
}

@test "mirror_sync: unreachable remote logged, exits non-zero, others unaffected" {
    git remote remove mirror_behind
    git remote remove mirror_diverged

    run mirror_sync
    [ "$status" -eq 1 ]
    [[ "$output" == *"unreachable"* ]] || [[ "$output" == *"mirror_unreachable"* ]]
    [[ "$output" == *"mirror_synced: in sync"* ]]
    grep -q "unreachable" "$PROJECT_ROOT/.context/working/.mirror-sync.log"
}

@test "mirror_sync --dry-run: behind remote not actually pushed" {
    git remote remove mirror_synced
    git remote remove mirror_diverged
    git remote remove mirror_unreachable

    local before
    before=$(git ls-remote mirror_behind refs/heads/master | awk '{print $1}')

    run mirror_sync --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"would push"* ]]

    local after
    after=$(git ls-remote mirror_behind refs/heads/master | awk '{print $1}')
    [ "$after" = "$before" ]
}

@test "mirror_sync: no mirror remotes is OK (only origin configured)" {
    git remote remove mirror_synced
    git remote remove mirror_behind
    git remote remove mirror_diverged
    git remote remove mirror_unreachable

    run mirror_sync
    [ "$status" -eq 0 ]
    [[ "$output" == *"No mirror remotes"* ]]
}

@test "mirror_status: prints parity per remote" {
    git remote remove mirror_unreachable

    run mirror_status
    [ "$status" -eq 0 ]
    [[ "$output" == *"origin HEAD:"* ]]
    [[ "$output" == *"mirror_synced: in sync"* ]]
    [[ "$output" == *"mirror_behind: behind by"* ]]
    [[ "$output" == *"mirror_diverged: DIVERGED"* ]]
}

@test "mirror_main: unknown subcommand exits 2" {
    run mirror_main bogus
    [ "$status" -eq 2 ]
    [[ "$output" == *"Unknown mirror subcommand"* ]]
}
