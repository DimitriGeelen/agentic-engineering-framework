#!/usr/bin/env bats
# T-3511 (OBS-547 prevention leg): a merge of a deliberately-parked branch is refused.
#
# END-TO-END BY CONSTRUCTION. Every test below runs the REAL installer into a
# synthetic consumer repo and then a REAL `git merge`. Asserting the guard script
# in isolation would prove the predicate and say nothing about whether git ever
# calls it — and "the gate is written" vs "the gate is reachable where it matters"
# are independent facts that look identical from inside the repo (L-573, measured
# on check-onboarding-gate: 38 green legs, 0 consumers).
#
# The shape matrix is measured, not assumed (git 2.43.0):
#   clean merge commit  -> pre-merge-commit fires   -> REFUSED   (the incident's shape)
#   conflicted merge    -> pre-commit fires later   -> REFUSED
#   --squash            -> pre-commit, no MERGE_HEAD-> allowed + NOTE
#   fast-forward        -> no pre-* hook at all     -> allowed  (pinned as a KNOWN gap)
#
# The fast-forward test asserts the gap deliberately. A known hole that is pinned
# stays visible when someone widens the guard later; an unpinned one gets
# rediscovered as an incident.

load ../test_helper

setup() {
    # HERMETICITY: git's own env vars leak a DIFFERENT repo into every git call in
    # this suite. With GIT_DIR/GIT_WORK_TREE inherited, `fw git install-hooks`
    # resolves the hooks dir to the caller's repo, sees the current version already
    # installed, short-circuits, and writes nothing to the fixture — so the tests
    # assert against hooks that were never installed.
    #
    # Found the hard way: this suite passed 13/13 interactively and failed inside
    # the P-011 close gate, which runs verification from a context that has those
    # vars set. L-606/L-645 extended — hermeticity is not only about the subject's
    # write-set, it is also about the env the harness inherits.
    unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY \
          GIT_COMMON_DIR GIT_PREFIX GIT_REFLOG_ACTION
    TEST_TEMP_DIR="$(mktemp -d)"
    REPO="$TEST_TEMP_DIR/consumer"
    mkdir -p "$REPO/.tasks/active"
    git -C "$REPO" init -q -b master
    git -C "$REPO" config user.email t@t.t
    git -C "$REPO" config user.name t
    printf 'framework_path: %s\n' "$FRAMEWORK_ROOT" > "$REPO/.framework.yaml"
    echo base > "$REPO/f"
    _commit_all "T-3511: base"
    _install_hooks
}

teardown() {
    rm -rf "$TEST_TEMP_DIR"
}

# Never let the live repo's framework state leak into the fixture. L-645: a suite
# that runs against the live repo rewrote focus.yaml to T-001 within seconds and
# blocked the parent session's every edit until it finished.
_fw() {
    # PROJECT_ROOT is the one that actually mattered, and it took two wrong
    # diagnoses to find. The P-011 close gate exports it, so `fw git install-hooks`
    # resolved the hooks dir to the LIVE repo, found the version it had just
    # installed there, printed "Hooks already installed (version 1.16)" and wrote
    # NOTHING to the fixture — rc=0, so nothing looked wrong. Tests 1 and 2 then
    # asserted against hooks that were never installed.
    #
    # Same class as the T-3499 verb-counter incident the day before: an inherited
    # path variable silently re-points a test at the live repo, and `bin/fw` prefers
    # the env over the cwd. Unset every path variable, not the ones you remember.
    ( cd "$REPO" && env -u CLAUDE_PROJECT_DIR -u PROJECT_ROOT -u TASKS_DIR \
        -u CONTEXT_DIR -u _FW_PATHS_DERIVED_BY -u _FW_PATHS_LOADED \
        -u FW_SWITCH_FOCUS \
        "$FRAMEWORK_ROOT/bin/fw" "$@" )
}

_install_hooks() {
    # Assert the install actually wrote, rather than trusting rc=0. The
    # short-circuit path ("Hooks already installed") also exits 0, so the return
    # code cannot distinguish "installed" from "decided not to" — T-2813's lesson,
    # one layer out: verify from disk state, not from the writer's exit status.
    local out
    out=$(_fw git install-hooks 2>&1)
    if [ ! -f "$REPO/.git/hooks/pre-merge-commit" ]; then
        echo "FIXTURE: install-hooks wrote nothing to $REPO:" >&2
        printf '%s\n' "$out" >&2
        return 1
    fi
}

_commit_all() {
    git -C "$REPO" add -A >/dev/null 2>&1
    # Do NOT swallow the failure. A fixture step that fails silently reports as a
    # broken assertion three lines later and sends you looking in the wrong place —
    # which is exactly what it did on the first run of this suite.
    local out
    if ! out=$(git -C "$REPO" commit -m "$1" 2>&1); then
        echo "FIXTURE: commit '$1' failed:" >&2
        printf '%s\n' "$out" >&2
        return 1
    fi
}

# $1=id $2=status $3=horizon
_task() {
    cat > "$REPO/.tasks/active/$1-fixture.md" <<EOF
---
id: $1
name: "fixture"
status: $2
workflow_type: build
owner: agent
horizon: $3
---

# $1
EOF
    _commit_all "T-3511: add fixture task"
}

# Branch that diverges from master, so a merge COMMIT is required (not a FF).
_feature_branch() {
    git -C "$REPO" checkout -q -b "$1"
    echo work > "$REPO/w-$1"
    _commit_all "T-3511: work on $1"
    git -C "$REPO" checkout -q master
    echo side > "$REPO/side-$1"
    _commit_all "T-3511: master moves on"
}

_merge() {
    ( cd "$REPO" && git merge --no-edit "$1" 2>&1 )
}

# ── the hook has to be DEPLOYED, not merely authored ───────────────────────────

@test "install-hooks writes pre-merge-commit, executable" {
    [ -f "$REPO/.git/hooks/pre-merge-commit" ]
    [ -x "$REPO/.git/hooks/pre-merge-commit" ]
}

@test "the version marker was bumped, so an existing install redeploys" {
    # PL-078: install-hooks short-circuits on the commit-msg VERSION marker alone.
    # Without the bump, this whole feature would sit in the template and never
    # reach a consumer that already has hooks.
    run grep -h '^# VERSION=' "$REPO/.git/hooks/commit-msg"
    [ "$status" -eq 0 ]
    installed="${output#*=}"
    template=$(grep -m1 '^COMMIT_MSG_HOOK_VERSION=' "$FRAMEWORK_ROOT/agents/git/lib/hooks.sh" | cut -d'"' -f2)
    [ "$installed" = "$template" ]
}

# ── the incident's own shape ───────────────────────────────────────────────────

@test "clean merge of a PARKED branch is refused" {
    _task T-3487 captured later
    _feature_branch t3487-remove-gate
    run _merge t3487-remove-gate
    [ "$status" -ne 0 ]
    [[ "$output" =~ "BLOCKED" ]]
    [[ "$output" =~ "t3487-remove-gate" ]]
    [[ "$output" =~ "T-3487" ]]
}

@test "the refused merge leaves NO merge commit behind" {
    _task T-3487 captured later
    _feature_branch t3487-remove-gate
    before=$(git -C "$REPO" rev-parse HEAD)
    run _merge t3487-remove-gate
    [ "$(git -C "$REPO" rev-parse HEAD)" = "$before" ]
}

@test "CONTROL: clean merge of a LIVE task's branch succeeds" {
    # Without this leg, the refusal test could be passing because merges are
    # broken in the fixture rather than because the guard judged anything.
    _task T-3487 work-completed now
    _feature_branch t3487-remove-gate
    run _merge t3487-remove-gate
    [ "$status" -eq 0 ]
    [[ ! "$output" =~ "BLOCKED" ]]
}

@test "CONTROL: a branch with no resolvable task id merges freely" {
    _feature_branch dispatch-f25
    run _merge dispatch-f25
    [ "$status" -eq 0 ]
    [[ ! "$output" =~ "BLOCKED" ]]
}

@test "horizon later alone is enough to refuse" {
    _task T-2353 started-work later
    _feature_branch t2353-audit-emit
    run _merge t2353-audit-emit
    [ "$status" -ne 0 ]
    [[ "$output" =~ "T-2353" ]]
}

# ── the conflicted shape, which routes through a different hook ────────────────

@test "conflicted merge of a PARKED branch is refused at the resolving commit" {
    _task T-3487 captured later
    git -C "$REPO" checkout -q -b t3487-remove-gate
    echo THEIRS > "$REPO/f"
    _commit_all "T-3511: theirs"
    git -C "$REPO" checkout -q master
    echo OURS > "$REPO/f"
    _commit_all "T-3511: ours"
    # The conflict is the POINT, so this merge exits 1. Without `|| true` bats
    # aborts the test here under set -e — and its DEBUG trap then reports a STALE
    # line inside _commit_all, which sent me hunting three statements upstream.
    ( cd "$REPO" && git merge --no-edit t3487-remove-gate >/dev/null 2>&1 ) || true
    echo OURS > "$REPO/f"
    git -C "$REPO" add -- f
    run bash -c "cd '$REPO' && git commit -m 'T-3511: resolve' 2>&1"
    [ "$status" -ne 0 ]
    [[ "$output" =~ "BLOCKED" ]]
}

# ── the bypass, which must be an env var because git rejects unknown flags ─────

@test "FW_ALLOW_PARKED_MERGE=1 permits the merge and says so" {
    _task T-3487 captured later
    _feature_branch t3487-remove-gate
    run bash -c "cd '$REPO' && FW_ALLOW_PARKED_MERGE=1 git merge --no-edit t3487-remove-gate 2>&1"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Tier-2" ]]
}

@test "the bypass warning does NOT fire on a merge that was never blocked" {
    # Otherwise the warning appears on ordinary merges and gets tuned out, which
    # is how a Tier-2 signal stops being read.
    _task T-3487 work-completed now
    _feature_branch t3487-remove-gate
    run bash -c "cd '$REPO' && FW_ALLOW_PARKED_MERGE=1 git merge --no-edit t3487-remove-gate 2>&1"
    [ "$status" -eq 0 ]
    [[ ! "$output" =~ "Tier-2" ]]
}

# ── the shapes this guard CANNOT cover, pinned as known state ──────────────────

@test "KNOWN GAP: a fast-forward merge of a parked branch is NOT refused" {
    # git fires no pre-merge-commit and no pre-commit on a fast-forward, because no
    # commit object is created — measured, not assumed. Pinned so the gap stays
    # visible: if someone later closes it via reference-transaction, this test
    # SHOULD go red and be rewritten deliberately.
    _task T-3487 captured later
    git -C "$REPO" checkout -q -b t3487-remove-gate
    echo work > "$REPO/w"
    _commit_all "T-3511: work"
    git -C "$REPO" checkout -q master
    run bash -c "cd '$REPO' && git merge --ff-only t3487-remove-gate 2>&1"
    [ "$status" -eq 0 ]
    [[ ! "$output" =~ "BLOCKED" ]]
}

@test "--squash of a parked branch is allowed but says it could not check" {
    _task T-3487 captured later
    _feature_branch t3487-remove-gate
    run bash -c "cd '$REPO' && git merge --squash t3487-remove-gate >/dev/null 2>&1; git commit -m 'T-3511: squashed' 2>&1"
    [[ "$output" =~ "cannot check a --squash merge" ]]
}

# ── degradation must be loud ───────────────────────────────────────────────────

@test "missing guard degrades to ALLOW but warns on stderr" {
    # T-2647: a control that no-ops is indistinguishable from one that passed.
    _task T-3487 captured later
    _feature_branch t3487-remove-gate
    printf 'framework_path: %s/nonexistent\n' "$TEST_TEMP_DIR" > "$REPO/.framework.yaml"
    _commit_all "T-3511: break the framework path"
    run _merge t3487-remove-gate
    [ "$status" -eq 0 ]
    [[ "$output" =~ "NOT running" ]]
}
