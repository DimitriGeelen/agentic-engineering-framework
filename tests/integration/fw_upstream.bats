#!/usr/bin/env bats
# Integration tests for fw upstream subcommand
#
# Tests help, config, status, report guards, list, and error handling.
# Network-dependent operations (gh issue create) are tested only in dry-run mode.

load ../test_helper

FW="$FRAMEWORK_ROOT/bin/fw"

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    guard_project_root
    export FRAMEWORK_ROOT
    export NO_COLOR=1
    mkdir -p "$PROJECT_ROOT/.tasks/active" "$PROJECT_ROOT/.tasks/completed"
    mkdir -p "$PROJECT_ROOT/.context/working" "$PROJECT_ROOT/.context/project"
    echo "framework_root: $FRAMEWORK_ROOT" > "$PROJECT_ROOT/.framework.yaml"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

_run_fw() {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' NO_COLOR=1 '$FW' upstream $*"
}

# --- Help ---

@test "fw upstream: no subcommand shows help" {
    _run_fw ""
    [ "$status" -eq 0 ]
    [[ "$output" == *"upstream"* ]]
    [[ "$output" == *"config"* ]]
    [[ "$output" == *"report"* ]]
    [[ "$output" == *"list"* ]]
}

@test "fw upstream --help: shows help" {
    _run_fw "--help"
    [ "$status" -eq 0 ]
    [[ "$output" == *"upstream"* ]]
}

@test "fw upstream help: shows help" {
    _run_fw "help"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Subcommands"* ]]
}

@test "fw upstream: help shows examples" {
    _run_fw "help"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Examples"* ]]
    [[ "$output" == *"--dry-run"* ]]
}

@test "fw upstream: unknown subcommand fails" {
    _run_fw "bogus"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Unknown upstream subcommand"* ]]
}

# --- Config ---

@test "fw upstream config: shows configuration" {
    _run_fw "config"
    [[ "$output" == *"Upstream"* ]] || [[ "$output" == *"Configuration"* ]] || [[ "$output" == *"Repo"* ]]
}

@test "fw upstream config --repo: sets upstream repo" {
    _run_fw "config --repo TestOwner/TestRepo"
    [ "$status" -eq 0 ]
    grep -q "upstream_repo: TestOwner/TestRepo" "$PROJECT_ROOT/.framework.yaml"
}

@test "fw upstream config --repo: rejects invalid format" {
    _run_fw "config --repo not-valid"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Invalid repo format"* ]]
}

@test "fw upstream config --repo: accepts hyphenated names" {
    _run_fw "config --repo my-org/my-repo"
    [ "$status" -eq 0 ]
    grep -q "upstream_repo: my-org/my-repo" "$PROJECT_ROOT/.framework.yaml"
}

@test "fw upstream config: shows repo after setting" {
    bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' NO_COLOR=1 '$FW' upstream config --repo TestOwner/TestRepo" >/dev/null
    _run_fw "config"
    [ "$status" -eq 0 ]
    [[ "$output" == *"TestOwner/TestRepo"* ]]
}

@test "fw upstream config: shows auth status" {
    _run_fw "config"
    # Should mention auth (either configured or not)
    [[ "$output" == *"Auth"* ]] || [[ "$output" == *"auth"* ]] || [[ "$output" == *"gh"* ]]
}

# --- Status ---

@test "fw upstream status: works (alias for config)" {
    _run_fw "status"
    [[ "$output" == *"Upstream"* ]] || [[ "$output" == *"Configuration"* ]] || [[ "$output" == *"Repo"* ]]
}

# --- Report ---

@test "fw upstream report: requires --title" {
    _run_fw "report"
    [ "$status" -eq 1 ]
    [[ "$output" == *"--title is required"* ]]
}

@test "fw upstream report --dry-run: shows preview" {
    bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' NO_COLOR=1 '$FW' upstream config --repo TestOwner/TestRepo" >/dev/null
    _run_fw "report --title 'Test bug report' --dry-run"
    [ "$status" -eq 0 ]
    [[ "$output" == *"DRY RUN"* ]]
    [[ "$output" == *"Test bug report"* ]]
    [[ "$output" == *"TestOwner/TestRepo"* ]]
}

@test "fw upstream report --dry-run: includes body" {
    bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' NO_COLOR=1 '$FW' upstream config --repo TestOwner/TestRepo" >/dev/null
    _run_fw "report --title 'Bug' --body 'Detailed description' --dry-run"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Detailed description"* ]]
}

@test "fw upstream report --dry-run: includes context metadata" {
    bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' NO_COLOR=1 '$FW' upstream config --repo TestOwner/TestRepo" >/dev/null
    _run_fw "report --title 'Bug' --dry-run"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Framework version"* ]]
}

@test "fw upstream report: rejects unknown option" {
    _run_fw "report --bogus"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Unknown option"* ]]
}

# --- List ---

@test "fw upstream list: empty when no issues sent" {
    _run_fw "list"
    [ "$status" -eq 0 ]
    [[ "$output" == *"No upstream issues sent"* ]]
}

@test "fw upstream list: shows sent issues" {
    mkdir -p "$PROJECT_ROOT/.context/working"
    echo "2026-03-30T12:00:00Z | https://github.com/test/repo/issues/1 | Test issue" > "$PROJECT_ROOT/.context/working/.upstream-issues-sent"
    _run_fw "list"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Upstream Issues Sent"* ]]
    [[ "$output" == *"Test issue"* ]]
}
