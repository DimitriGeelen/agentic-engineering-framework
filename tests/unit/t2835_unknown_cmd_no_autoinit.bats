#!/usr/bin/env bats
# T-2835 — an unrecognised fw subcommand must not initialise the caller's cwd.
#
# bin/fw's auto-init branch excluded a handful of named verbs but never asked
# whether the command existed, so `fw doctro` ran do_init on $PWD: git init plus
# a ~27M vendored tree, then re-exec. The `Unknown command:` error further down
# was unreachable, because the mutation happened hundreds of lines earlier.
# Origin: a live onboarding run where `fw doctor` against an older global install
# (verb not yet present) began bootstrapping the operator's test directory.
#
# Both directions are pinned. The unknown-verb direction is the bug. The
# known-verb direction guards T-2770 — whether a known read-only verb SHOULD
# auto-init is an open question with consumer blast radius, and this fix must
# neither answer nor foreclose it. If T-2770 is later decided, that test changes
# deliberately rather than silently.

setup() {
    FW="$BATS_TEST_DIRNAME/../../bin/fw"
    TEST_TEMP_DIR="$(mktemp -d)"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
    return 0
}

@test "unknown subcommand exits non-zero instead of initialising" {
    cd "$TEST_TEMP_DIR"
    run timeout 60 "$FW" nosuchsubcommand </dev/null
    [ "$status" -ne 0 ]
}

@test "unknown subcommand reports Unknown command" {
    cd "$TEST_TEMP_DIR"
    run timeout 60 "$FW" nosuchsubcommand </dev/null
    [[ "$output" == *"Unknown command"* ]]
}

@test "unknown subcommand creates NOTHING in cwd" {
    cd "$TEST_TEMP_DIR"
    run timeout 60 "$FW" nosuchsubcommand </dev/null
    [ ! -e "$TEST_TEMP_DIR/.git" ]
    [ ! -e "$TEST_TEMP_DIR/.agentic-framework" ]
    [ ! -e "$TEST_TEMP_DIR/.framework.yaml" ]
    [ ! -e "$TEST_TEMP_DIR/.fw-init-incomplete" ]
    # Belt and braces: the directory is still empty apart from . and ..
    [ -z "$(ls -A "$TEST_TEMP_DIR")" ]
}

@test "a near-miss typo of a real command is still unknown (no fuzzy init)" {
    cd "$TEST_TEMP_DIR"
    run timeout 60 "$FW" doctro </dev/null
    [ "$status" -ne 0 ]
    [ -z "$(ls -A "$TEST_TEMP_DIR")" ]
}

# --- guard: the known set must be derived, and must actually contain things ---

@test "known-command extraction finds real commands (not vacuously empty)" {
    # If the awk/grep extraction silently returned nothing, every command would
    # read as unknown and fw would refuse everything — a failure that would look
    # like this fix working. Assert the set is populated and contains known verbs.
    cmds=$(awk '/^case "\$cmd" in/,/^esac/' "$FW" \
        | grep -E '^[[:space:]]{4}[a-z][-a-z0-9|]+\)' \
        | sed 's/[[:space:]]*)//; s/^[[:space:]]*//' \
        | tr '|' '\n' | grep -v '^-' | sort -u)
    [ "$(echo "$cmds" | grep -c .)" -gt 20 ]
    echo "$cmds" | grep -qx "doctor"
    echo "$cmds" | grep -qx "audit"
    echo "$cmds" | grep -qx "metrics"
    ! echo "$cmds" | grep -qx "nosuchsubcommand"
}

@test "T-2770 boundary: a KNOWN verb still auto-inits (behaviour unchanged)" {
    cd "$TEST_TEMP_DIR"
    run timeout 300 "$FW" doctor </dev/null
    # The point is the side effect, not the exit code: doctor's own verdict may
    # be non-zero on a freshly created project.
    [ -e "$TEST_TEMP_DIR/.framework.yaml" ]
    [ -e "$TEST_TEMP_DIR/.agentic-framework" ]
}

@test "fw init in an empty directory still works" {
    cd "$TEST_TEMP_DIR"
    run timeout 300 "$FW" init --no-first-run </dev/null
    [ -e "$TEST_TEMP_DIR/.framework.yaml" ]
}
