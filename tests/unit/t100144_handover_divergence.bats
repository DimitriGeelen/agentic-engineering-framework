#!/usr/bin/env bats
# T-100144 (C3 of T-100139): handover branch-divergence line + merge-back nudge
#
# Function-level tests against fw_branch_divergence (lib/branch-hygiene.sh)
# plus static wiring pins on agents/handover/handover.sh.

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
    git push -q origin master
    # shellcheck disable=SC1091
    . "$REPO_ROOT/lib/branch-hygiene.sh"
}

# advance origin/master by N commits without moving the clone's checkout
_advance_origin_master() {
    local n="$1"
    local cur
    cur=$(git -C "$CLONE" branch --show-current)
    git -C "$CLONE" checkout -q master
    for i in $(seq 1 "$n"); do
        echo "m$i" >> f.txt && git -C "$CLONE" commit -qam "m$i"
    done
    git -C "$CLONE" push -q origin master
    git -C "$CLONE" checkout -q "$cur"
}

@test "divergence line: ahead and behind counts vs origin/master" {
    git -C "$CLONE" checkout -qb feat
    echo a > a.txt && git -C "$CLONE" add a.txt && git -C "$CLONE" commit -qm a
    _advance_origin_master 2
    run fw_branch_divergence "$CLONE"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "^divergence feat ahead=1 behind=2$"
}

@test "nudge fires when behind exceeds threshold" {
    git -C "$CLONE" checkout -qb feat
    echo a > a.txt && git -C "$CLONE" add a.txt && git -C "$CLONE" commit -qm a
    _advance_origin_master 3
    FW_BRANCH_BEHIND_WARN=2 run fw_branch_divergence "$CLONE"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "^nudge behind=3 threshold=2$"
}

@test "no nudge when behind is within threshold" {
    git -C "$CLONE" checkout -qb feat
    echo a > a.txt && git -C "$CLONE" add a.txt && git -C "$CLONE" commit -qm a
    _advance_origin_master 3
    FW_BRANCH_BEHIND_WARN=5 run fw_branch_divergence "$CLONE"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "^divergence feat ahead=1 behind=3$"
    ! echo "$output" | grep -q "^nudge"
}

@test "silent on master" {
    run fw_branch_divergence "$CLONE"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "silent when origin/master absent" {
    NOREMOTE="$FIX/noremote"
    git init -q -b master "$NOREMOTE"
    cd "$NOREMOTE"
    git config user.email t@t && git config user.name t
    echo x > x.txt && git add x.txt && git commit -qm x
    git checkout -qb feat
    run fw_branch_divergence "$NOREMOTE"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "handover.sh wires divergence + nudge into the document" {
    local h="$REPO_ROOT/agents/handover/handover.sh"
    grep -q "fw_branch_divergence" "$h"
    # divergence line rendered under Where We Are
    grep -q '${BRANCH_DIVERGENCE}' "$h"
    # nudge rendered under Suggested First Action
    grep -q '${MERGEBACK_NUDGE}' "$h"
    # nudge text names the landing verb
    grep -q "fw integrate run master --push" "$h"
}
