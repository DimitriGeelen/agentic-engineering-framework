#!/usr/bin/env bats
# T-3188: under the release train, "landed" means landed on the DEV branch.
#
# lib/branch-hygiene.sh judged every branch against origin/master. That was
# right while master was the trunk. Under T-3185 master only fast-forwards at
# a release, so between releases it lags ON PURPOSE — and the old target turns
# that deliberate lag into a finding, while reporting branches that HAVE landed
# on bleeding-edge as unlanded.
#
# Same control-leg discipline as T-3187: every "produces no finding" assertion
# is paired with one that fires over the same fixture, because a rail that went
# quiet for the right reason and a rail that went blind look identical.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    REPO="$TEST_TEMP_DIR/repo"
    UP="$TEST_TEMP_DIR/up.git"
    git init -q --bare "$UP"
    mkdir -p "$REPO"
    git -C "$REPO" init -q -b master
    git -C "$REPO" config user.email t@t.t
    git -C "$REPO" config user.name t
    git -C "$REPO" remote add origin "$UP"
    echo base > "$REPO/f"; git -C "$REPO" add f; git -C "$REPO" commit -qm "c1"
    git -C "$REPO" push -q origin master

    # The release-train shape: bleeding-edge ahead of master, master NOT yet
    # fast-forwarded. This is the normal between-releases state.
    git -C "$REPO" checkout -q -b bleeding-edge
    echo dev > "$REPO/f2"; git -C "$REPO" add f2; git -C "$REPO" commit -qm "c2: landed work"
    git -C "$REPO" push -q origin bleeding-edge
    git -C "$REPO" fetch -q origin

    LIB="$FRAMEWORK_ROOT/lib/branch-hygiene.sh"
}

teardown() { rm -rf "$TEST_TEMP_DIR"; }

_hygiene()    { run bash -c "source '$LIB'; fw_branch_hygiene '$REPO'" 2>/dev/null; }
_divergence() { run bash -c "source '$LIB'; fw_branch_divergence '$REPO'" 2>/dev/null; }

# ── master's lag is the product, not drift ───────────────────────────────

@test "a branch landed on the dev branch but NOT on master counts as landed" {
    # THE discriminator. landed-feature sits at c2: an ancestor of
    # bleeding-edge, not of master. Judged against the dev branch it is merged;
    # judged against master it is not. Any fixture where the branch is an
    # ancestor of both cannot tell the two targets apart — which is exactly how
    # the first version of this suite passed with the target reverted.
    git -C "$REPO" branch -q landed-feature HEAD
    _hygiene
    [[ "$output" =~ "merged-undeleted landed-feature" ]]
}

@test "the dev branch is never reported as unlanded — it is the trunk" {
    _hygiene
    [[ ! "$output" =~ "behind-threshold bleeding-edge" ]]
    [[ ! "$output" =~ "merged-undeleted bleeding-edge" ]]
}

@test "CONTROL LEG: master's own lag is not reported as a finding" {
    # Pairs with the test above: the same scan that recognises landed-feature
    # says nothing about master, whose lag is the release train's product.
    git -C "$REPO" branch -q landed-feature HEAD
    _hygiene
    [[ "$output" =~ "merged-undeleted landed-feature" ]]
    [[ ! "$output" =~ "master" ]]
}

@test "CONTROL LEG: a genuinely unlanded branch still fires" {
    git -C "$REPO" checkout -q -b real-feature
    echo x > "$REPO/f3"; git -C "$REPO" add f3; git -C "$REPO" commit -qm "unlanded"
    git -C "$REPO" checkout -q bleeding-edge
    _hygiene
    [[ ! "$output" =~ "merged-undeleted real-feature" ]]
}

# ── divergence: neutral on the branch the session belongs on ─────────────

@test "divergence is SILENT on the dev branch" {
    _divergence
    [ -z "$output" ]
}

@test "CONTROL LEG: divergence fires on a feature branch over the same fixture" {
    git -C "$REPO" checkout -q -b side
    echo y > "$REPO/f4"; git -C "$REPO" add f4; git -C "$REPO" commit -qm "side work"
    _divergence
    [[ "$output" =~ "divergence side ahead=1" ]]
}

@test "divergence measures against the DEV branch, not master" {
    # side branches from bleeding-edge, so it is 0 behind the dev branch but
    # would be 1 behind master. The number discriminates the target.
    git -C "$REPO" checkout -q -b side
    echo y > "$REPO/f4"; git -C "$REPO" add f4; git -C "$REPO" commit -qm "side work"
    _divergence
    [[ "$output" =~ "behind=0" ]]
}

# ── fallback: master-only consumers are untouched ────────────────────────

@test "FALLBACK: a repo with no dev branch still judges against master" {
    git -C "$REPO" checkout -q master
    git -C "$REPO" push -q origin --delete bleeding-edge
    git -C "$REPO" branch -q -D bleeding-edge
    git -C "$REPO" fetch -q --prune origin
    git -C "$REPO" branch -q old-feature
    _hygiene
    [[ "$output" =~ "merged-undeleted old-feature" ]]
}

@test "FALLBACK CONTROL LEG: without a dev branch, the SAME branch stops counting as landed" {
    # Pairs with the discriminator test. A branch at c2 is merged when judged
    # against bleeding-edge. Remove the dev branch and the target falls back to
    # master, which c2 is NOT an ancestor of — so the verdict must flip.
    git -C "$REPO" branch -q landed-feature HEAD
    git -C "$REPO" checkout -q master
    git -C "$REPO" push -q origin --delete bleeding-edge
    git -C "$REPO" branch -q -D bleeding-edge
    git -C "$REPO" fetch -q --prune origin
    _hygiene
    [[ ! "$output" =~ "merged-undeleted landed-feature" ]]
}

@test "FW_DEV_BRANCH overrides the dev branch name" {
    git -C "$REPO" branch -q -m bleeding-edge trunk
    git -C "$REPO" push -q origin trunk
    git -C "$REPO" fetch -q origin
    run bash -c "source '$LIB'; FW_DEV_BRANCH=trunk fw_branch_divergence '$REPO'"
    [ -z "$output" ]
}

@test "FW_DEV_BRANCH CONTROL LEG: without the override the same checkout is NOT silent" {
    git -C "$REPO" branch -q -m bleeding-edge trunk
    git -C "$REPO" push -q origin trunk
    git -C "$REPO" fetch -q origin
    _divergence
    [[ "$output" =~ "divergence trunk" ]]
}
