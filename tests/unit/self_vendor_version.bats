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

# T-3808: the two CLI tests below used to cd into the LIVE repo, overwrite the
# real .agentic-framework/VERSION and run a whole-tree `fw vendor self [--check]`.
# Any unrelated uncommitted vendored drift (another worker's edit) then reddened
# the --check test, and the plain run synced the live tree as a side effect.
# They now run the real bin/fw against a minimal fixture root: a COPY of bin/fw
# (FRAMEWORK_ROOT is derived from its real path), lib/ and agents/ symlinked so it
# runs, and a .agentic-framework/ holding only VERSION — every content class
# early-exits on its missing vendored subdirectory, so only VERSION is in play.
_fixture_root() {
    local repo="$BATS_TEST_DIRNAME/../.."
    FIX="$TEST_TEMP_DIR/fix"
    mkdir -p "$FIX/bin" "$FIX/.agentic-framework"
    cp "$repo/bin/fw" "$FIX/bin/fw"
    ln -s "$(cd "$repo" && pwd)/lib" "$FIX/lib"
    ln -s "$(cd "$repo" && pwd)/agents" "$FIX/agents"
    cp "$repo/FRAMEWORK.md" "$FIX/FRAMEWORK.md"
    echo "9.9.9" > "$FIX/VERSION"
    echo "0.0.0-drift" > "$FIX/.agentic-framework/VERSION"
    unset FRAMEWORK_ROOT PROJECT_ROOT CLAUDE_PROJECT_DIR
    cd "$FIX"
}

@test "fw vendor self SYNCS a drifted VERSION" {
    _fixture_root
    run bin/fw vendor self
    [ "$status" -eq 0 ]
    [ "$(cat .agentic-framework/VERSION)" = "9.9.9" ]
}

@test "fw vendor self --check does NOT flag VERSION (sync-only by design)" {
    # VERSION is rewritten in the working tree on every commit, so a checked
    # class would go red again the instant you commit the sync that cleared it —
    # the pre-push gate refuses, the fix re-breaks it. Knowingly the
    # unwitnessable-check shape (T-2726); the alternative is an unsatisfiable
    # gate. This test pins the choice so it cannot be reverted by accident.
    _fixture_root
    run bin/fw vendor self --check
    # --check is read-only and must stay so.
    [ "$(cat .agentic-framework/VERSION)" = "0.0.0-drift" ]
    [ "$status" -eq 0 ]
    [[ "$output" != *"would sync VERSION"* ]]
}

@test "T-3808: unrelated vendored drift is reported by --check but never VERSION" {
    # Regression: the assertion is about the VERSION class only. Another class
    # drifting (here a root data file) must surface as that class's drift, and
    # VERSION must still be neither flagged nor written.
    _fixture_root
    echo "src" > status-transitions.yaml
    echo "stale" > .agentic-framework/status-transitions.yaml
    run bin/fw vendor self --check
    [ "$status" -eq 1 ]
    [[ "$output" == *"would sync 1 root data file(s)"* ]]
    [[ "$output" != *"VERSION"* ]]
    [ "$(cat .agentic-framework/VERSION)" = "0.0.0-drift" ]
}
