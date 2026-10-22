#!/usr/bin/env bats
# Integration tests for fw costs
# Origin: T-947
#
# T-4618: every test owns its HOME and PROJECT_ROOT. fw costs reads
# $HOME/.claude/projects/<encoded PROJECT_ROOT>/*.jsonl (lib/paths.sh
# fw_claude_project_dirs), so without a fixture the tests measured the
# operator's live transcripts and failed on any host without them.

load ../test_helper

FW="$FRAMEWORK_ROOT/bin/fw"
FIXTURE_SESSION="t4618fx-0000-4000-8000-000000000001"

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    TEST_TEMP_DIR="$(cd "$TEST_TEMP_DIR" && pwd -P)"
    export HOME="$TEST_TEMP_DIR/home"
    export PROJECT_ROOT="$TEST_TEMP_DIR/project"
    guard_project_root
    export FRAMEWORK_ROOT
    mkdir -p "$HOME" "$PROJECT_ROOT/.tasks/active" "$PROJECT_ROOT/.tasks/completed"
    mkdir -p "$PROJECT_ROOT/.context/working" "$PROJECT_ROOT/.context/project"
    echo "framework_root: $FRAMEWORK_ROOT" > "$PROJECT_ROOT/.framework.yaml"

    # One session, two turns of 100 input + 1000 cache read + 200 cache create
    # + 50 output = 1350 tokens each, 2700 (2.7K) in total.
    local tdir="$HOME/.claude/projects/$(printf '%s' "$PROJECT_ROOT" | tr -c 'a-zA-Z0-9' '-')"
    mkdir -p "$tdir"
    local turn='{"timestamp":"2026-10-01T10:00:00Z","message":{"model":"claude-test","usage":{"input_tokens":100,"cache_read_input_tokens":1000,"cache_creation_input_tokens":200,"output_tokens":50}}}'
    printf '%s\n%s\n' "$turn" "$turn" > "$tdir/$FIXTURE_SESSION.jsonl"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

@test "fw costs help shows usage" {
    run "$FW" costs help
    [ "$status" -eq 0 ]
    [[ "$output" == *"fw costs"* ]]
    [[ "$output" == *"session"* ]]
    [[ "$output" == *"current"* ]]
}

@test "fw costs shows project summary" {
    run "$FW" costs
    [ "$status" -eq 0 ]
    [[ "$output" == *"Sessions:         1"* ]]
    [[ "$output" == *"Total turns:      2"* ]]
    [[ "$output" == *"2.7K"* ]]
}

@test "fw costs session shows table" {
    run "$FW" costs session
    [ "$status" -eq 0 ]
    [[ "$output" == *"${FIXTURE_SESSION:0:8}"* ]]
    [[ "$output" == *"2.7K"* ]]
}

@test "fw costs current shows current session" {
    run "$FW" costs current
    [ "$status" -eq 0 ]
    [[ "$output" == *"Session:    ${FIXTURE_SESSION:0:8}"* ]]
    [[ "$output" == *"Total:      2.7K tokens"* ]]
}

# PROJECT_ROOT is not a git repo, so there is one candidate dir. Its absence
# used to end fw costs with exit 1 and no output at all (set -e on the failed
# candidate test in lib/paths.sh fw_claude_project_dirs).
@test "fw costs with no transcripts fails with a stated reason" {
    rm -rf "$HOME/.claude"
    run "$FW" costs
    [ "$status" -ne 0 ]
    [[ "$output" == *"No JSONL directory found"* ]]
}
