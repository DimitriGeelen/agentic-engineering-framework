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
#
# ── READ THIS BEFORE ADDING A fw_branch_hygiene TEST (T-3199) ───────────────
# `fw_branch_hygiene` gates BOTH staleness classes on recency (T-3094,
# lib/branch-hygiene.sh:175):
#
#     _days=$(_bh_days_since_commit "$repo" "refs/heads/$br")
#     [ -n "$_days" ] && [ "$_days" -lt "$stale_days" ] && continue
#
# Every commit a bats fixture makes is made NOW, so `_days=0` and the default
# `FW_BRANCH_STALE_DAYS=30` skips the branch before any finding is reached.
# **A fresh fixture is invisible to the all-branches scan.** A test written
# without `FW_BRANCH_STALE_DAYS=0` exercises the `continue` path and asserts
# against empty output — it will pass a `! grep` and fail a `grep` for reasons
# that have nothing to do with what it meant to check.
#
# That is exactly how tests 1 and 2 came to be red: T-3094 landed the recency
# gate AND inserted `days=<n>` into the finding line, and the anchored patterns
# here were pinned to the pre-T-3094 format. Repairing only the format leaves
# them comparing against nothing. Both halves are needed.
#
# The last test in this file pins the gate itself, so the suppression is
# covered behaviour rather than a trap rediscovered by whoever trips it next.
#
# ── AND: `! cmd` DOES NOT FAIL A BATS TEST (T-3199) ────────────────────────
# Five assertions in this file used to read `! echo "$output" | grep -q X`.
# Every one of them was inert. POSIX: *"the -e setting shall be ignored when
# executing ... any command preceded by `!`"* — so a negated command that
# returns 1 aborts nothing, and bats only reads the exit status of the LAST
# command in the body. Measured, not inferred:
#
#     @test "..." { output="PRESENT"; ! echo "$output" | grep -q PRESENT; true; }   → ok
#     @test "..." { output="PRESENT"; if echo "$output" | grep -q PRESENT; then false; fi; true; }   → not ok
#
# Use `if <cmd>; then false; fi`. It is uglier and it is the one that fires.
# This is not a hypothetical: mutation M2 below (delete the recency gate) left
# the whole suite green precisely because the assertion that should have caught
# it was a `! grep`. The negations were converted in T-3199; the sibling lint
# that would catch the next one is tracked in T-3191.

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
    # threshold 2 → ahead=3>2 AND behind=3>2 → diverged-fork.
    # STALE_DAYS=0 defeats the T-3094 recency gate — see the header. Without it
    # the branch is skipped and $output is empty, which is not this test's subject.
    FW_BRANCH_BEHIND_WARN=2 FW_BRANCH_STALE_DAYS=0 run fw_branch_hygiene "$CLONE"
    [ "$status" -eq 0 ]
    # Anchored ^...$ deliberately: this pins the WHOLE line, so a future field
    # inserted into the finding format reddens here instead of passing as a
    # prefix match. days=0 because the fixture's commits are seconds old.
    echo "$output" | grep -q "^diverged-fork fork-feat ahead=3 behind=3 days=0 (threshold 2)$"
    if echo "$output" | grep -q "behind-threshold fork-feat"; then false; fi   # T-3199: was `! cmd` — inert, see header
}

@test "hygiene: small-ahead branch behind>threshold → behind-threshold, NO false diverged-fork" {
    # live branch with 1 unique commit, advance master by 3
    git -C "$CLONE" checkout -qb lag-feat
    echo lf > lf.txt && git -C "$CLONE" add lf.txt && git -C "$CLONE" commit -qm lf
    git -C "$CLONE" checkout -q master
    for i in 1 2 3; do echo "m$i" >> f.txt && git -C "$CLONE" commit -qam "m$i"; done
    git -C "$CLONE" push -q origin master
    # threshold 2 → ahead=1 NOT >2 → behind-threshold (landable lag), no fork
    FW_BRANCH_BEHIND_WARN=2 FW_BRANCH_STALE_DAYS=0 run fw_branch_hygiene "$CLONE"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "^behind-threshold lag-feat behind=3 days=0 (threshold 2)$"
    if echo "$output" | grep -q "diverged-fork lag-feat"; then false; fi   # T-3199: was `! cmd` — inert, see header
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
    if echo "$output" | grep -q "^nudge "; then false; fi   # T-3199: was `! cmd` — inert, see header
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
    if echo "$output" | grep -q "^fork "; then false; fi   # T-3199: was `! cmd` — inert, see header
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

# ── the recency gate itself (T-3199) ──

@test "hygiene: recency gate suppresses a fresh fork — the trap, pinned" {
    # T-3094's premise: a branch someone touched today is not a strand, however
    # far behind it has fallen. Correct behaviour, and the reason tests 1-2 above
    # must opt out of it.
    #
    # This pins the suppression so it is COVERED rather than merely tripped over.
    # Same fixture, same thresholds, one variable changed — which is what makes
    # the pair readable: with the gate the finding is absent, without it present.
    git -C "$CLONE" checkout -qb fresh-fork
    for i in 1 2 3; do echo "ff$i" >> ff.txt && git -C "$CLONE" add ff.txt && git -C "$CLONE" commit -qm "ff$i"; done
    git -C "$CLONE" checkout -q master
    for i in 1 2 3; do echo "m$i" >> f.txt && git -C "$CLONE" commit -qam "m$i"; done
    git -C "$CLONE" push -q origin master

    # Default stale window: every fixture commit is seconds old, so days=0 < 30.
    FW_BRANCH_BEHIND_WARN=2 run fw_branch_hygiene "$CLONE"
    [ "$status" -eq 0 ]
    if echo "$output" | grep -q "fresh-fork"; then false; fi   # T-3199: was `! cmd` — inert, see header
    # The control that makes the assertion above mean something. Without it,
    # "suppressed by recency" and "fw_branch_hygiene emits nothing ever" are the
    # same observation — the false-green shape this whole task is about.
    FW_BRANCH_BEHIND_WARN=2 FW_BRANCH_STALE_DAYS=0 run fw_branch_hygiene "$CLONE"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "^diverged-fork fresh-fork ahead=3 behind=3 days=0 (threshold 2)$"
}
