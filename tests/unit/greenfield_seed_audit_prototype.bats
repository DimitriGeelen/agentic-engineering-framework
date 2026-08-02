#!/usr/bin/env bats
# T-2703 PROTOTYPE — NOT wired into CI yet. Inception evidence only.
#
# Guards the specific class this RCA found: `fw init` (greenfield mode) seeds
# .tasks/active/T-001..T-005 from lib/seeds/tasks/greenfield/*.md, a SEPARATE
# hardcoded template set from .tasks/templates/{default,inception}.md. When
# audit.sh grows a new hard-FAIL control (e.g. CTL-027, T-1263) the seed
# templates are not automatically kept in sync — nothing runs `fw audit`
# against a freshly seeded project to catch the drift.
#
# This test seeds a real greenfield project via the framework's own `fw init`
# and asserts `fw audit` exits <= 1 (warnings only, never a hard FAIL) on the
# UNTOUCHED result — i.e. before any agent has done a stroke of work.
#
# Status as of authoring (2026-07-31): RED. See docs/reports/T-2703-*.md for
# the full RCA. Left as .bats (not .bats.disabled) so `bats tests/unit/` picks
# it up and the failure is visible — do not quietly skip it.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d -t fw-greenfield-seed-XXXXXX)"
    export FRAMEWORK_ROOT
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# Run a command against the seeded project's OWN vendored fw, in a scrubbed
# env — no inherited PROJECT_ROOT/FRAMEWORK_ROOT (T-2703 finding: a dispatch
# environment that pre-exports PROJECT_ROOT makes `fw` in a freshly-seeded
# directory silently operate on the WRONG project and hit a stale audit
# lock instead of the seeded one — same fresh_run pattern as
# upgrade_fresh_machine_simulation.bats).
seeded_run() {
    local proj="$1"; shift
    (cd "$proj" && env -i \
        PATH="/usr/local/bin:/usr/bin:/bin" \
        HOME="$TEST_TEMP_DIR/home" \
        "$proj/.agentic-framework/bin/fw" "$@")
}

@test "T-2703 PROTOTYPE: fresh greenfield seed passes its own audit (exit <= 1)" {
    local proj="$TEST_TEMP_DIR/proj"
    mkdir -p "$proj"

    # Seed a real greenfield project using the framework's own fw init.
    run "$FRAMEWORK_ROOT/bin/fw" init "$proj"
    [ "$status" -eq 0 ]

    # Sanity: greenfield mode actually seeded an inception task (T-002).
    # If this ever stops being true the test's premise is void — fail loud
    # rather than silently passing for the wrong reason.
    grep -rq "^workflow_type: inception" "$proj"/.tasks/active/*.md

    run seeded_run "$proj" audit
    echo "audit exit: $status"
    echo "$output"
    [ "$status" -le 1 ]
}
