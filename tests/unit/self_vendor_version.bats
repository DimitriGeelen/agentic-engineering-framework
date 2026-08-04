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

@test "fw vendor self SYNCS a drifted VERSION" {
    cd "$BATS_TEST_DIRNAME/../.."
    unset FRAMEWORK_ROOT
    orig="$(cat .agentic-framework/VERSION)"
    echo "0.0.0-drift" > .agentic-framework/VERSION
    run bin/fw vendor self
    after="$(cat .agentic-framework/VERSION)"
    printf '%s' "$orig" > .agentic-framework/VERSION
    [ "$status" -eq 0 ]
    [ "$after" != "0.0.0-drift" ]
}

@test "fw vendor self --check does NOT flag VERSION (sync-only by design)" {
    # VERSION is rewritten in the working tree on every commit, so a checked
    # class would go red again the instant you commit the sync that cleared it —
    # the pre-push gate refuses, the fix re-breaks it. Knowingly the
    # unwitnessable-check shape (T-2726); the alternative is an unsatisfiable
    # gate. This test pins the choice so it cannot be reverted by accident.
    cd "$BATS_TEST_DIRNAME/../.."
    unset FRAMEWORK_ROOT
    orig="$(cat .agentic-framework/VERSION)"
    echo "0.0.0-drift" > .agentic-framework/VERSION
    run bin/fw vendor self --check
    after="$(cat .agentic-framework/VERSION)"
    printf '%s' "$orig" > .agentic-framework/VERSION
    # --check is read-only and must stay so.
    [ "$after" = "0.0.0-drift" ]
    [ "$status" -eq 0 ]
    [[ "$output" != *"would sync VERSION"* ]]
}
