#!/usr/bin/env bats
# T-2809 (T-2800 slice 2, D-377 total isolation) — install.sh fetches framework
# bytes into a TEMPORARY path and vendors them into a NAMED TARGET PROJECT,
# never into $HOME. Companion to tests/unit/install_verify_no_cwd_init.bats
# (T-2799, no-target mode must not touch cwd) — this file exercises the
# WITH-target mode T-2799 deliberately did not cover.
#
# Regression provenance (AC6): before this change, install.sh only supported
# a machine-wide `$HOME/.agentic-framework` clone; there was no target-dir
# argument and no code path that vendored into a named project. Test 1 below
# was confirmed RED against the pre-T-2809 install.sh (git stash before
# writing this file, then run: fails because $TEST_HOME/.agentic-framework
# exists and the target project does not).

bats_require_minimum_version 1.5.0
load helpers/hermetic

# Not FRAMEWORK_ROOT: hermetic_setup strips that name when it is inherited.
REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
INSTALL="$REPO_ROOT/install.sh"

setup() {
    # T-4428: the shared hermetic fixture (T-4378) replaces the hand-rolled
    # temp HOME/target and the private TMPDIR of T-4318. HERMETIC_PROJECT is
    # left empty (no --project): it is the cwd test 5 asserts stays empty.
    hermetic_setup
    TEST_HOME="$HERMETIC_HOME"
    TEST_TARGET="$HERMETIC_ROOT/target"
    # T-4261: own repo, so an enclosing repo cannot stand in for the project's HEAD.
    git init -q "$TEST_TARGET"
    CURRENT_BRANCH="$(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD)"
}

teardown() {
    hermetic_teardown
}

# T-4434: tests 1-3 only read the result of one install.sh run, so it runs once
# here (five full installs took 5-6 min and timed out in the loaded nightly).
# Tests 4 and 5 keep their own runs: 4 re-runs install.sh against the target and
# 5 has no target. The SHARED_* names survive the per-test hermetic_setup that
# re-points HERMETIC_*, TMPDIR and FW_PORT.
setup_file() {
    hermetic_setup
    TEST_HOME="$HERMETIC_HOME"
    TEST_TARGET="$HERMETIC_ROOT/target"
    git init -q "$TEST_TARGET"
    CURRENT_BRANCH="$(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD)"
    SHARED_ROOT="$HERMETIC_ROOT"
    SHARED_HOME="$TEST_HOME"
    SHARED_TARGET="$TEST_TARGET"
    SHARED_TMPDIR="$TMPDIR"
    SHARED_FW_PORT="$FW_PORT"
    SHARED_DECOY_PID="$HERMETIC_DECOY_PID"
    SHARED_SIDECAR_WAS_STOPPED="$HERMETIC_SIDECAR_WAS_STOPPED"
    SHARED_STATUS=skipped
    SHARED_OUTPUT=""
    SHARED_LEAK=""
    if [[ "$CURRENT_BRANCH" != "HEAD" ]]; then
        SHARED_OUTPUT="$(run_install 2>&1)" && SHARED_STATUS=0 || SHARED_STATUS=$?
        SHARED_LEAK="$(compgen -G "$TMPDIR/agentic-fw-fetch-*" || true)"
    fi
    export SHARED_ROOT SHARED_HOME SHARED_TARGET SHARED_TMPDIR SHARED_FW_PORT \
        SHARED_DECOY_PID SHARED_SIDECAR_WAS_STOPPED \
        SHARED_STATUS SHARED_OUTPUT SHARED_LEAK
}

teardown_file() {
    # setup_file's decoy and tripwires belong to the shared install; the probe is
    # the same deliberate fw init /api/_identity call as allow_init_probe.
    HERMETIC_ROOT="$SHARED_ROOT"
    HERMETIC_DECOY_PID="$SHARED_DECOY_PID"
    HERMETIC_SIDECAR_WAS_STOPPED="$SHARED_SIDECAR_WAS_STOPPED"
    HERMETIC_SIDECAR_STOPPED="$HERMETIC_REPO/.context/sidecar/watcher/stopped"
    FW_PORT="$SHARED_FW_PORT"
    TERMLINK_TRIPWIRE_LOG="$SHARED_ROOT/termlink-tripwire.log"
    allow_init_probe
    hermetic_teardown
}

# T-4428: install.sh <target> runs fw init, which probes /api/_identity
# (lib/watchtower.sh:67) with no switch to skip it. FW_PORT is passed through
# env -i so the probe lands on the hermetic decoy; before this migration it
# reached the live Watchtower. Called in the test body, not inside run_install:
# `run` is a subshell and the flag must reach teardown.
allow_init_probe() {
    hermetic_allow_watchtower "install.sh -> fw init probes /api/_identity on purpose"
}

run_install() {
    # T-4261: identity supplied so the bootstrap commit lands; without it
    # install.sh's verify() now (correctly) fails on the missing HEAD.
    env -i HOME="$TEST_HOME" \
        GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.com \
        GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.com \
        PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
        TMPDIR="$TMPDIR" FW_PORT="$FW_PORT" \
        bash "$INSTALL" "$TEST_TARGET" --local "$REPO_ROOT" --branch "$CURRENT_BRANCH" --no-scan
}

@test "T-2809: install.sh <target> vendors into the target project, not \$HOME" {
    if [[ "$CURRENT_BRANCH" == "HEAD" ]]; then
        skip "detached HEAD -- --local install needs a real branch name"
    fi

    [ "$SHARED_STATUS" -eq 0 ] || { echo "$SHARED_OUTPUT"; false; }
    [[ "$SHARED_OUTPUT" == *"All verification steps passed"* ]]

    # The project was created where named...
    [ -f "$SHARED_TARGET/.framework.yaml" ]
    [ -f "$SHARED_TARGET/.agentic-framework/FRAMEWORK.md" ]

    # ...and NOTHING was written to \$HOME beyond the router + claude-fw.
    [ ! -d "$SHARED_HOME/.agentic-framework" ]
    [ -x "$SHARED_HOME/.local/bin/fw" ]
    [ -x "$SHARED_HOME/.local/bin/claude-fw" ]
}

@test "T-2809: fw in the target project reports Mode: vendored, with no global install" {
    if [[ "$CURRENT_BRANCH" == "HEAD" ]]; then
        skip "detached HEAD -- --local install needs a real branch name"
    fi

    [ "$SHARED_STATUS" -eq 0 ] || { echo "$SHARED_OUTPUT"; false; }

    run env -i HOME="$SHARED_HOME" \
        PATH="$SHARED_HOME/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
        TMPDIR="$SHARED_TMPDIR" FW_PORT="$SHARED_FW_PORT" \
        bash -c "cd '$SHARED_TARGET' && fw version"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Mode:      vendored"* ]]
    [[ "$output" == *"Framework: $SHARED_TARGET/.agentic-framework"* ]]
}

@test "T-2809: the temporary fetch directory does not survive the run" {
    if [[ "$CURRENT_BRANCH" == "HEAD" ]]; then
        skip "detached HEAD -- --local install needs a real branch name"
    fi

    # T-4318: TMPDIR is private (hermetic_setup). The shared /tmp listing also
    # changes when parallel tests create and remove their own agentic-fw-fetch-* dirs.
    # T-4434: the listing was taken in setup_file, right after the shared install.
    [ "$SHARED_STATUS" -eq 0 ] || { echo "$SHARED_OUTPUT"; false; }
    [ -z "$SHARED_LEAK" ] || { echo "fetch dir leaked: $SHARED_LEAK"; false; }
}

@test "T-2809: re-running install.sh against an already-initialised target leaves it untouched" {
    if [[ "$CURRENT_BRANCH" == "HEAD" ]]; then
        skip "detached HEAD -- --local install needs a real branch name"
    fi

    allow_init_probe
    run run_install
    [ "$status" -eq 0 ]

    local before_yaml before_pin
    before_yaml="$(md5sum "$TEST_TARGET/.framework.yaml" | cut -d' ' -f1)"
    before_pin="$(cat "$TEST_TARGET/.agentic-framework/VERSION")"

    # Re-run against the SAME target — must not move the version pin.
    run run_install
    [ "$status" -eq 0 ]

    local after_yaml after_pin
    after_yaml="$(md5sum "$TEST_TARGET/.framework.yaml" | cut -d' ' -f1)"
    after_pin="$(cat "$TEST_TARGET/.agentic-framework/VERSION")"

    [ "$before_yaml" = "$after_yaml" ]
    [ "$before_pin" = "$after_pin" ]
}

@test "T-2809: no target argument installs PATH tooling only, cwd stays empty (T-2799 companion)" {
    if [[ "$CURRENT_BRANCH" == "HEAD" ]]; then
        skip "detached HEAD -- --local install needs a real branch name"
    fi

    local cwd="$HERMETIC_PROJECT"

    run env -i HOME="$TEST_HOME" \
        PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
        TMPDIR="$TMPDIR" FW_PORT="$FW_PORT" \
        bash -c "cd '$cwd' && bash '$INSTALL' --local '$REPO_ROOT' --branch '$CURRENT_BRANCH' --no-scan"
    [ "$status" -eq 0 ]

    local entries
    entries=$(find "$cwd" -mindepth 1 | wc -l)
    [ "$entries" -eq 0 ] || { echo "cwd was NOT empty: $(ls -A "$cwd")"; false; }
    [ ! -d "$TEST_HOME/.agentic-framework" ]
    [ -x "$TEST_HOME/.local/bin/fw" ]
}
