#!/usr/bin/env bats
# T-2444 (F5, T-2442 batch): `fw init` must activate the session on the
# greenfield happy path — no "Session init failed — run 'fw context init'
# manually" on a first run.
#
# Regression origin: T-2441 onboarding dogfood. lib/init.sh activated governance
# by invoking agents/context/context.sh directly with only PROJECT_ROOT set;
# context.sh runs `set -euo pipefail` and needs the env bin/fw exports, so it
# aborted inline while the `fw context init` recovery (same script via bin/fw)
# succeeded — and a `2>/dev/null` masked the error. Fix routes the inline
# activation through the project's vendored fw and surfaces stderr.

load ../test_helper

setup() {
    unset PROJECT_ROOT  # L-456: avoid project-root leak from the parent shell
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# ------------------------------------------------------------- contract test
# The silent direct-script call is gone and activation routes through the fw
# `context init` entry point (the same path the recovery uses). Fast,
# deterministic, no full init run.
@test "F5: inline activation routes through fw 'context init', no silent 2>/dev/null" {
    # The old silent direct-script invocation must be gone.
    local rc=0
    grep -nE 'context\.sh" init 2>/dev/null' "$FRAMEWORK_ROOT/lib/init.sh" || rc=$?
    [ "$rc" -ne 0 ]

    # Activation must route through the fw `context init` verb.
    grep -q 'context init' "$FRAMEWORK_ROOT/lib/init.sh"
}

# ------------------------------------------------------------------ e2e test
# A real fresh `fw init` into an empty dir must reach the success line and not
# the failure line, and must leave a session.yaml behind.
@test "F5: fresh fw init activates the session (no 'Session init failed')" {
    run "$FRAMEWORK_ROOT/bin/fw" init "$TEST_TEMP_DIR" --provider claude

    # The greenfield happy path must report success, not the manual-recovery warning.
    echo "$output" | grep -q "Session initialized (governance active)"
    local rc=0
    echo "$output" | grep -q "Session init failed" || rc=$?
    [ "$rc" -ne 0 ]

    # Working memory was actually written.
    [ -f "$TEST_TEMP_DIR/.context/working/session.yaml" ]
}
