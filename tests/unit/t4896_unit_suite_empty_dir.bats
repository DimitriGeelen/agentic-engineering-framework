#!/usr/bin/env bats
# T-4896: unit-suite.sh with a missing or empty suite dir must be NOT EVALUATED (exit 3)
# and must not replace a real LATEST.yaml. Origin: 055 ran it by hand in a consumer without
# FW_UNIT_SUITE_DIR; it ran 0 files, reported runner_exit=0 and overwrote LATEST.yaml, so the
# pre-push ratchet graded an empty run as clean.

load ../test_helper

RUNNER="$BATS_TEST_DIRNAME/../../agents/audit/unit-suite.sh"

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    PROJ="$TEST_TEMP_DIR/proj"
    REPORTS="$PROJ/.context/audits/unit-suite"
    mkdir -p "$REPORTS" "$PROJ/.context/locks"
    printf 'schema: unit-suite-report-v2\nrunner_exit: 1\nmarker: real-previous-run\n' > "$REPORTS/LATEST.yaml"
    cp "$REPORTS/LATEST.yaml" "$REPORTS/LAST-COMPLETE.yaml"
    BEFORE="$(sha256sum "$REPORTS/LATEST.yaml" "$REPORTS/LAST-COMPLETE.yaml")"
}

teardown() { rm -rf "$TEST_TEMP_DIR"; }

_run_suite() {
    run env -u FW_UNIT_SUITE_TIER PROJECT_ROOT="$PROJ" FW_UNIT_SUITE_DIR="$1" \
        FW_UNIT_SUITE_REPORT_DIR="$REPORTS" FW_UNIT_SUITE_LOCK="$PROJ/.context/locks/us.lock" \
        FW_UNIT_SUITE_TIMEOUT=300 FW_UNIT_SUITE_JOBS=1 bash "$RUNNER"
}

@test "missing suite dir: exit 3, NOT EVALUATED, LATEST.yaml untouched" {
    _run_suite "$TEST_TEMP_DIR/nope"
    [ "$status" -eq 3 ]
    [[ "$output" == *"NOT EVALUATED"* ]]
    [[ "$output" == *"does not exist"* ]]
    [[ "$output" == *"FW_UNIT_SUITE_DIR"* ]]
    [ "$(sha256sum "$REPORTS/LATEST.yaml" "$REPORTS/LAST-COMPLETE.yaml")" = "$BEFORE" ]
    [ "$(ls "$REPORTS" | sort | tr '\n' ' ')" = "LAST-COMPLETE.yaml LATEST.yaml " ]
}

@test "suite dir with no test files: exit 3, LATEST.yaml untouched" {
    mkdir -p "$TEST_TEMP_DIR/empty"
    echo "not a test" > "$TEST_TEMP_DIR/empty/README.md"
    _run_suite "$TEST_TEMP_DIR/empty"
    [ "$status" -eq 3 ]
    [[ "$output" == *"contains no test files"* ]]
    [ "$(sha256sum "$REPORTS/LATEST.yaml" "$REPORTS/LAST-COMPLETE.yaml")" = "$BEFORE" ]
}

@test "control: a dir with one passing .bats file runs and writes LATEST.yaml" {
    mkdir -p "$TEST_TEMP_DIR/suite"
    printf '#!/usr/bin/env bats\n@test "ok" { true; }\n' > "$TEST_TEMP_DIR/suite/ok.bats"
    _run_suite "$TEST_TEMP_DIR/suite"
    [ "$status" -ne 3 ]
    ! grep -q "real-previous-run" "$REPORTS/LATEST.yaml"
}
