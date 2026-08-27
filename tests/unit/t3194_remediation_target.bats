#!/usr/bin/env bats
# T-3194: the ADVICE has to point at the branch the MEASUREMENT used.
#
# T-3188 retargeted branch hygiene's comparand to the dev branch but left every
# remediation string naming a literal `master`. Under the release train master
# is older than bleeding-edge between releases, so the advice printed with each
# finding told the operator to merge the older tree into the newer one — a
# remediation that undoes what the finding just detected. The handover nudge is
# the sharpest case: it is what SessionStart injects, so the next agent reads it
# as an instruction carrying the framework's own authority.
#
# Every "no longer says master" assertion is paired with one asserting the
# retargeted string IS present. Deleting the advice satisfies the first alone,
# and silence is not the outcome we want.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    REPO="$TEST_TEMP_DIR/repo"
    mkdir -p "$REPO"
    git -C "$REPO" init -q -b master
    git -C "$REPO" config user.email t@t.t
    git -C "$REPO" config user.name t
    echo base > "$REPO/f"; git -C "$REPO" add f; git -C "$REPO" commit -qm c1
    LIB="$FRAMEWORK_ROOT/lib/branch-hygiene.sh"
    FW="$FRAMEWORK_ROOT/bin/fw"
    AUDIT="$FRAMEWORK_ROOT/agents/audit/audit.sh"
    HANDOVER="$FRAMEWORK_ROOT/agents/handover/handover.sh"
}

teardown() { rm -rf "$TEST_TEMP_DIR"; }

_devname() { run bash -c "source '$LIB'; _fw_bh_dev_name '$REPO'"; }

# ── the shared resolver ──────────────────────────────────────────────────────

@test "T-3194: _fw_bh_dev_name returns the dev branch when it exists locally" {
    git -C "$REPO" branch -q bleeding-edge master
    _devname
    [ "$output" = "bleeding-edge" ]
}

@test "T-3194: control — _fw_bh_dev_name falls back to master when no dev branch exists" {
    # Without this leg the test above passes for a function that returns the
    # literal string 'bleeding-edge' and never looks at the repo at all.
    _devname
    [ "$output" = "master" ]
}

@test "T-3194: _fw_bh_dev_name honours FW_DEV_BRANCH, so a consumer gets ITS name" {
    git -C "$REPO" branch -q trunk-next master
    run bash -c "source '$LIB'; FW_DEV_BRANCH=trunk-next _fw_bh_dev_name '$REPO'"
    [ "$output" = "trunk-next" ]
}

@test "T-3194: control — FW_DEV_BRANCH naming a nonexistent branch falls back to master" {
    run bash -c "source '$LIB'; FW_DEV_BRANCH=nope _fw_bh_dev_name '$REPO'"
    [ "$output" = "master" ]
}

@test "T-3194: a remote-only dev branch resolves (fresh clone, no local ref)" {
    UP="$TEST_TEMP_DIR/up.git"; git init -q --bare "$UP"
    git -C "$REPO" remote add origin "$UP"
    git -C "$REPO" push -q origin master
    git -C "$REPO" checkout -q -b bleeding-edge
    echo d > "$REPO/d"; git -C "$REPO" add d; git -C "$REPO" commit -qm c2
    git -C "$REPO" push -q origin bleeding-edge
    CLONE="$TEST_TEMP_DIR/clone"; git clone -q "$UP" "$CLONE"
    run bash -c "source '$LIB'; _fw_bh_dev_name '$CLONE'"
    [ "$output" = "bleeding-edge" ]
}

# ── fw_go_live: it MERGES, so the target is behaviour, not just prose ────────

@test "T-3194: fw_go_live reports against the dev branch, not origin/master" {
    UP="$TEST_TEMP_DIR/up.git"; git init -q --bare "$UP"
    git -C "$REPO" remote add origin "$UP"
    git -C "$REPO" push -q origin master
    git -C "$REPO" checkout -q -b bleeding-edge
    git -C "$REPO" push -q origin bleeding-edge
    run bash -c "source '$LIB'; fw_go_live '$REPO' 2>&1"
    [[ "$output" == *"origin/bleeding-edge"* ]]
    [[ "$output" != *"origin/master"* ]]
}

@test "T-3194: control — with no dev branch fw_go_live still reports origin/master" {
    UP="$TEST_TEMP_DIR/up.git"; git init -q --bare "$UP"
    git -C "$REPO" remote add origin "$UP"
    git -C "$REPO" push -q origin master
    run bash -c "source '$LIB'; fw_go_live '$REPO' 2>&1"
    [[ "$output" == *"origin/master"* ]]
}

@test "T-3194: fw_go_live no longer tells anyone to land on master" {
    run bash -c "grep -n \"integrate run master --push\" '$LIB'"
    [ "$status" -ne 0 ]
}

@test "T-3194: control — fw_go_live still gives the one-way landing advice" {
    # Pairs with the assertion above: deleting the advice line entirely would
    # satisfy a bare 'no integrate run master' grep just as well as fixing it.
    run bash -c "grep -c 'integrate run \$_gl_dev --push' '$LIB'"
    [ "$status" -eq 0 ]
    [ "$output" -ge 1 ]
}

# ── the three printing surfaces ─────────────────────────────────────────────

@test "T-3194: doctor's hygiene remediation interpolates the resolved name" {
    run bash -c "grep -c '_bh_devname' '$FW'"
    [ "$status" -eq 0 ]
    [ "$output" -ge 2 ]
}

@test "T-3194: doctor's FORK advice no longer hard-codes origin/master" {
    run bash -c "grep -n 'git merge origin/master' '$FW' | grep -v '^[0-9]*: *#'"
    [ "$status" -ne 0 ]
}

@test "T-3194: control — doctor still prints FORK advice at all" {
    run bash -c "grep -c 'diverged-fork branch is BOTH ahead and behind' '$FW'"
    [ "$status" -eq 0 ]
    [ "$output" -ge 1 ]
}

@test "T-3194: audit's hygiene mitigation interpolates the resolved name" {
    run bash -c "grep -c '_bh_devname' '$AUDIT'"
    [ "$status" -eq 0 ]
    [ "$output" -ge 2 ]
}

@test "T-3194: audit's FORK mitigation no longer hard-codes origin/master" {
    run bash -c "grep -n 'merge origin/master INTO the branch' '$AUDIT'"
    [ "$status" -ne 0 ]
}

@test "T-3194: control — audit still names the do-NOT-integrate-a-fork rule (T-100194)" {
    # The T-100194 lesson must survive the retargeting, not be lost with it.
    run bash -c "grep -c 'Do NOT use fw integrate on a fork' '$AUDIT'"
    [ "$status" -eq 0 ]
    [ "$output" -ge 1 ]
}

@test "T-3194: the handover nudge interpolates the resolved name" {
    run bash -c "grep -c '_bd_devname' '$HANDOVER'"
    [ "$status" -eq 0 ]
    [ "$output" -ge 3 ]
}

@test "T-3194: the handover nudge no longer tells the next session to land on master" {
    run bash -c "grep -n 'integrate run master --push' '$HANDOVER'"
    [ "$status" -ne 0 ]
}

@test "T-3194: control — the handover nudge still exists in both arms" {
    run bash -c "grep -c 'MERGEBACK_NUDGE=' '$HANDOVER'"
    [ "$status" -eq 0 ]
    [ "$output" -ge 2 ]
}

# ── syntax (L-408) ──────────────────────────────────────────────────────────

@test "T-3194: all four edited files parse" {
    run bash -n "$FW";       [ "$status" -eq 0 ]
    run bash -n "$AUDIT";    [ "$status" -eq 0 ]
    run bash -n "$HANDOVER"; [ "$status" -eq 0 ]
    run bash -n "$LIB";      [ "$status" -eq 0 ]
}
