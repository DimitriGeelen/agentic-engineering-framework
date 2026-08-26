#!/usr/bin/env bats
# T-3187: the branch guard must assert IDENTITY, not reconcilability.
#
# Every pre-existing finding class in lib/branch-hygiene.sh asks "can this
# branch still be reconciled?" — none asks "is this the branch we are meant
# to be on?". The session sat on t2539-staging for 41 days, 0 BEHIND master
# the whole time, so `diverged-fork` never had a reason to fire.
#
# The trap this suite exists to avoid: on a CORRECT branch the guard is
# silent, and silence is precisely what the broken guard produced too. So
# "silent here" is worthless as evidence on its own. Every quiet assertion
# below is paired with a firing one over the same fixture — that pairing is
# the control leg.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    REPO="$TEST_TEMP_DIR/repo"
    mkdir -p "$REPO"
    git -C "$REPO" init -q -b master
    git -C "$REPO" config user.email t@t.t
    git -C "$REPO" config user.name t
    echo base > "$REPO/f"
    git -C "$REPO" add f
    git -C "$REPO" commit -qm "base"
    # A dev branch that is AHEAD and 0 BEHIND — the exact shape the
    # reconcilability rails cannot see.
    git -C "$REPO" checkout -q -b bleeding-edge
    echo more > "$REPO/f2"
    git -C "$REPO" add f2
    git -C "$REPO" commit -qm "dev work"

    LIB="$FRAMEWORK_ROOT/lib/branch-hygiene.sh"
}

teardown() {
    rm -rf "$TEST_TEMP_DIR"
}

_hygiene() {
    bash -c "source '$LIB'; fw_branch_hygiene '$REPO'" 2>/dev/null
}

# ── The pair that matters ────────────────────────────────────────────────

@test "silent when the checkout IS on the dev branch" {
    run _hygiene
    [[ ! "$output" =~ "wrong-branch" ]]
}

@test "CONTROL LEG: fires when the checkout is on a DIFFERENT branch" {
    # Same fixture, one thing changed. If this stays silent, the test above
    # was measuring the guard's absence, not its approval.
    git -C "$REPO" checkout -q -b t9999-stray
    run _hygiene
    [[ "$output" =~ "wrong-branch t9999-stray" ]]
}

@test "the finding names BOTH the actual and the expected branch" {
    git -C "$REPO" checkout -q -b t9999-stray
    run _hygiene
    [[ "$output" =~ "wrong-branch t9999-stray expected=bleeding-edge" ]]
}

# ── The 41-day shape specifically ────────────────────────────────────────

@test "fires on a 0-BEHIND branch — the state diverged-fork cannot see" {
    git -C "$REPO" checkout -q -b t2539-staging
    # 0 behind master, ahead by one: a clean fast-forward, which is why every
    # reconcilability class passed it silently for 41 days.
    echo x > "$REPO/f3"; git -C "$REPO" add f3; git -C "$REPO" commit -qm "T-x: work"
    behind=$(git -C "$REPO" rev-list --count "refs/heads/t2539-staging..master")
    [ "$behind" -eq 0 ]
    run _hygiene
    [[ "$output" =~ "wrong-branch t2539-staging" ]]
    [[ ! "$output" =~ "diverged-fork t2539-staging" ]]
}

@test "master itself fires — it is merge-only under the release train" {
    git -C "$REPO" checkout -q master
    run _hygiene
    [[ "$output" =~ "wrong-branch master expected=bleeding-edge" ]]
}

@test "detached HEAD is reported as its own case, not silently" {
    git -C "$REPO" checkout -q --detach
    run _hygiene
    [[ "$output" =~ "wrong-branch detached-HEAD" ]]
}

# ── Scope: the guard must not cry outside its model ──────────────────────

@test "SCOPE: silent in a repo with no dev branch (consumer on master-only)" {
    git -C "$REPO" checkout -q master
    git -C "$REPO" branch -D bleeding-edge
    run _hygiene
    [[ ! "$output" =~ "wrong-branch" ]]
}

@test "SCOPE: silent in a linked worktree, which sits on a feature branch by design" {
    git -C "$REPO" checkout -q bleeding-edge
    WT="$TEST_TEMP_DIR/wt"
    git -C "$REPO" worktree add -q -b feature-x "$WT" >/dev/null 2>&1
    run bash -c "source '$LIB'; fw_branch_hygiene '$WT'"
    [[ ! "$output" =~ "wrong-branch" ]]
}

@test "SCOPE: worktree silence is scope, not blindness — main tree still fires" {
    # Pairs with the test above. Without this, 'silent in a worktree' and
    # 'the guard is broken' are the same result.
    git -C "$REPO" checkout -q -b t9999-stray
    WT="$TEST_TEMP_DIR/wt2"
    git -C "$REPO" worktree add -q -b feature-y "$WT" >/dev/null 2>&1
    run bash -c "source '$LIB'; fw_branch_hygiene '$WT'"
    [[ ! "$output" =~ "wrong-branch" ]]
    run _hygiene
    [[ "$output" =~ "wrong-branch t9999-stray" ]]
}

# ── Override ─────────────────────────────────────────────────────────────

@test "FW_DEV_BRANCH overrides the expected branch name" {
    git -C "$REPO" checkout -q master
    git -C "$REPO" branch -q other-dev bleeding-edge
    run bash -c "source '$LIB'; FW_DEV_BRANCH=other-dev fw_branch_hygiene '$REPO'"
    [[ "$output" =~ "wrong-branch master expected=other-dev" ]]
}
