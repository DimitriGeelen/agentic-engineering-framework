#!/usr/bin/env bats
# T-3625 — fw doctor must not abort when PROJECT_ROOT is not inside a git repo.
# bin/fw runs set -euo pipefail; the T-2812 git-hooks check assigned the output
# of a failing `git rev-parse --git-path hooks` (rc 128), which killed doctor
# right after "OK Context directory" and made the empty-result fallback dead code.
# test_helper loads tests/git_fence.bash, so the /tmp fixture cannot resolve to
# a repo above it.

load ../test_helper

setup() {
    export FW_DOCTOR_SMOKE=0  # T-3933: never sweep the live Watchtower from a test
    TEST_TEMP_DIR="$(mktemp -d)"
    TEST_PROJECT="$TEST_TEMP_DIR/proj-non-git"
    mkdir -p "$TEST_PROJECT/.context/working" \
             "$TEST_PROJECT/.tasks/active" \
             "$TEST_PROJECT/.tasks/completed" \
             "$TEST_PROJECT/.tasks/templates"
    echo "# template" > "$TEST_PROJECT/.tasks/templates/default.md"
    echo "framework_root: $FRAMEWORK_ROOT" > "$TEST_PROJECT/.framework.yaml"
    export PROJECT_ROOT="$TEST_PROJECT"
    export FW_CRON_INSTALL_DIR="$TEST_TEMP_DIR/etc-cron-d"
    mkdir -p "$FW_CRON_INSTALL_DIR"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

@test "fixture is genuinely outside any git repo" {
    run git -C "$TEST_PROJECT" rev-parse --git-dir
    [ "$status" -ne 0 ]
}

@test "doctor does not exit 128 in a non-git project" {
    run "$FRAMEWORK_ROOT/bin/fw" doctor
    [ "$status" -ne 128 ]
}

@test "doctor reaches the git-hooks check and beyond in a non-git project" {
    run "$FRAMEWORK_ROOT/bin/fw" doctor
    [[ "$output" == *"Context directory"* ]]
    [[ "$output" == *"Git commit-msg hook"* ]]
    [[ "$output" == *"Git pre-push hook"* ]]
}
