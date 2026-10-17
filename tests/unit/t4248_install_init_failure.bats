#!/usr/bin/env bats
# T-4248: install.sh must not report success when its `fw init` step fails.
#
# Live symptom (dimitri-mint-dev, 2026-10-17): fw init reported
# "[x] .framework.yaml not found" / "[x] vendor incomplete", yet install.sh
# printed "Installation complete!" and exited 0.
#
# The failure is forced in a fixture clone of this repo whose bin/fw carries a
# test hook (T4248_FORCE_INIT): the real init still runs, so verify() passes and
# only the init check in do_project_init can turn the install red.
#   rc  — init completes, then exits 3
#   x   — init completes with exit 0, then prints a "[x]" step
# The control runs the same fixture with the hook unset.

bats_require_minimum_version 1.5.0

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
INSTALL="$FRAMEWORK_ROOT/install.sh"

setup_file() {
    CURRENT_BRANCH="$(git -C "$FRAMEWORK_ROOT" rev-parse --abbrev-ref HEAD)"
    export CURRENT_BRANCH
    [[ "$CURRENT_BRANCH" == "HEAD" ]] && return 0

    FIXTURE_REPO=$(mktemp -d)
    export FIXTURE_REPO
    git clone -q --depth 1 --branch "$CURRENT_BRANCH" --single-branch \
        "file://$FRAMEWORK_ROOT" "$FIXTURE_REPO"
    sed -i '1a\
if [[ "${1:-}" == init && "${T4248_FORCE_INIT:-}" == rc ]]; then T4248_FORCE_INIT= bash "$0" "$@"; echo "forced init failure"; exit 3; fi\
if [[ "${1:-}" == init && "${T4248_FORCE_INIT:-}" == x ]]; then T4248_FORCE_INIT= bash "$0" "$@"; rc=$?; echo "[x] forced failing step"; exit $rc; fi' \
        "$FIXTURE_REPO/bin/fw"
    git -C "$FIXTURE_REPO" -c user.name=t -c user.email=t@example.com \
        commit -q -am "T-4248 fixture: forced init failure hook"
}

teardown_file() {
    [[ -n "${FIXTURE_REPO:-}" ]] && rm -rf "$FIXTURE_REPO"
    return 0
}

setup() {
    [[ "$CURRENT_BRANCH" == "HEAD" ]] && skip "detached HEAD -- --local install needs a real branch name"
    TEST_HOME=$(mktemp -d)
    TEST_TARGET=$(mktemp -d)
    git init -q "$TEST_TARGET"
}

teardown() {
    rm -rf "${TEST_HOME:-}" "${TEST_TARGET:-}"
}

run_install() {
    # GIT_CEILING_DIRECTORIES: this host has a git repo at /, which would
    # otherwise enclose the mktemp target.
    run env -i HOME="$TEST_HOME" \
        PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
        GIT_CEILING_DIRECTORIES="$(dirname "$TEST_TARGET")" \
        GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.com \
        GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.com \
        "$@" \
        bash "$INSTALL" "$TEST_TARGET" --local "$FIXTURE_REPO" --branch "$CURRENT_BRANCH" --no-scan
}

@test "T-4248: control — init succeeds, install completes with exit 0" {
    run_install T4248_FORCE_INIT=
    [[ "$output" != *"FAILED"* ]]
    [[ "$output" == *"Project initialised: "* ]]
    [[ "$output" == *"Installation complete!"* ]]
    [ "$status" -eq 0 ]
}

@test "T-4248: fw init exits non-zero — install prints FAILED, exits non-zero, never 'complete'" {
    run_install T4248_FORCE_INIT=rc
    [[ "$output" == *"forced init failure"* ]]
    [[ "$output" == *"fw init reported an issue"* ]]
    [[ "$output" == *"Installation FAILED"* ]]
    [[ "$output" != *"Installation complete!"* ]]
    [ "$status" -ne 0 ]
}

@test "T-4248: fw init exits 0 but reports a [x] step — install prints FAILED, exits non-zero" {
    run_install T4248_FORCE_INIT=x
    [[ "$output" == *"[x] forced failing step"* ]]
    [[ "$output" == *"fw init reported an issue"* ]]
    [[ "$output" == *"Installation FAILED"* ]]
    [[ "$output" != *"Installation complete!"* ]]
    [ "$status" -ne 0 ]
}
