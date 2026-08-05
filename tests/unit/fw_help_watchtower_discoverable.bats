#!/usr/bin/env bats
# T-2808 — `fw help` must make the Watchtower port resolvable.
#
# CLAUDE.md's §Watchtower Port rule tells every agent to resolve the port with
# `fw watchtower port|url` and never hard-code :3000. The T-2732 close gate
# refuses a Verification line containing a bare port-3000 URL. And yet `fw help`
# listed no `watchtower` entry at all, while advertising "default port 3000" on
# the `serve` line — so the CLI's own front page taught the anti-pattern and hid
# the verb the rule depends on.
#
# Hit live: an onboarding agent on a fresh project ran `fw watchtower url`, got
# http://localhost:3000 back, and could not find the command in `fw help` to
# check itself against (operator report, 2026-08-05).

bats_require_minimum_version 1.5.0

FW() { echo "$BATS_TEST_DIRNAME/../../bin/fw"; }

setup() {
    # Strip ANSI so assertions are about words, not escape sequences.
    HELP="$(cd "$BATS_TEST_DIRNAME/../.." && bin/fw help 2>&1 | sed 's/\x1b\[[0-9;]*m//g')"
}

@test "fw help lists a watchtower entry" {
    echo "$HELP" | grep -qE '^[[:space:]]*watchtower[[:space:]]'
}

@test "the watchtower entry names the port and url subcommands" {
    # Listing the verb without its subcommands still leaves the agent guessing.
    local line
    line="$(echo "$HELP" | grep -E '^[[:space:]]*watchtower[[:space:]]')"
    echo "$line" | grep -q 'port'
    echo "$line" | grep -q 'url'
}

@test "fw help states no port-3000 default anywhere" {
    # Not scoped to the serve line: any 3000 in help is a number an agent may
    # copy. The port is per-project (triple-file -> FW_PORT -> 3000), so there is
    # no default worth printing here.
    ! echo "$HELP" | grep -q '3000'
}

@test "the serve entry points at the resolution command instead of a literal" {
    # Non-vacuity for the test above: deleting the serve line entirely would also
    # remove the 3000, and would be a regression rather than a fix.
    local line
    line="$(echo "$HELP" | grep -E '^[[:space:]]*serve[[:space:]]')"
    [ -n "$line" ]
    echo "$line" | grep -q 'watchtower port'
}

@test "fw help exits 0 and still lists the other top-level commands" {
    # Guards against a bad edit that truncates the command list — the assertions
    # above would all still pass on a help output that lost half its entries.
    run bash -c "cd '$(cd "$BATS_TEST_DIRNAME/../.." && pwd)' && bin/fw help"
    [ "$status" -eq 0 ]
    for verb in task work-on doctor audit handover fabric serve; do
        echo "$HELP" | grep -qE "^[[:space:]]*${verb}[[:space:]]" \
            || fail "missing top-level verb in help: $verb"
    done
}
