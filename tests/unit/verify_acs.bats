#!/usr/bin/env bats
# Unit tests for fw verify-acs (T-824)

setup() {
    FRAMEWORK_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    export FRAMEWORK_ROOT
    export PROJECT_ROOT="$FRAMEWORK_ROOT"
}

@test "verify-acs: help flag works" {
    run bash -c "source '$FRAMEWORK_ROOT/lib/verify-acs.sh' && do_verify_acs --help"
    [ "$status" -eq 0 ]
    [[ "$output" == *"verify-acs"* ]]
    [[ "$output" == *"RUBBER-STAMP"* ]]
}

@test "verify-acs: accepts --verbose flag" {
    run bash -c "source '$FRAMEWORK_ROOT/lib/verify-acs.sh' && do_verify_acs --verbose 2>&1 | head -3"
    [ "$status" -eq 0 ]
    [[ "$output" == *"verify-acs"* ]]
}

@test "verify-acs: accepts task ID filter" {
    run bash -c "source '$FRAMEWORK_ROOT/lib/verify-acs.sh' && do_verify_acs T-999 2>&1"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Summary"* ]]
}

@test "verify-acs: shows summary with counts" {
    run bash -c "source '$FRAMEWORK_ROOT/lib/verify-acs.sh' && do_verify_acs 2>&1"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Total ACs scanned"* ]]
    [[ "$output" == *"PASS"* ]]
    [[ "$output" == *"SKIP"* ]]
    [[ "$output" == *"REVIEW"* ]]
}

@test "verify-acs: rejects unknown flags" {
    run bash -c "source '$FRAMEWORK_ROOT/lib/verify-acs.sh' && do_verify_acs --bogus 2>&1"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Unknown option"* ]]
}

@test "verify-acs: fw route works" {
    run "$FRAMEWORK_ROOT/bin/fw" verify-acs --help 2>&1
    [ "$status" -eq 0 ]
    [[ "$output" == *"verify-acs"* ]]
}
