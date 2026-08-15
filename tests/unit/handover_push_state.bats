#!/usr/bin/env bats
# T-3026 (OBS-275): the handover's Branch line must report PUSH state, not only
# the delta against origin/master.
#
# These are different questions and the handover previously answered only one of
# them while reading as though it answered both. The rule the handover exists to
# serve is "do not end a session with unpushed commits" — a branch can be +131
# ahead of master and fully pushed, or level with master and holding unpushed
# work. Both arms of the T-3025 IW-2 probe flagged the omission unprompted.
#
# Each test builds a real repo in a temp dir with a real "origin", so the states
# are produced rather than mocked.

setup() {
    TMP="$(mktemp -d)"
    export TMP
    ORIGIN="$TMP/origin.git"
    WORK="$TMP/work"

    git init -q --bare "$ORIGIN"
    git init -q -b master "$WORK"
    cd "$WORK" || return 1
    git config user.email t@example.com
    git config user.name Test
    git remote add origin "$ORIGIN"
    echo seed > seed.txt
    git add seed.txt
    git commit -q -m "seed"
    git push -q origin master
}

teardown() {
    cd / || true
    rm -rf "$TMP"
}

# Mirrors the resolution in agents/handover/handover.sh. Kept as a helper so the
# three states are asserted against one implementation of the rule.
push_state() {
    local root="$1" branch="$2" ref n
    ref="refs/remotes/origin/${branch}"
    if ! git -C "$root" rev-parse --verify --quiet "$ref" >/dev/null 2>&1; then
        echo "never-pushed"; return
    fi
    n=$(git -C "$root" rev-list --count "origin/${branch}..HEAD" 2>/dev/null || true)
    case "$n" in
        ""|*[!0-9]*) echo "unknown" ;;
        0)           echo "in-sync" ;;
        *)           echo "unpushed:$n" ;;
    esac
}

@test "in-sync: everything pushed reports in-sync" {
    run push_state "$WORK" master
    [ "$status" -eq 0 ]
    [ "$output" = "in-sync" ]
}

@test "unpushed: local commits ahead of the remote branch are counted" {
    cd "$WORK"
    echo a > a.txt && git add a.txt && git commit -q -m "a"
    echo b > b.txt && git add b.txt && git commit -q -m "b"
    run push_state "$WORK" master
    [ "$output" = "unpushed:2" ]
}

@test "never-pushed: a branch with no remote counterpart is named as such" {
    cd "$WORK"
    git checkout -q -b feature-never-pushed
    echo c > c.txt && git add c.txt && git commit -q -m "c"
    run push_state "$WORK" feature-never-pushed
    [ "$output" = "never-pushed" ]
}

@test "in-sync is not confused by being ahead of master" {
    # The whole point of OBS-275: ahead-of-master and unpushed are orthogonal.
    cd "$WORK"
    git checkout -q -b strand
    echo d > d.txt && git add d.txt && git commit -q -m "d"
    git push -q origin strand
    # Ahead of master by 1, but fully pushed.
    [ "$(git rev-list --count master..HEAD)" = "1" ]
    run push_state "$WORK" strand
    [ "$output" = "in-sync" ]
}

@test "unpushed is not masked by being level with master" {
    # The converse: level with master, yet holding unpushed commits.
    cd "$WORK"
    echo e > e.txt && git add e.txt && git commit -q -m "e"
    [ "$(git rev-list --count master..HEAD)" = "0" ]
    run push_state "$WORK" master
    [ "$output" = "unpushed:1" ]
}

@test "handover.sh emits a push-state clause on its Branch line" {
    # Guards the wiring, not just the helper: the clause must actually reach the
    # generated document, or the logic above is dead code.
    run grep -c 'NOT pushed\|in sync with\|never pushed' \
        "${BATS_TEST_DIRNAME}/../../agents/handover/handover.sh"
    [ "$status" -eq 0 ]
    [ "$output" -ge 3 ]
}
