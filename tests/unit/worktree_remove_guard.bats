#!/usr/bin/env bats
# T-2829 / OBS-177 — `fw worktree remove`'s strand guard must ask
# "is any commit here on NO remote?", not "is origin/<branch> caught up?".
#
# Both directions are pinned, plus the undecidable case. The landed-onto-master
# direction is the regression: under the T-100196 flow work FF-lands onto master,
# so origin/<branch> is stale or absent while every commit sits on origin/master.
# The old predicate read that as unlanded and refused, which made --force routine
# — reinstating the exact bypass habit the guard exists to prevent.

setup() {
    REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
    TDIR="$(mktemp -d)"

    # A bare "remote" plus a working clone, so remote-tracking refs are real.
    git init -q --bare "$TDIR/remote.git"
    git init -q "$TDIR/work"
    cd "$TDIR/work" || return 1
    git config user.email t@localhost; git config user.name t
    git remote add origin "$TDIR/remote.git"
    echo base > base.txt; git add base.txt
    git commit -q -m "base"
    git branch -M master
    git push -q origin master

    # LANDED-ONTO-MASTER: commits authored on a side branch, FF-landed onto
    # master and pushed. origin/<branch> never exists.
    git checkout -q -b landed-branch
    echo work > landed.txt; git add landed.txt; git commit -q -m "landed work"
    git push -q origin landed-branch:master
    git fetch -q origin

    # GENUINELY STRANDED: commit on a branch, pushed nowhere at all.
    git checkout -q master
    git checkout -q -b stranded-branch
    echo lost > stranded.txt; git add stranded.txt; git commit -q -m "stranded work"

    git checkout -q master
    # shellcheck disable=SC1090
    source "$REPO_ROOT/lib/worktree.sh"
}

teardown() {
    cd / || true
    [ -n "${TDIR:-}" ] && rm -rf "$TDIR"
}

@test "landed onto master: guard ALLOWS removal even though origin/<branch> does not exist" {
    # Precondition — assert the situation the test is about actually holds,
    # otherwise a green here proves nothing (T-2828 vacuous-control lesson).
    run git rev-parse --verify --quiet refs/remotes/origin/landed-branch
    [ "$status" -ne 0 ]                       # origin/<branch> genuinely absent
    run git rev-list --count origin/master..landed-branch
    [ "$output" = "0" ]                       # yet fully landed on master

    run _wt_unpushed_summary landed-branch
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "genuinely stranded: guard REFUSES and names the count" {
    run git rev-list --count stranded-branch --not --remotes
    [ "$output" = "1" ]                       # precondition: really is stranded

    run _wt_unpushed_summary stranded-branch
    [ "$status" -eq 1 ]
    [[ "$output" == *"1 commit(s)"* ]]
    [[ "$output" == *"no remote"* ]]
}

@test "undecidable (branch does not resolve): guard REFUSES rather than allowing" {
    # A worktree DIRECTORY name is not always its branch name — in the live repo
    # .claude/worktrees/rca-worktree-push-strand is on branch
    # worktree-rca-worktree-push-strand. Passing the wrong name made `rev-list`
    # print nothing, and a `${x:-0}` default turned that silence into "0 stranded
    # => safe to remove". Empty for two different reasons, read as one.
    run _wt_unpushed_summary no-such-branch-anywhere
    [ "$status" -eq 1 ]
    [[ "$output" == *"does not resolve"* ]]
}

@test "no remotes configured: guard REFUSES (cannot verify anything is pushed)" {
    git remote remove origin
    run _wt_unpushed_summary landed-branch
    [ "$status" -eq 1 ]
    [[ "$output" == *"no git remotes"* ]]
}

@test "the implementation asks the reachability question, not the origin/<branch> question" {
    # Source-level pin: the old predicate used ONLY `<remote_ref>..<branch>` to
    # decide. That form survives in the diagnostic detail (it is genuinely useful
    # there), so assert the deciding call exists rather than that the old form is
    # absent.
    #
    # HONEST LIMIT — this test does NOT discriminate. Measured: under the T-2829
    # mutation (deciding line reverted to origin/<branch>) it stays green, because
    # the phrase still occurs in the diagnostic message string. It documents
    # intent; test 1 is what actually guards the behaviour. Recorded rather than
    # deleted so nobody later reads its green as evidence — a presence-grep that
    # looks like a behavioural assertion is the T-2726 unwitnessable class.
    run grep -c -- '--not --remotes' "${BATS_TEST_DIRNAME}/../../lib/worktree.sh"
    [ "$output" -ge 1 ]
}
