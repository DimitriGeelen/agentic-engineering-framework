#!/usr/bin/env bats
# T-2798 — asking for help must not create a project.
#
# bin/fw's auto-init branch exempts init/help/version/update/hook/vendor by
# testing `$1` only. `fw doctor --help` puts --help in `$2`, so every
# `fw <subcommand> --help` run from a non-project directory fell through and
# auto-initialised the caller's cwd: git repo created, ~90MB of framework
# vendored, all from a request to print a usage string. Non-interactively — the
# onboarding agent's case — with no prompt, because only the TTY branch asks.
#
# Field report 2026-08-04: an operator's onboarding agent ran `fw doctor --help`
# in an empty /opt/2345-test-install to check the verb existed, got an init,
# was interrupted mid-vendor, and left `.git` + `.agentic-framework/` with no
# `.framework.yaml` — a state where every fw call fails "Cannot find framework
# installation", so the tool cannot repair what it created.
#
# The third test is the one that keeps the other two honest: deleting the
# auto-init branch outright would make "help mutates nothing" pass while
# breaking the feature. Assert the branch still fires for a real command.

bats_require_minimum_version 1.5.0

FW() { echo "$BATS_TEST_DIRNAME/../../bin/fw"; }

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
}

teardown() {
    # Unconditional: a regression here vendors ~90MB into the temp dir, and the
    # tests that catch it are exactly the ones that fail before cleanup.
    [ -n "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
    return 0
}

# Everything the temp dir may contain when nothing has been created.
assert_dir_untouched() {
    local leftovers
    leftovers="$(ls -A "$TEST_TEMP_DIR")"
    if [ -n "$leftovers" ]; then
        echo "Directory was mutated by a help query:" >&2
        echo "$leftovers" >&2
        return 1
    fi
}

@test "fw <subcommand> --help prints help and creates nothing" {
    cd "$TEST_TEMP_DIR"
    run env -u FRAMEWORK_ROOT -u PROJECT_ROOT "$(FW)" doctor --help
    [ "$status" -eq 0 ]
    echo "$output" | grep -qi 'usage'
    [[ "$output" != *"Setting up agentic governance"* ]]
    assert_dir_untouched
}

@test "the short form -h is exempt too" {
    cd "$TEST_TEMP_DIR"
    run env -u FRAMEWORK_ROOT -u PROJECT_ROOT "$(FW)" doctor -h
    [ "$status" -eq 0 ]
    [[ "$output" != *"Setting up agentic governance"* ]]
    assert_dir_untouched
}

@test "the exemption is not a per-subcommand allowlist" {
    # The defect was an allowlist that had to be right for every subcommand and
    # was wrong for all of them. Sample a few unrelated verbs; the point is that
    # none of them needed to be enumerated anywhere.
    cd "$TEST_TEMP_DIR"
    for sub in task context fabric audit; do
        run env -u FRAMEWORK_ROOT -u PROJECT_ROOT "$(FW)" "$sub" --help
        [[ "$output" != *"Setting up agentic governance"* ]]
        assert_dir_untouched
    done
}

@test "auto-init still fires for a real command from a non-project directory" {
    # Non-vacuity guard. Without this, deleting the auto-init branch entirely
    # would turn all three tests above green while removing the feature.
    #
    # `timeout` because a full init vendors the framework and takes ~minutes:
    # the banner is emitted first, and its presence is the whole assertion.
    cd "$TEST_TEMP_DIR"
    run timeout 8 env -u FRAMEWORK_ROOT -u PROJECT_ROOT "$(FW)" doctor
    echo "$output" | grep -q 'Setting up agentic governance'
}
