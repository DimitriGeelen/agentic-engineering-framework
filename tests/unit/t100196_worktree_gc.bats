#!/usr/bin/env bats
# T-100196 slice 2: `fw worktree gc` reclaim analysis (lib/worktree.sh).
#
# The core fix (T-100199 finding): `git cherry` compares patch-ids, which never
# match after re-derivation (fw integrate + vendor self re-commit different file
# sets), so it falsely reports landed branches as unlanded. gc instead does a
# CONTENT comparison of DELIVERABLE files (ignoring vendored/generated/governance
# paths), which survives re-derivation.
#
# Fixture models re-derivation directly: a branch whose source file is
# byte-identical on master but whose vendored copy differs → must be RECLAIM.

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    FIX="$BATS_TEST_TMPDIR/fix"
    CLONE="$FIX/clone"
    mkdir -p "$FIX"
    git init -q -b master "$CLONE"
    cd "$CLONE"
    git config user.email t@t && git config user.name t
    # merge-base commit
    mkdir -p lib .agentic-framework/lib .context/working
    echo old  > lib/foo.sh
    echo old  > lib/bar.sh
    echo v0   > .agentic-framework/lib/foo.sh
    git add -A && git commit -qm mb
    MB="$(git rev-parse HEAD)"

    # branch feat-landed: source file reaches its FINAL content + a vendored copy
    # (v1). This models a change that later lands on master via re-derivation.
    git checkout -q -b feat-landed
    echo final > lib/foo.sh
    echo v1    > .agentic-framework/lib/foo.sh
    git commit -qam "feat: foo final (+vendored v1)"

    # branch feat-unlanded: a source change that is NOT on master.
    git checkout -q master
    git checkout -q -b feat-unlanded
    echo branchonly > lib/bar.sh
    git commit -qam "feat: bar branchonly"

    # branch feat-churn-only: touches only an ignorable (governance) path.
    git checkout -q master
    git checkout -q -b feat-churn-only
    echo note > .context/working/scratch.txt
    git add -A && git commit -qm "churn: context only"

    # master advances: same FINAL source content as feat-landed, but a DIFFERENT
    # vendored copy (v2) — exactly the re-derivation shape that defeats git cherry.
    git checkout -q master
    echo final > lib/foo.sh
    echo v2    > .agentic-framework/lib/foo.sh
    git commit -qam "master: foo final (+vendored v2, re-derived)"

    # shellcheck disable=SC1091
    . "$REPO_ROOT/lib/worktree.sh"
}

@test "gc: source byte-identical on master (vendored differs) → RECLAIM (survives re-derivation)" {
    run do_worktree_gc
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "RECLAIM branch    feat-landed  (all-deliverables-on-master)"
}

@test "gc: git cherry would FALSELY call the landed branch unlanded (control)" {
    # Proves the fix matters: cherry sees the branch commit as unlanded (+).
    run git cherry master feat-landed
    echo "$output" | grep -q '^+'
}

@test "gc: branch with a source change not on master → KEEP (unlanded)" {
    run do_worktree_gc
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "KEEP  feat-unlanded  (unlanded:1/1)"
}

@test "gc: branch touching only ignorable paths → RECLAIM (no-deliverables)" {
    run do_worktree_gc
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "RECLAIM branch    feat-churn-only  (no-deliverables)"
}

@test "gc: never lists master itself as reclaimable" {
    run do_worktree_gc
    [ "$status" -eq 0 ]
    ! echo "$output" | grep -qE "RECLAIM (branch|worktree) +master"
}

@test "gc --json emits valid JSON with per-branch verdicts" {
    run do_worktree_gc --json
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c 'import sys,json; d=json.load(sys.stdin); assert isinstance(d["items"],list) and len(d["items"])>=3'
    echo "$output" | python3 -c 'import sys,json; d=json.load(sys.stdin); ks={i["branch"]:i["kind"] for i in d["items"]}; assert ks["feat-landed"]=="reclaim-branch"; assert ks["feat-unlanded"]=="keep-branch"'
}

@test "gc: no-remote unlanded branch is flagged push-before-prune" {
    run do_worktree_gc
    [ "$status" -eq 0 ]
    echo "$output" | grep "feat-unlanded" | grep -q "no remote"
}
