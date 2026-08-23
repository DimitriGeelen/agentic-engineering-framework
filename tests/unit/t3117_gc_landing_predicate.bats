#!/usr/bin/env bats
# T-3117: `fw worktree gc` decides "has this landed?" against the right trunk,
# and by the right test.
#
# Two defects, both of which made gc report landed work as unlanded — the
# direction that is safe to be wrong in exactly once, and then never gets
# revisited because "it says there is unlanded work" reads as a good reason to
# leave a worktree alone.
#
#   1. TRUNK. _wt_master_ref preferred refs/heads/master. In the session-on-master
#      flow (T-100196) work lands by pushing HEAD:master from a topic branch,
#      which advances origin/master and never touches the local master branch.
#      Measured in the live repo on 2026-08-23: local master 1744 commits behind.
#      Every landing verdict was computed against a six-week-old trunk.
#
#   2. TEST. _wt_work_landed only ever asked "is every file this branch touched
#      byte-identical on master TODAY?". For a branch whose commits are all in
#      master but which is behind, master has since changed those files again,
#      so the answer is no — and gc printed `unlanded:1440/1442` for a branch
#      git itself calls a strict ancestor.
#
# Together they kept four worktrees unreclaimable for seven weeks — including the
# two whose stale enforcement code produced the duplicate task IDs that R7
# (T-3110..T-3113) was built to prevent. The tool that should have removed them
# was telling the operator they held unlanded work.
#
# The fixture is a real repo with a real remote, because both defects are about
# which *ref* is consulted; a single-repo fixture cannot express the difference.

setup() {
    _FW_ROOT="${FRAMEWORK_ROOT:-/opt/999-Agentic-Engineering-Framework}"
    LIB="$_FW_ROOT/lib/worktree.sh"
    [ -f "$LIB" ] || skip "lib not found: $LIB"

    TEST_ROOT="$(mktemp -d)"
    UPSTREAM="$TEST_ROOT/upstream.git"
    REPO="$TEST_ROOT/repo"

    git init -q --bare "$UPSTREAM"
    git init -q "$REPO"
    git -C "$REPO" config user.email t@t
    git -C "$REPO" config user.name t
    git -C "$REPO" remote add origin "$UPSTREAM"

    echo "v1" > "$REPO/lib.sh"
    git -C "$REPO" add -A
    git -C "$REPO" commit -qm "base"
    git -C "$REPO" branch -M master
    git -C "$REPO" push -q origin master

    # A topic branch with one real deliverable commit...
    git -C "$REPO" checkout -q -b topic
    echo "v2" > "$REPO/lib.sh"
    git -C "$REPO" commit -qam "topic work"

    # ...landed the way this framework lands things: push HEAD to the remote's
    # master. The LOCAL master ref is deliberately left behind, which is the
    # whole point — that is what the session-on-master flow actually does.
    git -C "$REPO" push -q origin topic:master
    git -C "$REPO" fetch -q origin

    # Then master moves on and touches the same file again, so a content
    # comparison against today's trunk cannot recognise the branch's work.
    git -C "$REPO" checkout -q -b later origin/master
    echo "v3" > "$REPO/lib.sh"
    git -C "$REPO" commit -qam "later work"
    git -C "$REPO" push -q origin later:master
    git -C "$REPO" fetch -q origin
    git -C "$REPO" checkout -q topic

    cd "$REPO"
    # shellcheck source=/dev/null
    source "$LIB"
}

teardown() {
    cd /
    [ -n "$TEST_ROOT" ] && rm -rf "$TEST_ROOT"
}

@test "the trunk is the remote-tracking ref, not a stale local master" {
    run _wt_master_ref
    [ "$status" -eq 0 ]
    [ "$output" = "refs/remotes/origin/master" ]
}

@test "the fixture reproduces the stale local master this exists to survive" {
    # Guards the test itself: if local master ever tracked origin/master here,
    # both assertions below would pass for the wrong reason.
    run bash -c "git -C '$REPO' rev-list --count master..origin/master"
    [ "$status" -eq 0 ]
    [ "$output" -gt 0 ]
}

@test "a merged branch is landed even when master has since changed its files" {
    # topic's commit is IN origin/master; lib.sh has since become v3. Content
    # comparison says unlanded, ancestry says merged, and ancestry is right.
    run _wt_work_landed refs/heads/topic refs/remotes/origin/master
    [ "$status" -eq 0 ]
    [ "$output" = "merged" ]
}

@test "the same branch measured against the stale local master is NOT trusted as landed" {
    # The pre-fix behaviour, pinned so the regression is visible rather than
    # theoretical: consult the wrong ref and the answer flips.
    run _wt_work_landed refs/heads/topic refs/heads/master
    [ "$status" -eq 1 ]
    [[ "$output" == unlanded:* ]]
}

@test "a branch with genuinely unlanded deliverables is still kept" {
    git -C "$REPO" checkout -q -b unlanded origin/master
    echo "not pushed anywhere" > "$REPO/lib.sh"
    git -C "$REPO" commit -qam "unlanded work"
    run _wt_work_landed refs/heads/unlanded refs/remotes/origin/master
    [ "$status" -eq 1 ]
    [[ "$output" == unlanded:* ]]
}

@test "a branch touching only ignorable paths still reports no-deliverables" {
    # The ancestry short-circuit runs first, so this only fires for branches
    # that are NOT ancestors — otherwise the pre-existing reason token would be
    # silently replaced by "merged" and the distinction would be lost.
    git -C "$REPO" checkout -q -b churn origin/master
    mkdir -p "$REPO/.context/working"
    echo "session state" > "$REPO/.context/working/session.yaml"
    git -C "$REPO" add -A
    git -C "$REPO" commit -qm "churn only"
    run _wt_work_landed refs/heads/churn refs/remotes/origin/master
    [ "$status" -eq 0 ]
    [ "$output" = "no-deliverables" ]
}

@test "ancestry never overrides an unrelated history" {
    git -C "$REPO" checkout -q --orphan orphan
    git -C "$REPO" rm -rq --cached . 2>/dev/null || true
    echo "unrelated" > "$REPO/other.txt"
    git -C "$REPO" add other.txt
    git -C "$REPO" commit -qm "orphan"
    run _wt_work_landed refs/heads/orphan refs/remotes/origin/master
    [ "$status" -eq 2 ]
    [ "$output" = "no-merge-base" ]
}

@test "a local-only repo with no remote still resolves a trunk" {
    # The fallback that keeps this usable outside a push-based flow.
    local solo="$TEST_ROOT/solo"
    git init -q "$solo"
    git -C "$solo" config user.email t@t
    git -C "$solo" config user.name t
    echo x > "$solo/f"
    git -C "$solo" add -A
    git -C "$solo" commit -qm base
    git -C "$solo" branch -M master
    run bash -c "cd '$solo' && source '$LIB' && _wt_master_ref"
    [ "$status" -eq 0 ]
    [ "$output" = "refs/heads/master" ]
}
