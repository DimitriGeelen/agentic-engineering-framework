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
# The environment is stripped on purpose (T-4378 hermetic helper). A worker
# shell can carry an inherited PROJECT_ROOT, which skips the branch under test
# and makes a regression look like a pass. HERMETIC_PROJECT is left empty (no
# --project): it is the non-project directory under test.
load helpers/hermetic

FW="$BATS_TEST_DIRNAME/../../bin/fw"

setup() {
    hermetic_setup
}

teardown() {
    hermetic_teardown
}

# run_clean <fw args...> — non-TTY, stripped environment, cwd = empty temp dir.
run_clean() {
    hermetic_run env HOME="$HERMETIC_HOME" timeout 60 "$FW" "$@"
}

assert_cwd_empty() {
    local leftovers
    leftovers="$(ls -A "$HERMETIC_PROJECT")"
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
    [ ! -e "$HERMETIC_PROJECT/.git" ]
    [ ! -e "$HERMETIC_PROJECT/.agentic-framework" ]
    [ ! -e "$HERMETIC_PROJECT/.framework.yaml" ]
}

@test "fw init in an empty directory still creates a project" {
    hermetic_allow_watchtower "init asks the configured port's /api/_identity whether a Watchtower is ours (lib/watchtower.sh:67); the decoy answers"
    hermetic_run env HOME="$HERMETIC_HOME" timeout 300 "$FW" init --no-first-run
    [ -e "$HERMETIC_PROJECT/.framework.yaml" ]
}
