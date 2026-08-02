#!/usr/bin/env bats
# T-2703 / T-2740 — greenfield seed conformance. LIVE guard, tracked in git.
#
# Authored T-2703 as inception evidence and left deliberately RED. T-2740 fixed
# the drift it found and turned it green. Filename kept (OBS-131 refers to it)
# even though "prototype" no longer describes it.
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
# Left as .bats (not .bats.disabled) so `bats tests/unit/` picks it up and any
# future failure is visible — do not quietly skip it.
#
# Why this shape and not a list of required sections per seed: the assertion is
# made by running the REAL `fw audit` against a REALLY seeded project. Any
# control added to audit.sh later applies here automatically. A hand-maintained
# list of expected sections would only ever cover the controls its author had in
# hand — which is precisely how CTL-027 (T-1263) drifted past the seeds for
# months while the canonical templates in .tasks/templates/ stayed current.

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

@test "T-2740: no seed is missing its Updates section" {
    # exit <= 1 tolerates WARNs, so the FAIL test above passes while four seeds
    # are still non-conformant. T-001 carried ## Updates and T-002..T-005 did
    # not — partial drift, which is why it never read as a systematic break.
    local proj="$TEST_TEMP_DIR/proj"
    mkdir -p "$proj"
    run "$FRAMEWORK_ROOT/bin/fw" init "$proj"
    [ "$status" -eq 0 ]

    run seeded_run "$proj" audit
    echo "$output"
    # premise: the audit actually reached the task-section checks
    [[ "$output" == *"SUMMARY"* ]]
    [[ "$output" != *"missing Updates section"* ]]
}

@test "T-2740: every seeded task carries the sections its own audit demands" {
    # The generalisation of the two tests above: whatever audit.sh checks about
    # task structure, a freshly seeded project satisfies it. Asserted on the
    # absence of any FAIL line, so a new hard control fires here on its first
    # run rather than on some consumer's first `fw audit`.
    local proj="$TEST_TEMP_DIR/proj"
    mkdir -p "$proj"
    run "$FRAMEWORK_ROOT/bin/fw" init "$proj"
    [ "$status" -eq 0 ]

    run seeded_run "$proj" audit
    echo "$output"
    [[ "$output" == *"SUMMARY"* ]]
    [[ "$output" != *"[FAIL]"* ]]
}
