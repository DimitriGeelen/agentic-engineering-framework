#!/usr/bin/env bats
# T-3197 — lib/worktree.sh must resolve the TRUNK through FW_DEV_BRANCH.
#
# Under the release train (T-3185) `master` is the consumer install surface and
# fast-forwards only at a release. It is no longer the trunk. Two consequences,
# and this file had both wrong:
#
#   create:  a worktree branched from master starts behind the dev branch, so
#            `fw integrate check` sees an old merge-base and reports both-sided
#            files that are not genuinely both-sided.
#   merged?: work landed via `fw integrate run bleeding-edge` is not in master
#            until the next release, so the landed test answered "no" for a
#            branch that is fully landed — while lib/branch-hygiene.sh:100 (which
#            already reads FW_DEV_BRANCH since T-3188) answered "yes" about the
#            same branch. Two rails, one branch, opposite verdicts.
#
# THE FIXTURE PUTS master AND bleeding-edge AT DIFFERENT COMMITS, and that is the
# whole design. If both refs pointed at the same commit every assertion below
# would pass against the UNFIXED code too: "branched from the dev branch" and
# "branched from master" are the same observation when the refs agree. A green
# suite on such a fixture is the false green this task exists to remove.
#
# The control legs (`fallback`, `master-only repo`) are equally load-bearing:
# "resolves the dev branch" and "ignores master entirely" produce an identical
# diff, and only the paired opposite assertion separates them.
#
# Note on worktrees: the operator directive is that worktrees are opt-in for
# real work. These create one inside a throwaway fixture repo under $BATS_TMPDIR
# purely to exercise the code under test — no worktree is created in this repo.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    REPO="$TEST_TEMP_DIR/trunk-repo"
    mkdir -p "$REPO"
    cd "$REPO" || return 1

    git init -q -b master .
    git config user.email t3197@test
    git config user.name t3197
    git config commit.gpgsign false

    # --- master: the release point. Deliberately BEHIND. -------------------
    echo "released" > released.txt
    git add -A && git commit -qm "release commit on master"
    MASTER_SHA="$(git rev-parse HEAD)"
    export MASTER_SHA

    # --- bleeding-edge: two commits of unreleased dev work ------------------
    git checkout -q -b bleeding-edge
    echo "dev1" > dev1.txt
    git add -A && git commit -qm "unreleased dev work 1"
    echo "dev2" > dev2.txt
    git add -A && git commit -qm "unreleased dev work 2"
    DEV_SHA="$(git rev-parse HEAD)"
    export DEV_SHA

    # The premise every assertion below rests on. Assert it rather than assume
    # it: a fixture that silently collapsed to one commit would make the whole
    # file vacuous while still printing green.
    [ "$MASTER_SHA" != "$DEV_SHA" ]

    source "$FRAMEWORK_ROOT/lib/worktree.sh"
}

# ---- resolution ----------------------------------------------------------

@test "T-3197: _wt_dev_ref resolves the dev branch, not master" {
    run _wt_dev_ref
    [ "$status" -eq 0 ]
    [ "$output" = "refs/heads/bleeding-edge" ]
    [ "$(git rev-parse "$output")" = "$DEV_SHA" ]
}

@test "T-3197: FW_DEV_BRANCH names the trunk" {
    git checkout -q -b staging
    echo s > s.txt && git add -A && git commit -qm "staging work"
    local staging_sha; staging_sha="$(git rev-parse HEAD)"
    git checkout -q bleeding-edge

    FW_DEV_BRANCH=staging run _wt_dev_ref
    [ "$status" -eq 0 ]
    [ "$output" = "refs/heads/staging" ]
    [ "$(git rev-parse "$output")" = "$staging_sha" ]
}

# ---- control leg: the fallback must survive ------------------------------

@test "T-3197/control: a repo with no dev branch still resolves master" {
    # Strictly a widening, not a swap. A consumer that never adopted the
    # release train must behave exactly as it did before this change.
    git checkout -q master
    git branch -q -D bleeding-edge

    run _wt_dev_ref
    [ "$status" -eq 0 ]
    [ "$output" = "refs/heads/master" ]
    [ "$(git rev-parse "$output")" = "$MASTER_SHA" ]
}

@test "T-3197/control: _wt_master_ref is untouched and still means master" {
    # The old helper keeps its old meaning — the master-lock reporting in
    # `fw worktree status` genuinely is about master and must not drift.
    run _wt_master_ref
    [ "$status" -eq 0 ]
    [ "$output" = "refs/heads/master" ]
}

# ---- create --------------------------------------------------------------

@test "T-3197: worktree create branches from the dev branch, not master" {
    run do_worktree_create wt1
    [ "$status" -eq 0 ]

    # The branch point is the assertion. Under the old code this equals
    # MASTER_SHA and the new worktree starts two commits behind.
    local head; head="$(git rev-parse refs/heads/worktree-wt1)"
    [ "$head" = "$DEV_SHA" ]
    [ "$head" != "$MASTER_SHA" ]

    # And the unreleased work is actually present in the checkout.
    [ -f "$REPO/.claude/worktrees/wt1/dev2.txt" ]
}

@test "T-3197: --from still overrides the resolved trunk" {
    run do_worktree_create wt2 --from master
    [ "$status" -eq 0 ]
    [ "$(git rev-parse refs/heads/worktree-wt2)" = "$MASTER_SHA" ]
}

# ---- merged? / landed ----------------------------------------------------

@test "T-3197: a branch landed on the dev branch reads merged, before any release" {
    # THE defect in its observable form: work merged into bleeding-edge but not
    # yet released. Under the old code this reported not-merged for as long as
    # the release train deliberately lags — which is always, between releases.
    #
    # This drives do_worktree_status, the real CONSUMER. An earlier cut called
    # `_wt_work_landed ... "$(_wt_dev_ref)"` — passing the resolved ref in by
    # hand, which tests the helper and says nothing about whether the consumer
    # uses it. Mutation M2 (consumer reverted to _wt_master_ref) left that
    # version green; only the source-level grep noticed, and by accident.
    git checkout -q -b feature bleeding-edge
    echo f > f.txt && git add -A && git commit -qm "feature work"
    git checkout -q bleeding-edge
    git merge -q --no-ff -m "land feature" feature

    # A real linked worktree on the landed branch, so status has something to
    # report a merged? verdict about.
    git worktree add -q "$TEST_TEMP_DIR/wt-feature" feature

    run do_worktree_status --json
    [ "$status" -eq 0 ]

    # The trunk the consumer actually measured against.
    echo "$output" | grep -q '"trunk_ref": "refs/heads/bleeding-edge"'
    [[ "$output" != *'"trunk_ref": "refs/heads/master"'* ]]

    # And the verdict that trunk produces for landed-but-unreleased work.
    python3 -c '
import json,sys
d=json.load(sys.stdin)
wts=d["linked_worktrees"]
row=[w for w in wts if w.get("branch")=="feature"]
assert row, "feature worktree not reported: %r" % (wts,)
assert row[0].get("merged")=="yes", "landed-on-dev branch reported merged=%r" % row[0].get("merged")
' <<<"$output"

    # Control: it is genuinely NOT in master, so the old answer was measuring
    # a real fact — just not the one the question asks.
    run git merge-base --is-ancestor refs/heads/feature refs/heads/master
    [ "$status" -ne 0 ]
}

@test "T-3197/control: unlanded work is still reported unlanded" {
    # The dangerous direction. Widening what counts as the trunk must not make
    # everything look landed — gc surfaces reclaim candidates off this verdict.
    git checkout -q -b orphan bleeding-edge
    echo o > o.txt && git add -A && git commit -qm "never landed anywhere"
    git checkout -q bleeding-edge

    run _wt_work_landed refs/heads/orphan "$(_wt_dev_ref)"
    [ "$status" -ne 0 ]
}

# ---- gc must not eat the trunk ------------------------------------------

@test "T-3197: gc does not offer the dev branch itself as a reclaim candidate" {
    # Once "landed" is measured against the dev branch, the dev branch is
    # trivially an ancestor of itself — so without an explicit skip it becomes a
    # reclaim candidate and gc hands the operator `git branch -D bleeding-edge`.
    # That is a hazard this task's own widening INTRODUCES, which is why the
    # skip and this test ship in the same commit as the widening.
    #
    # The main checkout must be on some OTHER branch. gc's second loop only
    # considers branches with no worktree, so while bleeding-edge is the
    # checked-out branch it is skipped for an unrelated reason and the test
    # passes whether or not the fix is present — measured: mutation M3 reddened
    # nothing against the first cut of this fixture.
    git checkout -q master

    run do_worktree_gc
    [ "$status" -eq 0 ]

    # Verbatim strings from the real renderer, captured off a live probe rather
    # than guessed — the first cut asserted on invented pipe-delimited rows that
    # gc never emits, so it could not have failed.
    [[ "$output" != *"RECLAIM branch    bleeding-edge"* ]]
    [[ "$output" != *"git branch -D bleeding-edge"* ]]
    echo "$output" | grep -q "Summary: 0 reclaimable"
}

# ---- source-level --------------------------------------------------------

@test "T-3197: worktree.sh is syntactically valid and the trunk helper is shared" {
    bash -n "$FRAMEWORK_ROOT/lib/worktree.sh"
    # definition + status + gc + create (4 or more references)
    run grep -c "_wt_dev_ref" "$FRAMEWORK_ROOT/lib/worktree.sh"
    [ "$output" -ge 4 ]
}

@test "T-3197: gc reclaims work landed on the dev branch, before any release" {
    # The gc half of the fix, and the one that pays for it. Under master
    # semantics a branch merged into bleeding-edge is "unlanded" until the next
    # release, so gc reclaims nothing for the entire inter-release window —
    # which is the observable state this repo was in (22 branch-hygiene
    # findings, several of them merged-undeleted).
    #
    # Mutation M2b (gc's trunk reverted to _wt_master_ref) reddened NOTHING
    # against the first cut of this file: the neighbouring gc test only asserts
    # that the trunk is NOT reclaimed, which stays true under either resolution.
    # An assertion that gc DOES reclaim is what separates them.
    git checkout -q -b landed-feature bleeding-edge
    echo lf > lf.txt && git add -A && git commit -qm "feature to be landed"
    git checkout -q bleeding-edge
    git merge -q --no-ff -m "land landed-feature" landed-feature
    git checkout -q master

    run do_worktree_gc
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "RECLAIM branch    landed-feature"
    [[ "$output" != *"Summary: 0 reclaimable"* ]]
}
