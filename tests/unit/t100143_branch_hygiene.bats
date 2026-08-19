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

@test "remote ref fully contained in origin/master reports contained, not ahead" {
    # Name updated by T-3092: an ahead remote is no longer silent — it now reports
    # `remote-unlanded`. What this test still pins is that a CONTAINED ref reports
    # contained and that the two classes never cross.
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

# ── T-3092: remote refs carrying unlanded commits ──────────────────────────
#
# The gap these cover: the remote loop had one arm (`remote-contained`, ahead=0)
# and emitted NOTHING for the complement. A remote ref holding work not on master
# was not reported as risky — it was not reported at all.
#
# Assertion style. `! cmd | grep -q X` in NON-FINAL position is INERT: `set -e`
# ignores the status of any command inverted with `!`, and bats only checks the
# body's final line. The refute helper below returns non-zero explicitly so a
# leak fails the test wherever it sits. (Same class as L-387 pipefail and the
# T-3090 inert-leak assertion — a green test that asserts nothing.)

_refute_line() {
    if echo "$output" | grep -q "$1"; then
        echo "LEAK: output matched '$1' but should not have:" >&2
        echo "$output" >&2
        return 1
    fi
    return 0
}

@test "T-3092: remote ref with unlanded commits surfaces with its count" {
    git -C "$CLONE" checkout -qb strand-feat
    echo s1 > s1.txt && git -C "$CLONE" add s1.txt && git -C "$CLONE" commit -qm s1
    echo s2 > s2.txt && git -C "$CLONE" add s2.txt && git -C "$CLONE" commit -qm s2
    git -C "$CLONE" push -q origin strand-feat
    git -C "$CLONE" checkout -q master
    git -C "$CLONE" branch -q -D strand-feat
    git -C "$CLONE" fetch -q origin

    run fw_branch_hygiene "$CLONE"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "^remote-unlanded origin/strand-feat ahead=2$"
}

@test "T-3092: contained remote refs still report contained, not unlanded" {
    # Regression guard: the new arm shares the loop with the old one, so a
    # mistake in the branch condition silently reclassifies every landed ref.
    git -C "$CLONE" push -q origin "HEAD~1:refs/heads/old-feat"
    git -C "$CLONE" fetch -q origin

    run fw_branch_hygiene "$CLONE"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "^remote-contained origin/old-feat$"
    _refute_line "remote-unlanded origin/old-feat"
}

@test "T-3092: a landed LOCAL namesake does not suppress the remote finding" {
    # The exact t2416 confusion. Local `t2416-fw-safe-mode-hook-timing` was an
    # ancestor of origin/master and read `merged-undeleted`; the remote ref of the
    # same name held 202 unlanded commits and read as nothing. An operator seeing
    # only the local verdict concludes the branch is landed and deletable.
    # Both halves must be judged on their own evidence.
    git -C "$CLONE" checkout -qb twin
    echo t > t.txt && git -C "$CLONE" add t.txt && git -C "$CLONE" commit -qm t
    git -C "$CLONE" push -q origin twin
    # local `twin` is now reset to a commit that IS on master → landed
    git -C "$CLONE" checkout -q master
    git -C "$CLONE" branch -qf twin HEAD~1
    git -C "$CLONE" fetch -q origin

    run fw_branch_hygiene "$CLONE"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "^merged-undeleted twin$"
    echo "$output" | grep -q "^remote-unlanded origin/twin ahead=1$"
}

@test "T-3092: the current branch's own upstream is not reported as a strand" {
    # You are standing on it; fw_branch_divergence reports it in detail. A
    # permanent WARN for your own working branch is the noise that trains people
    # to stop reading the section.
    git -C "$CLONE" checkout -qb mine
    echo m > m.txt && git -C "$CLONE" add m.txt && git -C "$CLONE" commit -qm m
    git -C "$CLONE" push -q -u origin mine
    git -C "$CLONE" fetch -q origin

    run fw_branch_hygiene "$CLONE"
    [ "$status" -eq 0 ]
    _refute_line "remote-unlanded origin/mine"
}

@test "T-3092: a corrupt remote ref produces no finding at all" {
    # A corrupt ref must not become a bogus WARN. It does not, but NOT for the
    # reason the code suggests: `for-each-ref` drops broken refs before the loop
    # can see them (it prints `warning: ignoring broken ref` and omits the row),
    # so the sentinel guard inside the loop is never what saves us here.
    #
    # This test previously claimed to cover the sentinel and was INERT — proven by
    # mutation: restoring the old `|| echo 1` fallback left it green. Kept, with
    # its claim corrected, because the operator-visible guarantee is real and
    # worth pinning: repo corruption yields silence, not a phantom strand.
    git -C "$CLONE" push -q origin "HEAD:refs/heads/broken-feat"
    git -C "$CLONE" fetch -q origin
    echo "0000000000000000000000000000000000000000" > "$CLONE/.git/refs/remotes/origin/broken-feat"

    # stderr is dropped, matching the only real caller (`bin/fw:3221` runs this as
    # `$(fw_branch_hygiene "$root" 2>/dev/null)`). Without that, git's own
    # `warning: ignoring broken ref ...` lands in bats' $output and the assertion
    # fails on a line the doctor rail never sees.
    run bash -c "source '$REPO_ROOT/lib/branch-hygiene.sh'; fw_branch_hygiene '$CLONE' 2>/dev/null"
    [ "$status" -eq 0 ]
    _refute_line "origin/broken-feat"
}

# ── T-3092: class-representative truncation (fw_branch_hygiene_head) ────────
#
# fw_doctor caps the printed findings. The cap was positional and the emission
# order puts remote refs last, so on a repo with 12+ local findings every remote
# finding was cut off. A class that is always truncated has not shipped.

@test "T-3092 head: under the cap, everything passes through unchanged" {
    run bash -c "source '$REPO_ROOT/lib/branch-hygiene.sh'; printf 'a x\nb y\nc z\n' | fw_branch_hygiene_head 12"
    [ "$status" -eq 0 ]
    [ "$(echo "$output" | grep -c .)" -eq 3 ]
}

@test "T-3092 head: over the cap, every class that fired is still represented" {
    # 12 local findings then one of each remote class — the live shape that hid
    # remote-unlanded behind `head -12`.
    local input=""
    for i in $(seq 1 12); do input+="behind-threshold b$i behind=99"$'\n'; done
    input+="remote-contained origin/done"$'\n'
    input+="remote-unlanded origin/strand ahead=204"$'\n'

    run bash -c "source '$REPO_ROOT/lib/branch-hygiene.sh'; printf '%s' '$input' | fw_branch_hygiene_head 12"
    [ "$status" -eq 0 ]
    [ "$(echo "$output" | grep -c .)" -eq 12 ]
    echo "$output" | grep -q '^remote-unlanded origin/strand ahead=204$'
    echo "$output" | grep -q '^remote-contained origin/done$'
    echo "$output" | grep -q '^behind-threshold '
}

@test "T-3092 head: a positional cap would have dropped the remote classes" {
    # The control that gives the test above its meaning: same input, plain
    # `head -12`, and the remote lines are gone. Without this, "grep found it"
    # proves nothing about what the cap was doing before.
    local input=""
    for i in $(seq 1 12); do input+="behind-threshold b$i behind=99"$'\n'; done
    input+="remote-unlanded origin/strand ahead=204"$'\n'

    run bash -c "printf '%s' '$input' | head -12"
    [ "$status" -eq 0 ]
    _refute_line "remote-unlanded"
}

@test "T-3092 head: never emits more than the cap" {
    local input=""
    for i in $(seq 1 40); do input+="behind-threshold b$i behind=99"$'\n'; done
    run bash -c "source '$REPO_ROOT/lib/branch-hygiene.sh'; printf '%s' '$input' | fw_branch_hygiene_head 5"
    [ "$status" -eq 0 ]
    [ "$(echo "$output" | grep -c .)" -eq 5 ]
}
