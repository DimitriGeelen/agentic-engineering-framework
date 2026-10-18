#!/usr/bin/env bats
# T-2746 — a non-TTY fw verb run outside any project must not create one.
#
# Origin: a field run (dimitri-mint-dev, greenfield run 4) called
# `fw sidecar inbox --peek` by absolute path from a directory that was not a
# project, with no TTY. bin/fw's auto-init branch ran `do_init` in that cwd: git
# init, a ~44 MB vendored tree, a bootstrap commit. The accidental project's
# hooks then went live mid-session and blocked writes to the real target.
#
# The contract pinned here: read-only and unrelated verbs say so and exit
# non-zero, with nothing written. Only init (and the exempt verbs) may create
# or touch a project. Interactive TTY prompting is out of scope and unchanged.
#
# The environment is cleared on purpose (env -i). A worker shell can carry an
# inherited PROJECT_ROOT, which skips the branch under test and makes a
# regression look like a pass.
load ../git_fence

FW="$BATS_TEST_DIRNAME/../../bin/fw"

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    TEST_HOME="$(mktemp -d)"
    cd "$TEST_TEMP_DIR"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
    [ -d "${TEST_HOME:-}" ] && rm -rf "$TEST_HOME"
    return 0
}

# run_clean <fw args...> — non-TTY, empty environment, cwd = empty temp dir.
run_clean() {
    run env -i HOME="$TEST_HOME" PATH="$PATH" timeout 60 "$FW" "$@" </dev/null
}

assert_cwd_empty() {
    local leftovers
    leftovers="$(ls -A "$TEST_TEMP_DIR")"
    if [ -n "$leftovers" ]; then
        echo "cwd was mutated: $leftovers" >&2
        return 1
    fi
}

@test "sidecar inbox --peek from a non-project creates nothing" {
    run_clean sidecar inbox --peek
    [ "$status" -ne 0 ]
    [[ "$output" == *"not in an AEF project:"* ]]
    [[ "$output" == *"run fw init to create one"* ]]
    assert_cwd_empty
}

@test "doctor from a non-project creates nothing" {
    run_clean doctor
    [ "$status" -ne 0 ]
    [[ "$output" == *"not in an AEF project:"* ]]
    assert_cwd_empty
}

@test "task list from a non-project creates nothing" {
    run_clean task list
    [ "$status" -ne 0 ]
    [[ "$output" == *"not in an AEF project:"* ]]
    assert_cwd_empty
}

@test "version from a non-project still answers and creates nothing" {
    # version is exempt from the guard: it is read-only and never needed a project.
    run_clean version
    [ "$status" -eq 0 ]
    assert_cwd_empty
}

@test "the refusal does not mention a project it did not create" {
    run_clean doctor
    [[ "$output" != *"Setting up agentic governance"* ]]
    [ ! -e "$TEST_TEMP_DIR/.git" ]
    [ ! -e "$TEST_TEMP_DIR/.agentic-framework" ]
    [ ! -e "$TEST_TEMP_DIR/.framework.yaml" ]
}

@test "fw init in an empty directory still creates a project" {
    run timeout 300 env -i HOME="$TEST_HOME" PATH="$PATH" "$FW" init --no-first-run </dev/null
    [ -e "$TEST_TEMP_DIR/.framework.yaml" ]
}
