#!/usr/bin/env bats
# T-4331 (dimitri-mint-dev T-133 F-02) — install.sh's post-install fw doctor
# reported "failures (exit 2; 0 warning(s))" while a manual fw doctor right
# afterwards exited 0. Cause: the shell that ran install.sh carried
# PROJECT_ROOT/FRAMEWORK_ROOT from another install. do_project_init strips them
# for fw init (T-4248/T-4298); verify() did not, so doctor ran against the
# inherited PROJECT_ROOT and refused ("PROJECT_ROOT does not exist", rc 2).
# Companion to install_target_project.bats (same env -i harness).
#
# Confirmed RED against the pre-T-4331 install.sh: test 1 sees
# "fw doctor reported failures (exit 2".

bats_require_minimum_version 1.5.0

FRAMEWORK_ROOT_REPO="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
INSTALL="$FRAMEWORK_ROOT_REPO/install.sh"

setup() {
    TEST_HOME=$(mktemp -d)
    TEST_TARGET=$(mktemp -d)
    GONE=$(mktemp -d)
    rmdir "$GONE"
    git init -q "$TEST_TARGET"
    CURRENT_BRANCH="$(git -C "$FRAMEWORK_ROOT_REPO" rev-parse --abbrev-ref HEAD)"
}

teardown() {
    rm -rf "$TEST_HOME" "$TEST_TARGET"
}

run_install_with_leaked_env() {
    env -i HOME="$TEST_HOME" \
        FRAMEWORK_ROOT="$GONE/fw" PROJECT_ROOT="$GONE/proj" \
        GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.com \
        GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.com \
        PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
        bash "$INSTALL" "$TEST_TARGET" --local "$FRAMEWORK_ROOT_REPO" --branch "$CURRENT_BRANCH" --no-scan
}

@test "T-4331: post-install doctor ignores an inherited PROJECT_ROOT/FRAMEWORK_ROOT" {
    if [[ "$CURRENT_BRANCH" == "HEAD" ]]; then
        skip "detached HEAD -- --local install needs a real branch name"
    fi

    run run_install_with_leaked_env
    [ "$status" -eq 0 ]
    [[ "$output" == *"Ignoring inherited environment"* ]]
    [[ "$output" != *"fw doctor reported failures"* ]]
    [[ "$output" == *"Step 3/3: fw doctor passes"* ]]

    # The installer's verdict agrees with a manual doctor from a clean shell.
    run env -i HOME="$TEST_HOME" PATH="/usr/local/bin:/usr/bin:/bin" \
        bash -c "cd '$TEST_TARGET' && .agentic-framework/bin/fw doctor"
    [ "$status" -eq 0 ]
}

@test "T-4331: a failing post-install doctor names what failed, not just the exit code" {
    # Static check: the failure branch prints doctor's FAIL/refusal lines.
    run grep -n 'fail_lines' "$INSTALL"
    [ "$status" -eq 0 ]
    run grep -nE 'env -u FRAMEWORK_ROOT -u PROJECT_ROOT -u TASKS_DIR' "$INSTALL"
    [ "$status" -eq 0 ]
    [ "${#lines[@]}" -ge 2 ]
}
