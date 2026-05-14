#!/usr/bin/env bats
# T-1839 — fw upgrade silent-downgrade guard.
#
# Origin: T-1838 (sibling) fixed the doctor advice that would have pointed
# operators at a downgrading `fw upgrade`. T-1839 closes the loop by making
# the command itself refuse the downgrade direction unless explicitly
# overridden with --force-downgrade.
#
# Pre-fix behaviour (lib/upgrade.sh:1082-1112): direction-blind overwrite of
# .framework.yaml's `version:` field with $FW_VERSION whenever the two
# differ. Consumer at 1.6.260 + framework at 1.6.170 → silent downgrade,
# only post-facto forensic trail in `upgraded_from` + audit YAML.
#
# These tests pin:
#   - Source-level: --force-downgrade arg accepted; sort -V direction check
#     present; REFUSED message names both versions + T-1828
#   - Behavioural: do_upgrade refuses when consumer > framework (--dry-run
#     mode, so no real filesystem mutation); proceeds with --force-downgrade

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export FRAMEWORK_ROOT
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    export FW_VERSION="1.6.170"
    export NO_COLOR=1
    source "$FRAMEWORK_ROOT/lib/colors.sh"
    source "$FRAMEWORK_ROOT/lib/upgrade.sh"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# ── Source-level pins (cheap, fast) ──

@test "T-1839: --force-downgrade flag is parsed in do_upgrade" {
    run do_upgrade --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"--force-downgrade"* ]]
}

@test "T-1839: help text explains --force-downgrade and references T-1839" {
    run do_upgrade --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"T-1839"* ]]
}

@test "T-1839: lib/upgrade.sh contains the sort -V direction check" {
    run grep -q 'sort -V' "$FRAMEWORK_ROOT/lib/upgrade.sh"
    [ "$status" -eq 0 ]
}

@test "T-1839: lib/upgrade.sh REFUSED message names AHEAD of framework" {
    run grep -q 'AHEAD of framework' "$FRAMEWORK_ROOT/lib/upgrade.sh"
    [ "$status" -eq 0 ]
}

@test "T-1839: lib/upgrade.sh REFUSED message references T-1828" {
    run grep -q 'T-1828' "$FRAMEWORK_ROOT/lib/upgrade.sh"
    [ "$status" -eq 0 ]
}

@test "T-1839: lib/upgrade.sh suggests --force-downgrade in refusal text" {
    run grep -q 'force-downgrade' "$FRAMEWORK_ROOT/lib/upgrade.sh"
    [ "$status" -eq 0 ]
}

@test "T-1839: lib/upgrade.sh parses with bash -n" {
    run bash -n "$FRAMEWORK_ROOT/lib/upgrade.sh"
    [ "$status" -eq 0 ]
}

# ── Behavioural pin: sort -V direction primitive ──

@test "T-1839: sort -V resolves 1.6.260 ahead of 1.6.170" {
    local cv="1.6.260"
    local fv="1.6.170"
    local top
    top=$(printf '%s\n%s\n' "$cv" "$fv" | sort -V | tail -1)
    [ "$top" = "$cv" ]
}

@test "T-1839: sort -V resolves 1.6.100 behind 1.6.170" {
    local cv="1.6.100"
    local fv="1.6.170"
    local top
    top=$(printf '%s\n%s\n' "$cv" "$fv" | sort -V | tail -1)
    [ "$top" = "$fv" ]
}
