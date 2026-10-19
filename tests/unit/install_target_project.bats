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

    allow_init_probe
    run run_install
    [ "$status" -eq 0 ]
    [[ "$output" == *"All verification steps passed"* ]]

    # The project was created where named...
    [ -f "$TEST_TARGET/.framework.yaml" ]
    [ -f "$TEST_TARGET/.agentic-framework/FRAMEWORK.md" ]

    # ...and NOTHING was written to \$HOME beyond the router + claude-fw.
    [ ! -d "$TEST_HOME/.agentic-framework" ]
    [ -x "$TEST_HOME/.local/bin/fw" ]
    [ -x "$TEST_HOME/.local/bin/claude-fw" ]
}

@test "T-2809: fw in the target project reports Mode: vendored, with no global install" {
    if [[ "$CURRENT_BRANCH" == "HEAD" ]]; then
        skip "detached HEAD -- --local install needs a real branch name"
    fi

    allow_init_probe
    run run_install
    [ "$status" -eq 0 ]

    run env -i HOME="$TEST_HOME" \
        PATH="$TEST_HOME/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
        TMPDIR="$TMPDIR" FW_PORT="$FW_PORT" \
        bash -c "cd '$TEST_TARGET' && fw version"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Mode:      vendored"* ]]
    [[ "$output" == *"Framework: $TEST_TARGET/.agentic-framework"* ]]
}

@test "T-2809: the temporary fetch directory does not survive the run" {
    if [[ "$CURRENT_BRANCH" == "HEAD" ]]; then
        skip "detached HEAD -- --local install needs a real branch name"
    fi

    # T-4318: TMPDIR is private (hermetic_setup). The shared /tmp listing also
    # changes when parallel tests create and remove their own agentic-fw-fetch-* dirs.
    local after

    allow_init_probe
    run run_install
    [ "$status" -eq 0 ]

    after="$(compgen -G "$TMPDIR/agentic-fw-fetch-*" || true)"
    [ -z "$after" ] || { echo "fetch dir leaked: $after"; false; }
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
