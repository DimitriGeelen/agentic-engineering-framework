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
    # T-3094: this test commits seconds before asserting, so the recency gate would
    # correctly suppress it. FW_BRANCH_STALE_DAYS=0 isolates the BEHIND threshold,
    # which is what this test is actually about — the recency boundary has its own
    # coverage below. Kept rather than deleted: the behind-count still decides
    # WHICH stale branches surface, it just no longer decides ON ITS OWN.
    # branch with unique commit (unmerged), then advance master by 3
    git -C "$CLONE" checkout -qb live-feat
    echo lf > lf.txt && git -C "$CLONE" add lf.txt && git -C "$CLONE" commit -qm lf
    git -C "$CLONE" checkout -q master
    for i in 1 2 3; do
        echo "m$i" >> f.txt && git -C "$CLONE" commit -qam "m$i"
    done
    git -C "$CLONE" push -q origin master
    # threshold 2 → behind=3 fires
    FW_BRANCH_BEHIND_WARN=2 FW_BRANCH_STALE_DAYS=0 run fw_branch_hygiene "$CLONE"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "^behind-threshold live-feat behind=3 days=0 (threshold 2)$"
    # threshold 5 → behind=3 silent
    FW_BRANCH_BEHIND_WARN=5 FW_BRANCH_STALE_DAYS=0 run fw_branch_hygiene "$CLONE"
    [ "$status" -eq 0 ]
    _refute_line "behind-threshold"
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
    [[ "$output" != *"remote-contained origin/ahead-feat"* ]]
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

# ── T-3094 (T-3093 slice 1): staleness measured in days, not commits ────────
#
# The behind-count answers "how much happened elsewhere". On the origin repo
# origin/master moves ~41 commits/day and 88% of that is governance churn, so the
# 50-commit threshold trips in ~1.2 days — every healthy branch became a finding
# by the next morning. That false-positive rate is why the section went unread.
# Recency gates the staleness classes; the counts stay on the line because they
# are what tell the operator whether a strand is still landable.

@test "T-3094: a branch committed to recently is silent however far behind" {
    git -C "$CLONE" checkout -qb fresh-feat
    echo ff > ff.txt && git -C "$CLONE" add ff.txt && git -C "$CLONE" commit -qm ff
    git -C "$CLONE" checkout -q master
    for i in 1 2 3 4 5; do echo "m$i" >> f.txt && git -C "$CLONE" commit -qam "m$i"; done
    git -C "$CLONE" push -q origin master

    # behind=5 > threshold 2, but the branch was committed to seconds ago
    FW_BRANCH_BEHIND_WARN=2 FW_BRANCH_STALE_DAYS=30 run fw_branch_hygiene "$CLONE"
    [ "$status" -eq 0 ]
    _refute_line "fresh-feat"
}

@test "T-3094: control — the same branch DOES fire once recency is not required" {
    # Without this, the test above is satisfied by any bug that drops the branch
    # entirely (wrong ref path, broken loop). This proves the branch is otherwise
    # a finding and that recency is the only thing suppressing it.
    git -C "$CLONE" checkout -qb fresh-feat
    echo ff > ff.txt && git -C "$CLONE" add ff.txt && git -C "$CLONE" commit -qm ff
    git -C "$CLONE" checkout -q master
    for i in 1 2 3 4 5; do echo "m$i" >> f.txt && git -C "$CLONE" commit -qam "m$i"; done
    git -C "$CLONE" push -q origin master

    FW_BRANCH_BEHIND_WARN=2 FW_BRANCH_STALE_DAYS=0 run fw_branch_hygiene "$CLONE"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q '^behind-threshold fresh-feat behind=5 days=0 (threshold 2)$'
}

@test "T-3094: an untouched branch still surfaces, with days on the line" {
    git -C "$CLONE" checkout -qb old-feat
    # commit dated 90 days ago
    GIT_AUTHOR_DATE="$(date -d '90 days ago' +%s) +0000" \
    GIT_COMMITTER_DATE="$(date -d '90 days ago' +%s) +0000" \
        git -C "$CLONE" commit -q --allow-empty -m stale
    git -C "$CLONE" checkout -q master
    for i in 1 2 3; do echo "m$i" >> f.txt && git -C "$CLONE" commit -qam "m$i"; done
    git -C "$CLONE" push -q origin master

    FW_BRANCH_BEHIND_WARN=2 FW_BRANCH_STALE_DAYS=30 run fw_branch_hygiene "$CLONE"
    [ "$status" -eq 0 ]
    echo "$output" | grep -qE '^behind-threshold old-feat behind=3 days=(89|90|91) \(threshold 2\)$'
}

@test "T-3094: the threshold is a boundary, not a suggestion" {
    git -C "$CLONE" checkout -qb edge-feat
    GIT_AUTHOR_DATE="$(date -d '10 days ago' +%s) +0000" \
    GIT_COMMITTER_DATE="$(date -d '10 days ago' +%s) +0000" \
        git -C "$CLONE" commit -q --allow-empty -m edge
    git -C "$CLONE" checkout -q master
    for i in 1 2 3; do echo "m$i" >> f.txt && git -C "$CLONE" commit -qam "m$i"; done
    git -C "$CLONE" push -q origin master

    # 10 days old, threshold 11 → under, silent
    FW_BRANCH_BEHIND_WARN=2 FW_BRANCH_STALE_DAYS=11 run fw_branch_hygiene "$CLONE"
    [ "$status" -eq 0 ]
    _refute_line "edge-feat"
    # threshold 10 → at the boundary, fires
    FW_BRANCH_BEHIND_WARN=2 FW_BRANCH_STALE_DAYS=10 run fw_branch_hygiene "$CLONE"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q '^behind-threshold edge-feat '
}

@test "T-3094: recency does not touch the non-staleness classes" {
    # merged-undeleted, remote-contained and remote-unlanded are not staleness
    # judgements — a freshly-merged branch is still undeleted, and a remote ref
    # committed to this morning still holds unlanded work.
    git -C "$CLONE" branch merged-fresh HEAD~1
    git -C "$CLONE" push -q origin "HEAD~1:refs/heads/contained-fresh"
    git -C "$CLONE" checkout -qb unlanded-fresh
    echo u > u.txt && git -C "$CLONE" add u.txt && git -C "$CLONE" commit -qm u
    git -C "$CLONE" push -q origin unlanded-fresh
    git -C "$CLONE" checkout -q master
    git -C "$CLONE" branch -q -D unlanded-fresh
    git -C "$CLONE" fetch -q origin

    FW_BRANCH_STALE_DAYS=30 run fw_branch_hygiene "$CLONE"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q '^merged-undeleted merged-fresh$'
    echo "$output" | grep -q '^remote-contained origin/contained-fresh$'
    echo "$output" | grep -q '^remote-unlanded origin/unlanded-fresh ahead=1$'
}

@test "T-3094: the date helper returns empty for a ref it cannot date" {
    # Contract test for _bh_days_since_commit, not for the caller.
    #
    # The caller treats an empty result as STALE (fail loud, `-n "$_days" &&`) so a
    # branch is never silently exempted by a date lookup failure. That choice is
    # NOT covered by a caller-level test and mutating it to fail-silent leaves the
    # suite green — because the loop only ever passes `refs/heads/$br` for a ref it
    # just enumerated, so the empty case is unreachable from there. Documented
    # rather than papered over; same shape as the T-3092 sentinel.
    run bash -c "source '$REPO_ROOT/lib/branch-hygiene.sh'; _bh_days_since_commit '$CLONE' 'refs/heads/does-not-exist'"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    # and a real ref does yield a number, so the empty result means something
    run bash -c "source '$REPO_ROOT/lib/branch-hygiene.sh'; _bh_days_since_commit '$CLONE' 'refs/heads/master'"
    [ "$status" -eq 0 ]
    [[ "$output" =~ ^[0-9]+$ ]]
}
