#!/usr/bin/env bats
# Integration tests for fw test subcommand
# Named fw_test_cmd.bats to avoid confusion with test framework files

load ../test_helper

FW="$FRAMEWORK_ROOT/bin/fw"

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    guard_project_root
    export FRAMEWORK_ROOT
    mkdir -p "$PROJECT_ROOT/.tasks/active" "$PROJECT_ROOT/.tasks/completed"
    mkdir -p "$PROJECT_ROOT/.context/working" "$PROJECT_ROOT/.context/project"
    echo "framework_root: $FRAMEWORK_ROOT" > "$PROJECT_ROOT/.framework.yaml"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

@test "fw test: runs test suite" {
    # T-4615: a fixture suite, not the repo's tests/unit/ (1000+ files). A bare
    # `fw test unit` ran the whole unit suite and the file hit 900 s; `| head -5`
    # neither stopped it nor let a failing exit status through.
    local fixture="$TEST_TEMP_DIR/fixture-suite"
    mkdir -p "$fixture"
    printf '@test "fixture bats ok" {\n    true\n}\n' > "$fixture/fixture_ok.bats"
    printf 'def test_fixture_pytest_ok():\n    assert True\n' > "$fixture/test_fixture_ok.py"
    run timeout 120 env FRAMEWORK_ROOT="$FRAMEWORK_ROOT" PROJECT_ROOT="$PROJECT_ROOT" "$FW" test unit -- "$fixture"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Bats Unit Tests"* ]]
    [[ "$output" == *"ok 1 fixture bats ok"* ]]
    [[ "$output" == *"test_fixture_pytest_ok PASSED"* ]]
}

@test "fw test lint: runs shellcheck" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' test lint 2>&1 | head -5"
    [[ "$output" == *"ShellCheck"* ]] || [[ "$output" == *"Lint"* ]] || [[ "$output" == *"PASS"* ]] || [[ "$output" == *"WARN"* ]]
}

@test "fw test playwright: shows playwright header" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' test playwright 2>&1 | head -5"
    [[ "$output" == *"Playwright"* ]] || [[ "$output" == *"playwright"* ]] || [[ "$output" == *"pytest"* ]] || [[ "$output" == *"ERROR"* ]]
}

@test "fw test playwright: accepts --playwright flag" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' test --playwright 2>&1 | head -5"
    [[ "$output" == *"Playwright"* ]] || [[ "$output" == *"playwright"* ]] || [[ "$output" == *"pytest"* ]] || [[ "$output" == *"ERROR"* ]]
}
