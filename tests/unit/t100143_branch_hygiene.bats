#!/usr/bin/env bats
# T-100143 (C2 of T-100139): branch-hygiene WARN scan — lib/branch-hygiene.sh
#
# Fixture: bare ORIGIN + CLONE with a master lineage. Each test arranges a
# hygiene state and asserts fw_branch_hygiene's line output (empty = clean).

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    FIX="$BATS_TEST_TMPDIR/fix"
    ORIGIN="$FIX/origin.git"
    CLONE="$FIX/clone"
    mkdir -p "$FIX"
    git init --bare -q -b master "$ORIGIN"
    git clone -q "$ORIGIN" "$CLONE" 2>/dev/null
    cd "$CLONE"
    git config user.email t@t && git config user.name t
    git checkout -q -b master
    echo one > f.txt && git add f.txt && git commit -qm c1
    echo two >> f.txt && git commit -qam c2
    git push -q origin master
    # shellcheck disable=SC1091
    . "$REPO_ROOT/lib/branch-hygiene.sh"
}

@test "clean repo: no findings (silence)" {
    run fw_branch_hygiene "$CLONE"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "merged-but-undeleted local branch surfaces" {
    git -C "$CLONE" branch merged-feat HEAD~1
    run fw_branch_hygiene "$CLONE"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "^merged-undeleted merged-feat$"
}

@test "live branch behind threshold surfaces; under threshold silent" {
    # branch with unique commit (unmerged), then advance master by 3
    git -C "$CLONE" checkout -qb live-feat
    echo lf > lf.txt && git -C "$CLONE" add lf.txt && git -C "$CLONE" commit -qm lf
    git -C "$CLONE" checkout -q master
    for i in 1 2 3; do
        echo "m$i" >> f.txt && git -C "$CLONE" commit -qam "m$i"
    done
    git -C "$CLONE" push -q origin master
    # threshold 2 → behind=3 fires
    FW_BRANCH_BEHIND_WARN=2 run fw_branch_hygiene "$CLONE"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "^behind-threshold live-feat behind=3 (threshold 2)$"
    # threshold 5 → behind=3 silent
    FW_BRANCH_BEHIND_WARN=5 run fw_branch_hygiene "$CLONE"
    [ "$status" -eq 0 ]
    ! echo "$output" | grep -q "behind-threshold"
}

@test "worktree on merged branch surfaces with path and branch" {
    git -C "$CLONE" branch wt-feat HEAD~1
    git -C "$CLONE" worktree add -q "$FIX/wt-feat" wt-feat
    run fw_branch_hygiene "$CLONE"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "^worktree-merged .*wt-feat branch=wt-feat$"
    # the branch itself is also reported as merged-undeleted
    echo "$output" | grep -q "^merged-undeleted wt-feat$"
}

@test "remote ref fully contained in origin/master surfaces; ahead remote silent" {
    # contained remote branch: push master~1 as origin/old-feat
    git -C "$CLONE" push -q origin "HEAD~1:refs/heads/old-feat"
    # ahead remote branch: unique commit pushed as origin/ahead-feat
    git -C "$CLONE" checkout -qb ahead-feat
    echo af > af.txt && git -C "$CLONE" add af.txt && git -C "$CLONE" commit -qm af
    git -C "$CLONE" push -q origin ahead-feat
    git -C "$CLONE" checkout -q master
    git -C "$CLONE" branch -q -D ahead-feat
    git -C "$CLONE" fetch -q origin
    run fw_branch_hygiene "$CLONE"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "^remote-contained origin/old-feat$"
    ! echo "$output" | grep -q "remote-contained origin/ahead-feat"
    ! echo "$output" | grep -q "remote-contained origin/master"
}

@test "repo with no master lineage: silent, exit 0" {
    NOMASTER="$FIX/nomaster"
    git init -q -b trunk "$NOMASTER"
    cd "$NOMASTER"
    git config user.email t@t && git config user.name t
    echo x > x.txt && git add x.txt && git commit -qm x
    run fw_branch_hygiene "$NOMASTER"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}
