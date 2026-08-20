#!/usr/bin/env bats
# T-3095 (T-3093 slice 2): branch hygiene on the audit cron.
#
# The block under test lives inside a 6000-line audit.sh, so it is EXTRACTED
# from the shipped source and evaluated against stub pass/warn/info/fail — the
# same technique T-3096 used for the hook's message functions. Extracting keeps
# the assertions pinned to the real file: a copy in the test would pass forever
# after audit.sh changed, which is the defect class this rail exists to catch.

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    FIX="$BATS_TEST_TMPDIR/fix"
    ORIGIN="$FIX/origin.git"
    CLONE="$FIX/clone"
    mkdir -p "$FIX"

    RUNNER="$REPO_ROOT/tests/helpers/audit-branch-hygiene-block.sh"

    git init --bare -q -b master "$ORIGIN"
    git clone -q "$ORIGIN" "$CLONE" 2>/dev/null
    cd "$CLONE"
    git config user.email t@t && git config user.name t
    git checkout -q -b master
    echo one > f.txt && git add f.txt && git commit -qm c1
    echo two >> f.txt && git commit -qam c2
    git push -q origin master
}

_block() { run "$RUNNER" "$REPO_ROOT" "$1"; }

# ── the four states named in the ACs ──────────────────────────────────────────

@test "findings present: WARN emitted with the finding count" {
    git -C "$CLONE" branch stale-feat HEAD~1
    _block "$CLONE"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q '^WARN|Branch hygiene: 1 finding(s)'
    echo "$output" | grep -q 'EVIDENCE|merged-undeleted stale-feat'
}

@test "findings absent: positive OK line, not silence" {
    _block "$CLONE"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q '^PASS|Branch hygiene: no stale'
    ! echo "$output" | grep -q '^WARN|'
}

@test "linked worktree: INFO skip, never WARN" {
    git -C "$CLONE" branch merged-feat HEAD~1
    git -C "$CLONE" worktree add -q "$FIX/wt" -b wtbranch >/dev/null 2>&1
    _block "$FIX/wt"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q '^INFO|Branch hygiene skipped — linked worktree'
    ! echo "$output" | grep -q '^WARN|'
    ! echo "$output" | grep -q '^PASS|Branch hygiene'
}

@test "exit-code neutrality: findings never raise FAIL_COUNT" {
    git -C "$CLONE" branch a HEAD~1
    git -C "$CLONE" branch b HEAD~1
    _block "$CLONE"
    echo "$output" | grep -q 'COUNTS|pass=0|warn=1|fail=0'
}

@test "the block contains no fail() call at all" {
    # Structural companion to the count assertion above: the audit's exit code
    # is 2 only when FAIL_COUNT > 0, so the guarantee is that this block cannot
    # reach fail() on ANY input, not merely that it did not on this fixture.
    run bash -c "sed -n '/^_bh_lib=\"\\\$FRAMEWORK_ROOT\\/lib\\/branch-hygiene\\.sh\"\$/,/^fi\$/p' '$REPO_ROOT/agents/audit/audit.sh' | grep -E '^[[:space:]]*fail '"
    [ "$status" -ne 0 ]
}

# ── class-representative truncation (AC #3) ───────────────────────────────────

@test "over the cap: every class is represented, not the first 12 lines" {
    # 13 merged locals fill a positional cap on their own; the remote class is
    # emitted last. A flat `head -12` shows zero remote findings — the exact
    # miss T-3092 fixed in doctor (0 of 4 remote lines survived).
    for i in 01 02 03 04 05 06 07 08 09 10 11 12 13; do
        git -C "$CLONE" branch "a$i" HEAD~1
    done
    git -C "$CLONE" checkout -q -b strand
    echo s >> f.txt && git -C "$CLONE" commit -qam strand
    git -C "$CLONE" push -q origin strand
    git -C "$CLONE" checkout -q master
    git -C "$CLONE" branch -qD strand
    git -C "$CLONE" fetch -q origin
    _block "$CLONE"
    echo "$output" | grep -q '^WARN|Branch hygiene: 14 finding(s)'
    echo "$output" | grep -q 'remote-unlanded origin/strand'
    echo "$output" | grep -q 'more (shown lines are one-per-class'
}

# ── surfaces that must not report a check that could not run ──────────────────

@test "no master lineage: INFO skip, never a clean PASS" {
    git init -q -b main "$FIX/nomaster"
    git -C "$FIX/nomaster" config user.email t@t
    git -C "$FIX/nomaster" config user.name t
    echo x > "$FIX/nomaster/f" && git -C "$FIX/nomaster" add f
    git -C "$FIX/nomaster" commit -qm c1
    _block "$FIX/nomaster"
    echo "$output" | grep -q '^INFO|Branch hygiene skipped — no master lineage'
    ! echo "$output" | grep -q '^PASS|Branch hygiene: no stale'
}

@test "not a git repository: block is silent, emits nothing" {
    mkdir -p "$FIX/plain"
    _block "$FIX/plain"
    ! echo "$output" | grep -q 'Branch hygiene'
}

# ── remedy routing (T-100195) ─────────────────────────────────────────────────

@test "diverged-fork present: mitigation names the fork remedy, not fw integrate" {
    git -C "$CLONE" checkout -q -b forked
    echo a >> f.txt && git -C "$CLONE" commit -qam fa
    echo b >> f.txt && git -C "$CLONE" commit -qam fb
    git -C "$CLONE" checkout -q master
    echo m1 >> g.txt && git -C "$CLONE" add g.txt && git -C "$CLONE" commit -qm m1
    echo m2 >> g.txt && git -C "$CLONE" commit -qam m2
    git -C "$CLONE" push -q origin master
    FW_BRANCH_BEHIND_WARN=1 FW_BRANCH_STALE_DAYS=0 run "$RUNNER" "$REPO_ROOT" "$CLONE"
    echo "$output" | grep -q 'EVIDENCE|.*diverged-fork forked' || echo "$output" | grep -q 'diverged-fork forked'
    echo "$output" | grep -q 'MITIGATION|.*FORK present: reconcile while small'
    echo "$output" | grep -q 'MITIGATION|.*Do NOT use fw integrate on a fork'
}

# ── the call, not a copy (AC #1) ──────────────────────────────────────────────

@test "audit calls fw_branch_hygiene rather than re-implementing it" {
    grep -q 'fw_branch_hygiene "\$PROJECT_ROOT"' "$REPO_ROOT/agents/audit/audit.sh"
    grep -q 'fw_branch_hygiene_head' "$REPO_ROOT/agents/audit/audit.sh"
    # No second copy of the classification vocabulary: the class tokens must
    # appear in audit.sh only where they are MATCHED (the diverged-fork remedy
    # routing), never where they are EMITTED.
    run bash -c "grep -nE '^[[:space:]]*echo \"(merged-undeleted|behind-threshold|diverged-fork|worktree-merged|remote-contained|remote-unlanded) ' '$REPO_ROOT/agents/audit/audit.sh'"
    [ "$status" -ne 0 ]
}
