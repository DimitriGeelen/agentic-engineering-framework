#!/usr/bin/env bats
# T-3186: fw sync and fw integrate must land on the DEV branch, not master.
#
# Under the release train (T-3185) master is the consumer install surface and
# lags deliberately between releases. Two commands still aimed at it:
#
#   fw integrate run  — landed worktree work ONTO master, injecting unreleased
#                       code straight into what consumers `fw upgrade` from.
#   fw sync           — rebased the session onto origin/master, replaying local
#                       commits onto an OLDER tree. A rewind wearing a
#                       reconcile's output.
#
# Control-leg discipline (T-3187/T-3188): every "resolves to bleeding-edge"
# assertion is paired with a fixture where it must resolve to master, because
# a resolver that reads the knob and a resolver that hard-codes the new default
# produce identical output on the happy path.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    REPO="$TEST_TEMP_DIR/repo"
    mkdir -p "$REPO"
    git -C "$REPO" init -q -b master
    git -C "$REPO" config user.email t@t.t
    git -C "$REPO" config user.name t
    echo base > "$REPO/f"; git -C "$REPO" add f; git -C "$REPO" commit -qm c1
    INTEGRATE="$FRAMEWORK_ROOT/lib/integrate.py"
    FW="$FRAMEWORK_ROOT/bin/fw"
}

teardown() { rm -rf "$TEST_TEMP_DIR"; }

# Resolve _default_target() in the fixture repo's cwd, with the env the caller set.
_target() {
    run bash -c "cd '$REPO' && python3 -c \"
import sys; sys.path.insert(0, '$(dirname "$INTEGRATE")')
import integrate
print(integrate._default_target())
\""
}

_mk_dev() { git -C "$REPO" branch -q "${1:-bleeding-edge}" master; }

# ── the resolver ────────────────────────────────────────────────────────────

@test "T-3186: with a bleeding-edge branch present, the default target is bleeding-edge" {
    _mk_dev
    _target
    [ "$status" -eq 0 ]
    [ "$output" = "bleeding-edge" ]
}

@test "T-3186: control — with NO dev branch, the default target is still master" {
    # The pre-T-3185 fallback. Without this leg the test above passes equally
    # for a resolver that returns the literal string 'bleeding-edge'.
    _target
    [ "$status" -eq 0 ]
    [ "$output" = "master" ]
}

@test "T-3186: FW_DEV_BRANCH overrides the default when that branch exists" {
    _mk_dev release-candidate
    run bash -c "cd '$REPO' && FW_DEV_BRANCH=release-candidate python3 -c \"
import sys; sys.path.insert(0, '$(dirname "$INTEGRATE")')
import integrate
print(integrate._default_target())
\""
    [ "$status" -eq 0 ]
    [ "$output" = "release-candidate" ]
}

@test "T-3186: control — FW_DEV_BRANCH naming a branch that does NOT exist falls back to master" {
    run bash -c "cd '$REPO' && FW_DEV_BRANCH=no-such-branch python3 -c \"
import sys; sys.path.insert(0, '$(dirname "$INTEGRATE")')
import integrate
print(integrate._default_target())
\""
    [ "$status" -eq 0 ]
    [ "$output" = "master" ]
}

@test "T-3186: a remote-only dev branch resolves too (fresh clone, no local ref yet)" {
    UP="$TEST_TEMP_DIR/up.git"
    git init -q --bare "$UP"
    git -C "$REPO" remote add origin "$UP"
    git -C "$REPO" push -q origin master
    git -C "$REPO" checkout -q -b bleeding-edge
    echo d > "$REPO/d"; git -C "$REPO" add d; git -C "$REPO" commit -qm c2
    git -C "$REPO" push -q origin bleeding-edge
    CLONE="$TEST_TEMP_DIR/clone"
    git clone -q "$UP" "$CLONE"
    run bash -c "cd '$CLONE' && python3 -c \"
import sys; sys.path.insert(0, '$(dirname "$INTEGRATE")')
import integrate
print(integrate._default_target())
\""
    [ "$status" -eq 0 ]
    [ "$output" = "bleeding-edge" ]
}

# ── integrate check / run wiring ─────────────────────────────────────────────

@test "T-3186: integrate check with no argument names the dev branch as the target" {
    _mk_dev
    git -C "$REPO" checkout -q -b feature
    echo x > "$REPO/x"; git -C "$REPO" add x; git -C "$REPO" commit -qm feat
    run bash -c "cd '$REPO' && python3 '$INTEGRATE' check 2>&1"
    [[ "$output" == *"bleeding-edge"* ]]
    [[ "$output" != *"ONTO master"* ]]
}

@test "T-3186: an explicit target still wins over the resolver" {
    _mk_dev
    git -C "$REPO" checkout -q -b feature
    echo x > "$REPO/x"; git -C "$REPO" add x; git -C "$REPO" commit -qm feat
    run bash -c "cd '$REPO' && python3 '$INTEGRATE' check master 2>&1"
    [[ "$output" != *"bleeding-edge"* ]]
}

@test "T-3186: integrate refuses when HEAD already IS the resolved target" {
    # Before T-3186 the guard only knew master/main, so running from
    # bleeding-edge sailed past it and compared the dev branch against master.
    _mk_dev
    git -C "$REPO" checkout -q bleeding-edge
    run bash -c "cd '$REPO' && python3 '$INTEGRATE' check 2>&1; echo rc=\$?"
    [[ "$output" == *"nothing to integrate"* ]]
    [[ "$output" == *"rc=3"* ]]
}

@test "T-3186: control — integrate does NOT refuse from a branch that is not the target" {
    _mk_dev
    git -C "$REPO" checkout -q -b feature
    echo x > "$REPO/x"; git -C "$REPO" add x; git -C "$REPO" commit -qm feat
    run bash -c "cd '$REPO' && python3 '$INTEGRATE' check 2>&1; echo rc=\$?"
    [[ "$output" != *"nothing to integrate"* ]]
}

@test "T-3186: integrate run with no positional target resolves the dev branch ITSELF" {
    # Asserts on cmd_run's OWN preflight line, not on any 'bleeding-edge'
    # anywhere in the output. Mutation testing caught the looser form: reverting
    # cmd_run's default to "master" reddened nothing, because main() passes an
    # explicit None and the downstream cmd_check resolved the branch correctly
    # on its own. The mutant printed "check None" and the bare substring grep
    # still found 'bleeding-edge' in cmd_check's output — a test that measured
    # its callee instead of its subject.
    _mk_dev
    git -C "$REPO" checkout -q -b feature
    echo x > "$REPO/x"; git -C "$REPO" add x; git -C "$REPO" commit -qm feat
    run bash -c "cd '$REPO' && python3 '$INTEGRATE' run --dry-run 2>&1"
    [[ "$output" == *"preflight: fw integrate check bleeding-edge"* ]]
}

# ── fw sync wiring (source-level: the reconcile itself needs a live remote) ──

@test "T-3186: fw sync no longer fetches or rebases origin/master unconditionally" {
    # Comment lines are excluded on purpose: the retargeting comment QUOTES the
    # old `git pull --rebase origin master` to explain why it had to move, and
    # that explanation is the most valuable line in the block. A grep that
    # cannot tell code from the commentary about it would force us to delete
    # the reason in order to keep the rail green.
    run bash -c "grep -vE '^[[:space:]]*#' '$FW' | grep -n 'fetch origin master\|pull --rebase origin master'"
    [ "$status" -ne 0 ]
}

@test "T-3186: control — fw sync still contains the fetch and rebase steps" {
    # Pairs with the assertion above: deleting the sync block entirely would
    # satisfy a bare 'no origin/master' grep just as well as retargeting it.
    run grep -c 'fetch origin "\$_sync_dev"' "$FW"
    [ "$status" -eq 0 ]
    [ "$output" -ge 1 ]
    run grep -c 'pull --rebase origin "\$_sync_dev"' "$FW"
    [ "$status" -eq 0 ]
    [ "$output" -ge 1 ]
}

@test "T-3186: fw sync's branch warning fires for NOT being on the dev branch" {
    run grep -c '_sync_branch" != "\$_sync_dev"' "$FW"
    [ "$status" -eq 0 ]
    [ "$output" -ge 1 ]
}

@test "T-3186: no surface still tells the operator to run the session on master" {
    run grep -n 'runs the persistent session ON master\|the session itself should be on master' "$FW"
    [ "$status" -ne 0 ]
}

@test "T-3186: fw sync resolves its target through FW_DEV_BRANCH, not a second knob" {
    run grep -c 'FW_DEV_BRANCH:-bleeding-edge' "$FW"
    [ "$status" -eq 0 ]
    [ "$output" -ge 1 ]
}

@test "T-3186: bin/fw parses (L-408)" {
    run bash -n "$FW"
    [ "$status" -eq 0 ]
}
