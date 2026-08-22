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

# T-3088 A5: source-level pin that `fw doctor` wires the stuck-diverged
# check in (per F7/T-2451 — full `fw doctor` is slow/network-coupled, so
# don't run it here; assert the wiring instead, mirroring t2452's pattern).
@test "T-3088: do_doctor calls mirror_stuck_diverged_check, guarded by --quick" {
    run grep -n "mirror_stuck_diverged_check" "$FRAMEWORK_ROOT/bin/fw"
    [ "$status" -eq 0 ]
    run bash -c "grep -A20 'T-3088: mirror sync stuck DIVERGED' '$FRAMEWORK_ROOT/bin/fw' | grep -q 'source.*mirror.sh'"
    [ "$status" -eq 0 ]
    run grep -q 'Mirror sync stuck diverged (.mirror-sync.log)' "$FRAMEWORK_ROOT/bin/fw"
    [ "$status" -eq 0 ]
}

# T-3088: mirror_default_branch previously fell back to the LOCAL checkout's
# current branch when refs/remotes/origin/HEAD was absent, instead of asking
# origin what its default branch actually is. That meant mirror_sync_one
# fetched refs/heads/<local-branch> from the mirror and compared it against
# origin's HEAD SHA (which is origin's default branch, e.g. master) — two
# different branches, silently compared as if they were the same one.

@test "mirror_default_branch: resolves origin's real default branch, not the local current branch" {
    # No refs/remotes/origin/HEAD in these fixtures (confirmed: git remote add
    # + push does not populate it without an explicit fetch/set-head). Put the
    # local checkout on a branch that is NOT origin's default.
    git checkout -q -b totally-unrelated-local-branch

    run mirror_default_branch
    [ "$status" -eq 0 ]
    [ "$output" = "master" ]
}

@test "mirror_sync: compares the SAME branch on origin and mirror regardless of local checkout branch" {
    git remote remove mirror_behind
    git remote remove mirror_diverged
    git remote remove mirror_unreachable

    # mirror_synced's master already matches origin's master (c3, from setup).
    # Push a DIFFERENT commit to mirror_synced under a branch name that
    # matches the local checkout's current branch — this is the value the
    # old fallback would have queried instead of "master".
    git checkout -q -b sidebranch-local
    echo cLocal >> a && git add a && git commit -qm cLocal
    git push -q mirror_synced sidebranch-local:sidebranch-local
    git checkout -q master

    local origin_master mirror_synced_master mirror_synced_side
    origin_master=$(git ls-remote origin refs/heads/master | awk '{print $1}')
    mirror_synced_master=$(git ls-remote mirror_synced refs/heads/master | awk '{print $1}')
    mirror_synced_side=$(git ls-remote mirror_synced refs/heads/sidebranch-local | awk '{print $1}')
    [ "$origin_master" = "$mirror_synced_master" ]
    [ "$origin_master" != "$mirror_synced_side" ]

    # Now run mirror_sync from the "sidebranch-local" checkout — the exact
    # condition live since 2026-08-14. Correct behavior: still compares
    # master vs master (in-sync), never touches sidebranch-local.
    git checkout -q sidebranch-local

    run mirror_sync
    [ "$status" -eq 0 ]
    [[ "$output" == *"mirror_synced: in sync"* ]]

    # The mirror's sidebranch-local ref must be untouched — proof the sync
    # never compared or pushed against the local-branch-named ref.
    local after_side
    after_side=$(git ls-remote mirror_synced refs/heads/sidebranch-local | awk '{print $1}')
    [ "$after_side" = "$mirror_synced_side" ]
}

@test "mirror_stuck_diverged_check: fires when the last N runs are all diverged (T-3088, A5)" {
    local log="$TEST_TEMP_DIR/stuck.log"
    printf '2026-08-14T09:00:00Z\tgithub\tin-sync\txxx\txxx\n' > "$log"
    printf '2026-08-14T09:15:00Z\tgithub\tdiverged\taaa\tbbb\n' >> "$log"
    printf '2026-08-14T09:30:00Z\tgithub\tdiverged\taaa\tccc\n' >> "$log"
    printf '2026-08-14T09:45:00Z\tgithub\tdiverged\taaa\tddd\n' >> "$log"
    printf '2026-08-14T10:00:00Z\tgithub\tdiverged\taaa\teee\n' >> "$log"

    run mirror_stuck_diverged_check "$log" 4
    [ "$status" -eq 1 ]
    [ "$output" = "github" ]
}

@test "mirror_stuck_diverged_check: does not fire when the most recent run recovered" {
    local log="$TEST_TEMP_DIR/recovered.log"
    printf '2026-08-14T09:15:00Z\tgithub\tdiverged\taaa\tbbb\n' > "$log"
    printf '2026-08-14T09:30:00Z\tgithub\tdiverged\taaa\tccc\n' >> "$log"
    printf '2026-08-14T09:45:00Z\tgithub\tdiverged\taaa\tddd\n' >> "$log"
    printf '2026-08-14T10:00:00Z\tgithub\tin-sync\teee\teee\n' >> "$log"

    run mirror_stuck_diverged_check "$log" 4
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "mirror_stuck_diverged_check: does not fire below the threshold count" {
    local log="$TEST_TEMP_DIR/short.log"
    printf '2026-08-14T09:45:00Z\tgithub\tdiverged\taaa\tddd\n' > "$log"
    printf '2026-08-14T10:00:00Z\tgithub\tdiverged\taaa\teee\n' >> "$log"

    run mirror_stuck_diverged_check "$log" 4
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "mirror_stuck_diverged_check: missing log file is not stuck" {
    run mirror_stuck_diverged_check "$TEST_TEMP_DIR/does-not-exist.log" 4
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "mirror_sync: diverged remote still refused when local checkout is on a non-default branch (positive control, L-616)" {
    git remote remove mirror_synced
    git remote remove mirror_behind
    git remote remove mirror_unreachable

    git checkout -q -b totally-unrelated-local-branch

    local before
    before=$(git ls-remote mirror_diverged refs/heads/master | awk '{print $1}')

    run mirror_sync
    [ "$status" -eq 1 ]
    [[ "$output" == *"DIVERGED"* ]]

    local after
    after=$(git ls-remote mirror_diverged refs/heads/master | awk '{print $1}')
    [ "$after" = "$before" ]
}
