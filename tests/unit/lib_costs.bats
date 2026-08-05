#!/usr/bin/env bats
# Unit tests for lib/costs.sh — token usage tracking from JSONL transcripts
#
# Tests: _costs_jsonl_dir, costs_main routing, Python JSONL parsing, edge cases

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export PROJECT_ROOT="$TEST_TEMP_DIR/project"
    guard_project_root
    export FRAMEWORK_ROOT
    export NO_COLOR=1
    mkdir -p "$PROJECT_ROOT"
    source "$FRAMEWORK_ROOT/lib/costs.sh"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# --- Helper: create a minimal JSONL fixture ---
_create_jsonl_fixture() {
    local dir="$1"
    local session_id="${2:-abc12345-6789-0000-1111-222233334444}"
    local file="$dir/${session_id}.jsonl"
    mkdir -p "$dir"
    cat > "$file" << 'JSONL'
{"type":"system","timestamp":"2026-04-01T10:00:00Z","message":{"role":"system","content":"init"}}
{"type":"assistant","timestamp":"2026-04-01T10:01:00Z","message":{"role":"assistant","model":"claude-sonnet-4-20250514","usage":{"input_tokens":1000,"cache_read_input_tokens":5000,"cache_creation_input_tokens":200,"output_tokens":300},"content":"response 1"}}
{"type":"assistant","timestamp":"2026-04-01T10:02:00Z","message":{"role":"assistant","model":"claude-sonnet-4-20250514","usage":{"input_tokens":800,"cache_read_input_tokens":4000,"cache_creation_input_tokens":100,"output_tokens":250},"content":"response 2"}}
{"type":"assistant","timestamp":"2026-04-01T10:03:00Z","message":{"role":"assistant","model":"claude-sonnet-4-20250514","usage":{"input_tokens":500,"cache_read_input_tokens":3000,"cache_creation_input_tokens":50,"output_tokens":150},"content":"response 3"}}
JSONL
    echo "$file"
}

# ============================================================
# _costs_jsonl_dir — path computation
# ============================================================

@test "costs: _costs_jsonl_dir computes correct path from PROJECT_ROOT" {
    export PROJECT_ROOT="/opt/my-project"
    source "$FRAMEWORK_ROOT/lib/costs.sh"
    result=$(_costs_jsonl_dir)
    [ "$result" = "$HOME/.claude/projects/-opt-my-project" ]
}

@test "costs: _costs_jsonl_dir strips leading dash from path" {
    export PROJECT_ROOT="/foo/bar"
    source "$FRAMEWORK_ROOT/lib/costs.sh"
    result=$(_costs_jsonl_dir)
    [ "$result" = "$HOME/.claude/projects/-foo-bar" ]
}

@test "costs: _costs_jsonl_dir uses pwd when PROJECT_ROOT unset" {
    unset PROJECT_ROOT
    source "$FRAMEWORK_ROOT/lib/costs.sh"
    result=$(_costs_jsonl_dir)
    # Should contain the current working directory translated
    [[ "$result" == "$HOME/.claude/projects/-"* ]]
}

# ============================================================
# costs_main routing
# ============================================================

@test "costs: help subcommand shows usage" {
    run costs_main help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Token usage tracking"* ]]
    [[ "$output" == *"fw costs"* ]]
}

@test "costs: -h flag shows usage" {
    run costs_main -h
    [ "$status" -eq 0 ]
    [[ "$output" == *"Token usage tracking"* ]]
}

@test "costs: --help flag shows usage" {
    run costs_main --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Token usage tracking"* ]]
}

@test "costs: unknown subcommand returns error" {
    run costs_main nonexistent
    [ "$status" -eq 1 ]
    [[ "$output" == *"Unknown costs subcommand"* ]]
}

# ============================================================
# Python JSONL parsing — summary mode
# ============================================================

@test "costs: summary mode shows token counts" {
    local jsonl_dir="$TEST_TEMP_DIR/jsonl"
    _create_jsonl_fixture "$jsonl_dir"

    run _costs_parse_all "$jsonl_dir" "summary"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Token Usage Summary"* ]]
    [[ "$output" == *"Sessions:"* ]]
    [[ "$output" == *"Total turns:"* ]]
    [[ "$output" == *"Fresh input"* ]]
    [[ "$output" == *"Cache read"* ]]
    [[ "$output" == *"Output"* ]]
    [[ "$output" == *"TOTAL"* ]]
}

@test "costs: summary mode calculates correct turn count" {
    local jsonl_dir="$TEST_TEMP_DIR/jsonl"
    _create_jsonl_fixture "$jsonl_dir"

    run _costs_parse_all "$jsonl_dir" "summary"
    [ "$status" -eq 0 ]
    # 3 messages with usage data = 3 turns
    [[ "$output" == *"Total turns:      3"* ]]
}

@test "costs: summary mode reports 1 session" {
    local jsonl_dir="$TEST_TEMP_DIR/jsonl"
    _create_jsonl_fixture "$jsonl_dir"

    run _costs_parse_all "$jsonl_dir" "summary"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Sessions:         1"* ]]
}

# ============================================================
# Python JSONL parsing — sessions mode
# ============================================================

@test "costs: sessions mode shows table header" {
    local jsonl_dir="$TEST_TEMP_DIR/jsonl"
    _create_jsonl_fixture "$jsonl_dir"

    run _costs_parse_all "$jsonl_dir" "sessions"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Session"* ]]
    [[ "$output" == *"Turns"* ]]
    [[ "$output" == *"Input"* ]]
    [[ "$output" == *"TOTAL"* ]]
}

@test "costs: sessions mode shows session ID prefix" {
    local jsonl_dir="$TEST_TEMP_DIR/jsonl"
    _create_jsonl_fixture "$jsonl_dir"

    run _costs_parse_all "$jsonl_dir" "sessions"
    [ "$status" -eq 0 ]
    [[ "$output" == *"abc12345"* ]]
}

# ============================================================
# Python JSONL parsing — session-detail mode
# ============================================================

@test "costs: session-detail mode shows detailed breakdown" {
    local jsonl_dir="$TEST_TEMP_DIR/jsonl"
    _create_jsonl_fixture "$jsonl_dir"

    run _costs_parse_all "$jsonl_dir" "session-detail" "abc12345"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Session abc12345"* ]]
    [[ "$output" == *"Turns:"* ]]
    [[ "$output" == *"Fresh input"* ]]
    [[ "$output" == *"Cache read"* ]]
    [[ "$output" == *"Cache hit rate"* ]]
}

@test "costs: session-detail mode shows correct model" {
    local jsonl_dir="$TEST_TEMP_DIR/jsonl"
    _create_jsonl_fixture "$jsonl_dir"

    run _costs_parse_all "$jsonl_dir" "session-detail" "abc12345"
    [ "$status" -eq 0 ]
    [[ "$output" == *"claude-sonnet"* ]]
}

@test "costs: session-detail with invalid ID fails" {
    local jsonl_dir="$TEST_TEMP_DIR/jsonl"
    _create_jsonl_fixture "$jsonl_dir"

    run _costs_parse_all "$jsonl_dir" "session-detail" "nonexistent"
    [ "$status" -eq 1 ]
    [[ "$output" == *"No session found"* ]]
}

# ============================================================
# Python JSONL parsing — current mode
# ============================================================

@test "costs: current mode shows current session stats" {
    local jsonl_dir="$TEST_TEMP_DIR/jsonl"
    _create_jsonl_fixture "$jsonl_dir"

    run _costs_parse_all "$jsonl_dir" "current"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Current Session"* ]]
    [[ "$output" == *"Turns:"* ]]
    [[ "$output" == *"Total:"* ]]
}

# ============================================================
# Edge cases
# ============================================================

@test "costs: empty directory returns error" {
    local jsonl_dir="$TEST_TEMP_DIR/empty-jsonl"
    mkdir -p "$jsonl_dir"

    run _costs_parse_all "$jsonl_dir" "summary"
    [ "$status" -eq 1 ]
    [[ "$output" == *"No session transcripts"* ]]
}

@test "costs: nonexistent directory returns error" {
    run _costs_parse_all "$TEST_TEMP_DIR/nonexistent" "summary"
    [ "$status" -eq 1 ]
    [[ "$output" == *"No JSONL directory"* ]]
}

@test "costs: malformed JSON lines are skipped gracefully" {
    local jsonl_dir="$TEST_TEMP_DIR/jsonl-bad"
    mkdir -p "$jsonl_dir"
    cat > "$jsonl_dir/test-session.jsonl" << 'JSONL'
not valid json at all
{"type":"assistant","timestamp":"2026-04-01T10:01:00Z","message":{"role":"assistant","model":"claude-sonnet-4-20250514","usage":{"input_tokens":100,"cache_read_input_tokens":200,"cache_creation_input_tokens":50,"output_tokens":30},"content":"ok"}}
{truncated json
JSONL

    run _costs_parse_all "$jsonl_dir" "summary"
    [ "$status" -eq 0 ]
    # Should still show the 1 valid turn
    [[ "$output" == *"Total turns:      1"* ]]
}

@test "costs: messages without usage are skipped" {
    local jsonl_dir="$TEST_TEMP_DIR/jsonl-nousage"
    mkdir -p "$jsonl_dir"
    cat > "$jsonl_dir/test-session.jsonl" << 'JSONL'
{"type":"system","timestamp":"2026-04-01T10:00:00Z","message":{"role":"system","content":"init"}}
{"type":"user","timestamp":"2026-04-01T10:00:30Z","message":{"role":"user","content":"hello"}}
{"type":"assistant","timestamp":"2026-04-01T10:01:00Z","message":{"role":"assistant","model":"claude-sonnet-4-20250514","usage":{"input_tokens":500,"cache_read_input_tokens":1000,"cache_creation_input_tokens":100,"output_tokens":200},"content":"response"}}
JSONL

    run _costs_parse_all "$jsonl_dir" "summary"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Total turns:      1"* ]]
}

@test "costs: synthetic model entries are skipped" {
    local jsonl_dir="$TEST_TEMP_DIR/jsonl-synthetic"
    mkdir -p "$jsonl_dir"
    cat > "$jsonl_dir/test-session.jsonl" << 'JSONL'
{"type":"assistant","timestamp":"2026-04-01T10:01:00Z","message":{"role":"assistant","model":"<synthetic>","usage":{"input_tokens":99999,"cache_read_input_tokens":99999,"cache_creation_input_tokens":99999,"output_tokens":99999},"content":"synthetic"}}
{"type":"assistant","timestamp":"2026-04-01T10:02:00Z","message":{"role":"assistant","model":"claude-sonnet-4-20250514","usage":{"input_tokens":100,"cache_read_input_tokens":200,"cache_creation_input_tokens":50,"output_tokens":30},"content":"real"}}
JSONL

    run _costs_parse_all "$jsonl_dir" "summary"
    [ "$status" -eq 0 ]
    # Only the real entry should count (1 turn)
    [[ "$output" == *"Total turns:      1"* ]]
}

@test "costs: agent- prefixed files are filtered out" {
    local jsonl_dir="$TEST_TEMP_DIR/jsonl-agent"
    mkdir -p "$jsonl_dir"
    # Agent transcript — should be ignored
    cat > "$jsonl_dir/agent-task-abc.jsonl" << 'JSONL'
{"type":"assistant","timestamp":"2026-04-01T10:01:00Z","message":{"role":"assistant","model":"claude-sonnet-4-20250514","usage":{"input_tokens":99999,"cache_read_input_tokens":99999,"cache_creation_input_tokens":99999,"output_tokens":99999},"content":"agent"}}
JSONL
    # Real session — should be counted
    cat > "$jsonl_dir/real-session.jsonl" << 'JSONL'
{"type":"assistant","timestamp":"2026-04-01T10:01:00Z","message":{"role":"assistant","model":"claude-sonnet-4-20250514","usage":{"input_tokens":100,"cache_read_input_tokens":200,"cache_creation_input_tokens":50,"output_tokens":30},"content":"real"}}
JSONL

    run _costs_parse_all "$jsonl_dir" "summary"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Sessions:         1"* ]]
    [[ "$output" == *"Total turns:      1"* ]]
}

@test "costs: multiple sessions are aggregated" {
    local jsonl_dir="$TEST_TEMP_DIR/jsonl-multi"
    _create_jsonl_fixture "$jsonl_dir" "session-aaa"
    _create_jsonl_fixture "$jsonl_dir" "session-bbb"

    run _costs_parse_all "$jsonl_dir" "summary"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Sessions:         2"* ]]
    # 3 turns per session × 2 = 6 total
    [[ "$output" == *"Total turns:      6"* ]]
}

@test "costs: multiple sessions show in table" {
    local jsonl_dir="$TEST_TEMP_DIR/jsonl-multi"
    _create_jsonl_fixture "$jsonl_dir" "session-aaa"
    _create_jsonl_fixture "$jsonl_dir" "session-bbb"

    run _costs_parse_all "$jsonl_dir" "sessions"
    [ "$status" -eq 0 ]
    [[ "$output" == *"session-"* ]]
    [[ "$output" == *"TOTAL"* ]]
}

@test "costs: fmt_tokens formats K correctly" {
    local jsonl_dir="$TEST_TEMP_DIR/jsonl-fmt"
    mkdir -p "$jsonl_dir"
    cat > "$jsonl_dir/test.jsonl" << 'JSONL'
{"type":"assistant","timestamp":"2026-04-01T10:01:00Z","message":{"role":"assistant","model":"claude-sonnet-4-20250514","usage":{"input_tokens":1500,"cache_read_input_tokens":0,"cache_creation_input_tokens":0,"output_tokens":0},"content":"small"}}
JSONL

    run _costs_parse_all "$jsonl_dir" "summary"
    [ "$status" -eq 0 ]
    [[ "$output" == *"1.5K"* ]]
}

@test "costs: date range is shown in summary" {
    local jsonl_dir="$TEST_TEMP_DIR/jsonl"
    _create_jsonl_fixture "$jsonl_dir"

    run _costs_parse_all "$jsonl_dir" "summary"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Date range:"* ]]
    [[ "$output" == *"2026-04-01"* ]]
}
