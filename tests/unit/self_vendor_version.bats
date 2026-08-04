#!/usr/bin/env bats
# T-2793 (OBS-151) — VERSION is the seventh self-vendor drift class.
#
# `fw vendor self` synced six classes of CONTENT and never the vendored copy's
# IDENTITY, so .agentic-framework/VERSION kept whatever the last full do_vendor
# wrote. Measured at 1.6.234 against a source at 1.6.114 — a number from a
# different era, which every version comparison downstream treated as fact.
#
# It stops being cosmetic under T-2793: a vendored copy has no .git, so
# _derive_version falls through to VERSION, making that file the only statement
# of which framework a consumer is running.

bats_require_minimum_version 1.5.0

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export FRAMEWORK_ROOT="$TEST_TEMP_DIR/fw"
    mkdir -p "$FRAMEWORK_ROOT/.agentic-framework"
    echo "9.9.9" > "$FRAMEWORK_ROOT/VERSION"
    # shellcheck disable=SC1090
    GREEN=""; NC=""
    source "$BATS_TEST_DIRNAME/../../lib/upgrade.sh" >/dev/null 2>&1 || true
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
    return 0
}

@test "syncs a stale vendored VERSION to the source VERSION" {
    echo "1.2.3" > "$FRAMEWORK_ROOT/.agentic-framework/VERSION"
    run _self_vendor_version false
    [ "$status" -eq 0 ]
    [ "$(cat "$FRAMEWORK_ROOT/.agentic-framework/VERSION")" = "9.9.9" ]
}

@test "creates VERSION when the vendored copy has none" {
    run _self_vendor_version false
    [ "$(cat "$FRAMEWORK_ROOT/.agentic-framework/VERSION")" = "9.9.9" ]
}

@test "dry-run reports the drift and mutates nothing" {
    echo "1.2.3" > "$FRAMEWORK_ROOT/.agentic-framework/VERSION"
    run _self_vendor_version true
    [[ "$output" == *"would sync VERSION"* ]]
    [[ "$output" == *"1.2.3"* ]]
    [[ "$output" == *"9.9.9"* ]]
    [ "$(cat "$FRAMEWORK_ROOT/.agentic-framework/VERSION")" = "1.2.3" ]
}

@test "silent and idempotent when already in sync" {
    echo "9.9.9" > "$FRAMEWORK_ROOT/.agentic-framework/VERSION"
    run _self_vendor_version false
    [ -z "$output" ]
}

@test "no-op in a consumer (no nested .agentic-framework/)" {
    rm -rf "$FRAMEWORK_ROOT/.agentic-framework"
    run _self_vendor_version false
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "syncs the VERSION file, NOT the git-derived version" {
    # Deliberate: $FW_VERSION is `git describe` — commits-since-tag — so syncing
    # it would drift one step after every commit, and the T-2240 pre-push gate
    # would demand a re-vendor whose own commit re-opens the drift. A livelock in
    # a gate whose whole purpose is to be satisfiable. The VERSION file moves only
    # at release, so this class can be both synced AND checked.
    body=$(awk '/^_self_vendor_version\(\)/,/^}/' "$BATS_TEST_DIRNAME/../../lib/upgrade.sh" | sed 's/[[:space:]]*#.*//')
    run bash -c "printf '%s' \"\$body\" | grep -c 'FW_VERSION'"
    [ "$output" = "0" ]
}

@test "fw vendor self --check reports VERSION drift as drift" {
    # End-to-end through the real verb: a class that syncs but is never CHECKED
    # is only ever fixed by someone who already suspected it.
    cd "$BATS_TEST_DIRNAME/../.."
    # setup() exported FRAMEWORK_ROOT at a temp fixture; leaking it here would
    # point the real verb at the wrong tree and grade a different question.
    unset FRAMEWORK_ROOT
    orig="$(cat .agentic-framework/VERSION)"
    echo "0.0.0-drift" > .agentic-framework/VERSION
    run bin/fw vendor self --check
    printf '%s' "$orig" > .agentic-framework/VERSION
    [ "$status" -ne 0 ]
    [[ "$output" == *"VERSION"* ]]
}
