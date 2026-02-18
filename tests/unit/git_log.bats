#!/usr/bin/env bats
# Unit tests for agents/git/lib/log.sh
#
# Tests: do_log (argument parsing, git log filtering, traceability),
#        show_log_help, show_traceability

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    mkdir -p "$PROJECT_ROOT/.tasks/active" "$PROJECT_ROOT/.context"
    export TASKS_DIR="$PROJECT_ROOT/.tasks"
    export CONTEXT_DIR="$PROJECT_ROOT/.context"
    # Disable colors for predictable output matching
    RED='' GREEN='' YELLOW='' CYAN='' NC=''

    # Create a git repo with known commits
    cd "$PROJECT_ROOT"
    git init -q
    git config user.email "test@test.com"
    git config user.name "Test"
    echo "a" > file.txt && git add . && git commit -q -m "T-001: First commit"
    echo "b" > file.txt && git add . && git commit -q -m "T-002: Second commit"
    echo "c" > file.txt && git add . && git commit -q -m "No task ref commit"

    source "$FRAMEWORK_ROOT/agents/git/lib/common.sh"
    source "$FRAMEWORK_ROOT/agents/git/lib/log.sh"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# --- do_log with no arguments (default) ---

@test "do_log: with no args shows recent commits" {
    run do_log
    [ "$status" -eq 0 ]
    [[ "$output" == *"Recent Commits"* ]]
    [[ "$output" == *"T-001: First commit"* ]]
    [[ "$output" == *"T-002: Second commit"* ]]
    [[ "$output" == *"No task ref commit"* ]]
}

# --- do_log --task ---

@test "do_log: --task T-001 filters to that task only" {
    run do_log --task T-001
    [ "$status" -eq 0 ]
    [[ "$output" == *"Commits for T-001"* ]]
    [[ "$output" == *"T-001: First commit"* ]]
    [[ "$output" != *"T-002: Second commit"* ]]
    [[ "$output" != *"No task ref commit"* ]]
}

@test "do_log: -t short flag works same as --task" {
    run do_log -t T-002
    [ "$status" -eq 0 ]
    [[ "$output" == *"Commits for T-002"* ]]
    [[ "$output" == *"T-002: Second commit"* ]]
    [[ "$output" != *"T-001: First commit"* ]]
}

@test "do_log: --task with nonexistent ID returns no commits" {
    run do_log --task T-999
    [ "$status" -eq 0 ]
    [[ "$output" == *"Commits for T-999"* ]]
    # Should not contain any commit lines (only the header)
    [[ "$output" != *"First commit"* ]]
    [[ "$output" != *"Second commit"* ]]
}

# --- do_log -n ---

@test "do_log: -n 1 limits output to one commit" {
    run do_log -n 1
    [ "$status" -eq 0 ]
    # Most recent commit should be shown
    [[ "$output" == *"No task ref commit"* ]]
    # Older commits should not appear
    [[ "$output" != *"T-001: First commit"* ]]
}

@test "do_log: -n 2 shows exactly two commits" {
    run do_log -n 2
    [ "$status" -eq 0 ]
    # Two most recent should appear
    [[ "$output" == *"No task ref commit"* ]]
    [[ "$output" == *"T-002: Second commit"* ]]
    # Oldest should not appear
    [[ "$output" != *"T-001: First commit"* ]]
}

# --- do_log --traceability ---

@test "do_log: --traceability shows traceability report" {
    run do_log --traceability
    [ "$status" -eq 0 ]
    [[ "$output" == *"Git Traceability Report"* ]]
    [[ "$output" == *"Total commits:"* ]]
    [[ "$output" == *"With task ref:"* ]]
    [[ "$output" == *"Traceability:"* ]]
}

# --- show_traceability ---

@test "show_traceability: calculates correct stats (2 of 3 = 66%)" {
    run show_traceability
    [ "$status" -eq 0 ]
    [[ "$output" == *"Total commits:     3"* ]]
    [[ "$output" == *"With task ref:     2"* ]]
    [[ "$output" == *"Traceability:      66%"* ]]
}

@test "show_traceability: lists orphan commits without task refs" {
    run show_traceability
    [ "$status" -eq 0 ]
    [[ "$output" == *"Commits without task references:"* ]]
    [[ "$output" == *"No task ref commit"* ]]
}

@test "show_traceability: all commits traced shows success message" {
    cd "$PROJECT_ROOT"
    # Amend the orphan commit to include a task ref
    git commit --amend -q -m "T-003: Now has task ref"
    run show_traceability
    [ "$status" -eq 0 ]
    [[ "$output" == *"All commits have task references!"* ]]
    [[ "$output" == *"Traceability:      100%"* ]]
}

# --- show_log_help ---

@test "show_log_help: outputs usage text" {
    run show_log_help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Git Agent - Log Command"* ]]
    [[ "$output" == *"Usage:"* ]]
    [[ "$output" == *"--task"* ]]
    [[ "$output" == *"--traceability"* ]]
    [[ "$output" == *"-n COUNT"* ]]
}

@test "show_log_help: includes examples" {
    run show_log_help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Examples:"* ]]
    [[ "$output" == *"git.sh log --task T-003"* ]]
}

# --- do_log -h (help via arg) ---

@test "do_log: -h shows help and exits 0" {
    run do_log -h
    [ "$status" -eq 0 ]
    [[ "$output" == *"Git Agent - Log Command"* ]]
}

# --- do_log unknown option ---

@test "do_log: unknown option exits with error" {
    run do_log --bogus
    [ "$status" -eq 1 ]
    [[ "$output" == *"Unknown option: --bogus"* ]]
}
