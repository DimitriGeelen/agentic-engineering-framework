#!/usr/bin/env bats
# T-2289 (OBS-053): lib/paths.sh re-derives TASKS_DIR/CONTEXT_DIR when
# PROJECT_ROOT differs from the value that originally derived them.
#
# Surfaces under test:
#   - lib/paths.sh — _FW_PATHS_DERIVED_BY exported sentinel; unset block fires
#     when sentinel != current PROJECT_ROOT.
#   - Test-fixture invariant: same-shell explicit TASKS_DIR override (no prior
#     derivation, sentinel absent) survives intact.
#
# AC mapping (per .tasks/active/T-2289-*.md):
#   sentinel exported                    — t1
#   env-leak detected and re-derived     — t2
#   fixture invariant preserved          — t3
#   fresh invocation derivation          — t4
#   subprocess PROJECT_ROOT triggers     — t5

load ../test_helper

setup() {
    # Clean any sentinel leaked into the bats runner before each test
    unset _FW_PATHS_LOADED _FW_PATHS_DERIVED_BY TASKS_DIR CONTEXT_DIR
    TEST_TEMP_A="$(mktemp -d -t fw-t2289-A-XXXXXX)"
    TEST_TEMP_B="$(mktemp -d -t fw-t2289-B-XXXXXX)"
}

teardown() {
    [ -d "${TEST_TEMP_A:-}" ] && rm -rf "$TEST_TEMP_A"
    [ -d "${TEST_TEMP_B:-}" ] && rm -rf "$TEST_TEMP_B"
}

@test "t1: paths.sh exports _FW_PATHS_DERIVED_BY after derivation" {
    run bash -c "
        unset _FW_PATHS_LOADED _FW_PATHS_DERIVED_BY TASKS_DIR CONTEXT_DIR
        export PROJECT_ROOT='$TEST_TEMP_A'
        source '$FRAMEWORK_ROOT/lib/paths.sh'
        echo \"DERIVED_BY=\$_FW_PATHS_DERIVED_BY\"
        echo \"TASKS=\$TASKS_DIR\"
    "
    [ "$status" -eq 0 ]
    [[ "$output" == *"DERIVED_BY=$TEST_TEMP_A"* ]]
    [[ "$output" == *"TASKS=$TEST_TEMP_A/.tasks"* ]]
}

@test "t2: env-leak detected and re-derived when PROJECT_ROOT changes" {
    # Simulate: outer shell sources paths with PROJECT_ROOT=A, then a
    # subprocess re-sources with PROJECT_ROOT=B inheriting A's paths.
    run bash -c "
        unset _FW_PATHS_LOADED _FW_PATHS_DERIVED_BY TASKS_DIR CONTEXT_DIR
        export PROJECT_ROOT='$TEST_TEMP_A'
        source '$FRAMEWORK_ROOT/lib/paths.sh'
        # Now simulate subprocess: re-source with new PROJECT_ROOT
        unset _FW_PATHS_LOADED
        export PROJECT_ROOT='$TEST_TEMP_B'
        source '$FRAMEWORK_ROOT/lib/paths.sh'
        echo \"TASKS=\$TASKS_DIR\"
        echo \"CONTEXT=\$CONTEXT_DIR\"
        echo \"DERIVED_BY=\$_FW_PATHS_DERIVED_BY\"
    "
    [ "$status" -eq 0 ]
    [[ "$output" == *"TASKS=$TEST_TEMP_B/.tasks"* ]]
    [[ "$output" == *"CONTEXT=$TEST_TEMP_B/.context"* ]]
    [[ "$output" == *"DERIVED_BY=$TEST_TEMP_B"* ]]
    # Critical: paths must NOT still point at TEST_TEMP_A (env-leak)
    [[ "$output" != *"TASKS=$TEST_TEMP_A/.tasks"* ]]
}

@test "t3: fixture invariant — explicit TASKS_DIR in same shell survives" {
    # Mirrors tests/unit/create_task.bats:18 pattern: setup() exports both
    # PROJECT_ROOT and TASKS_DIR before any prior paths.sh sourcing. No
    # sentinel, so the unset block must be skipped.
    run bash -c "
        unset _FW_PATHS_LOADED _FW_PATHS_DERIVED_BY TASKS_DIR CONTEXT_DIR
        export PROJECT_ROOT='$FRAMEWORK_ROOT'
        export TASKS_DIR='$TEST_TEMP_A/fixture-tasks'
        source '$FRAMEWORK_ROOT/lib/paths.sh'
        echo \"TASKS=\$TASKS_DIR\"
    "
    [ "$status" -eq 0 ]
    [[ "$output" == *"TASKS=$TEST_TEMP_A/fixture-tasks"* ]]
}

@test "t4: fresh invocation derives TASKS_DIR/CONTEXT_DIR from PROJECT_ROOT" {
    run bash -c "
        unset _FW_PATHS_LOADED _FW_PATHS_DERIVED_BY TASKS_DIR CONTEXT_DIR
        export PROJECT_ROOT='$TEST_TEMP_A'
        source '$FRAMEWORK_ROOT/lib/paths.sh'
        echo \"TASKS=\$TASKS_DIR\"
        echo \"CONTEXT=\$CONTEXT_DIR\"
    "
    [ "$status" -eq 0 ]
    [[ "$output" == *"TASKS=$TEST_TEMP_A/.tasks"* ]]
    [[ "$output" == *"CONTEXT=$TEST_TEMP_A/.context"* ]]
}

@test "t5: real subprocess inherits env and re-derives correctly" {
    # End-to-end via bash subshell with explicit env inheritance,
    # mirroring the actual SSH/dispatch leak path.
    run bash -c "
        unset _FW_PATHS_LOADED _FW_PATHS_DERIVED_BY TASKS_DIR CONTEXT_DIR
        export PROJECT_ROOT='$TEST_TEMP_A'
        source '$FRAMEWORK_ROOT/lib/paths.sh'
        # Outer derives A. Now spawn a subprocess with overridden PROJECT_ROOT.
        # _FW_PATHS_DERIVED_BY=A is exported and inherited; TASKS_DIR=A/.tasks
        # is also inherited. _FW_PATHS_LOADED is NOT exported (intentional)
        # so the inner script will run.
        PROJECT_ROOT='$TEST_TEMP_B' bash -c '
            source \"$FRAMEWORK_ROOT/lib/paths.sh\"
            echo \"INNER_TASKS=\$TASKS_DIR\"
            echo \"INNER_CONTEXT=\$CONTEXT_DIR\"
            echo \"INNER_DERIVED=\$_FW_PATHS_DERIVED_BY\"
        '
    "
    [ "$status" -eq 0 ]
    [[ "$output" == *"INNER_TASKS=$TEST_TEMP_B/.tasks"* ]]
    [[ "$output" == *"INNER_CONTEXT=$TEST_TEMP_B/.context"* ]]
    [[ "$output" == *"INNER_DERIVED=$TEST_TEMP_B"* ]]
}
