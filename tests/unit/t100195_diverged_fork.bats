#!/usr/bin/env bats
# T-100195 (RCA T-100194): bidirectional-fork detection in lib/branch-hygiene.sh.
#
# The behind-only reading could not distinguish a genuine fork (branch ALSO
# substantially ahead) from a pure lag — the exact state that made a go-live
# `git merge origin/master` explode into 100+ conflicts. These tests pin the
# three-way distinction for both surfaces:
#   fw_branch_hygiene   (all local branches, doctor scan)  → diverged-fork
#   fw_branch_divergence (current checkout, handover)       → fork / nudge
#
# Fixture: bare ORIGIN + CLONE with a master lineage; threshold set low (2) so
# small commit counts cross it.

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

# ── fw_branch_hygiene: all-branches scan ──

@test "hygiene: branch ahead>threshold AND behind>threshold → diverged-fork (not behind-threshold)" {
    # live branch with 3 unique commits, then advance master by 3
    git -C "$CLONE" checkout -qb fork-feat
    for i in 1 2 3; do echo "lf$i" >> lf.txt && git -C "$CLONE" add lf.txt && git -C "$CLONE" commit -qm "lf$i"; done
    git -C "$CLONE" checkout -q master
    for i in 1 2 3; do echo "m$i" >> f.txt && git -C "$CLONE" commit -qam "m$i"; done
    git -C "$CLONE" push -q origin master
    # threshold 2 → ahead=3>2 AND behind=3>2 → diverged-fork
    FW_BRANCH_BEHIND_WARN=2 run fw_branch_hygiene "$CLONE"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "^diverged-fork fork-feat ahead=3 behind=3 (threshold 2)$"
    ! echo "$output" | grep -q "behind-threshold fork-feat"
}

@test "hygiene: small-ahead branch behind>threshold → behind-threshold, NO false diverged-fork" {
    # live branch with 1 unique commit, advance master by 3
    git -C "$CLONE" checkout -qb lag-feat
    echo lf > lf.txt && git -C "$CLONE" add lf.txt && git -C "$CLONE" commit -qm lf
    git -C "$CLONE" checkout -q master
    for i in 1 2 3; do echo "m$i" >> f.txt && git -C "$CLONE" commit -qam "m$i"; done
    git -C "$CLONE" push -q origin master
    # threshold 2 → ahead=1 NOT >2 → behind-threshold (landable lag), no fork
    FW_BRANCH_BEHIND_WARN=2 run fw_branch_hygiene "$CLONE"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "^behind-threshold lag-feat behind=3 (threshold 2)$"
    ! echo "$output" | grep -q "diverged-fork lag-feat"
}

# ── fw_branch_divergence: current-checkout, three-way ──

@test "divergence: current branch forked (ahead>t AND behind>t) → fork line" {
    git -C "$CLONE" checkout -qb cur-fork
    for i in 1 2 3; do echo "c$i" >> c.txt && git -C "$CLONE" add c.txt && git -C "$CLONE" commit -qm "c$i"; done
    # advance origin/master by 3 via a second clone so origin/master ref moves
    git -C "$CLONE" checkout -q master
    for i in 1 2 3; do echo "m$i" >> f.txt && git -C "$CLONE" commit -qam "m$i"; done
    git -C "$CLONE" push -q origin master
    git -C "$CLONE" fetch -q origin
    git -C "$CLONE" checkout -q cur-fork
    FW_BRANCH_BEHIND_WARN=2 run fw_branch_divergence "$CLONE"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "^fork ahead=3 behind=3 threshold=2$"
    ! echo "$output" | grep -q "^nudge "
}

@test "divergence: merely-behind (ahead=0, behind>t) → nudge, not fork" {
    # a branch with NO unique commits, but origin/master advances past it
    git -C "$CLONE" checkout -qb cur-lag
    git -C "$CLONE" checkout -q master
    for i in 1 2 3; do echo "m$i" >> f.txt && git -C "$CLONE" commit -qam "m$i"; done
    git -C "$CLONE" push -q origin master
    git -C "$CLONE" fetch -q origin
    git -C "$CLONE" checkout -q cur-lag
    FW_BRANCH_BEHIND_WARN=2 run fw_branch_divergence "$CLONE"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "^nudge behind=3 threshold=2$"
    ! echo "$output" | grep -q "^fork "
}

@test "divergence: up-to-date branch → neither fork nor nudge" {
    git -C "$CLONE" checkout -qb cur-clean
    echo x >> c.txt && git -C "$CLONE" add c.txt && git -C "$CLONE" commit -qm x
    FW_BRANCH_BEHIND_WARN=2 run fw_branch_divergence "$CLONE"
    [ "$status" -eq 0 ]
    if echo "$output" | grep -q "^fork "; then false; fi
    if echo "$output" | grep -q "^nudge "; then false; fi
    echo "$output" | grep -q "^divergence cur-clean "
}
