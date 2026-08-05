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

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
INSTALL="$FRAMEWORK_ROOT/install.sh"

setup() {
    TEST_HOME=$(mktemp -d)
    TEST_TARGET=$(mktemp -d)
    # mktemp already creates the dir; do_init refuses on a non-empty dir only
    # via the .framework.yaml check, so an empty dir here is fine to reuse.
    CURRENT_BRANCH="$(git -C "$FRAMEWORK_ROOT" rev-parse --abbrev-ref HEAD)"
}

teardown() {
    rm -rf "$TEST_HOME" "$TEST_TARGET"
}

run_install() {
    env -i HOME="$TEST_HOME" \
        PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
        bash "$INSTALL" "$TEST_TARGET" --local "$FRAMEWORK_ROOT" --branch "$CURRENT_BRANCH" --no-scan
}

@test "T-2809: install.sh <target> vendors into the target project, not \$HOME" {
    if [[ "$CURRENT_BRANCH" == "HEAD" ]]; then
        skip "detached HEAD -- --local install needs a real branch name"
    fi

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

    run run_install
    [ "$status" -eq 0 ]

    run env -i HOME="$TEST_HOME" \
        PATH="$TEST_HOME/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
        bash -c "cd '$TEST_TARGET' && fw version"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Mode:      vendored"* ]]
    [[ "$output" == *"Framework: $TEST_TARGET/.agentic-framework"* ]]
}

@test "T-2809: the temporary fetch directory does not survive the run" {
    if [[ "$CURRENT_BRANCH" == "HEAD" ]]; then
        skip "detached HEAD -- --local install needs a real branch name"
    fi

    local before after
    before="$(compgen -G "${TMPDIR:-/tmp}/agentic-fw-fetch-*" || true)"

    run run_install
    [ "$status" -eq 0 ]

    after="$(compgen -G "${TMPDIR:-/tmp}/agentic-fw-fetch-*" || true)"
    [ "$before" = "$after" ] || { echo "fetch dir leaked: $after"; false; }
}

@test "T-2809: re-running install.sh against an already-initialised target leaves it untouched" {
    if [[ "$CURRENT_BRANCH" == "HEAD" ]]; then
        skip "detached HEAD -- --local install needs a real branch name"
    fi

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

    local cwd
    cwd=$(mktemp -d)

    run env -i HOME="$TEST_HOME" \
        PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
        bash -c "cd '$cwd' && bash '$INSTALL' --local '$FRAMEWORK_ROOT' --branch '$CURRENT_BRANCH' --no-scan"
    [ "$status" -eq 0 ]

    local entries
    entries=$(find "$cwd" -mindepth 1 | wc -l)
    [ "$entries" -eq 0 ] || { echo "cwd was NOT empty: $(ls -A "$cwd")"; false; }
    [ ! -d "$TEST_HOME/.agentic-framework" ]
    [ -x "$TEST_HOME/.local/bin/fw" ]

    rm -rf "$cwd"
}
