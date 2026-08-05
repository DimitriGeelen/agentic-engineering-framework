#!/usr/bin/env bats
# Unit tests for agents/context/lib/status.sh
#
# Tests the do_status() function:
#   - Displays working memory, project memory, episodic memory sections
#   - Handles missing session.yaml gracefully
#   - Reports counts for patterns, decisions, learnings

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    guard_project_root
    export FRAMEWORK_ROOT
    export CONTEXT_DIR="$PROJECT_ROOT/.context"
    mkdir -p "$PROJECT_ROOT/.tasks/active" "$PROJECT_ROOT/.context/working" "$PROJECT_ROOT/.context/project"
    mkdir -p "$PROJECT_ROOT/.context/episodic" "$PROJECT_ROOT/.context/handovers" "$PROJECT_ROOT/.context/audits"

    # Disable colors for test output matching
    RED='' GREEN='' YELLOW='' CYAN='' NC=''

    # Stub ensure_context_dirs
    ensure_context_dirs() { mkdir -p "$CONTEXT_DIR/working" "$CONTEXT_DIR/project" "$CONTEXT_DIR/episodic" "$CONTEXT_DIR/handovers" "$CONTEXT_DIR/audits"; }
    export -f ensure_context_dirs

    # Source dependencies
    export TASKS_DIR="$PROJECT_ROOT/.tasks"
    source "$FRAMEWORK_ROOT/lib/compat.sh"
    source "$FRAMEWORK_ROOT/agents/context/lib/status.sh"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# --- Section headers ---

@test "status: shows context fabric header" {
    run do_status
    [ "$status" -eq 0 ]
    [[ "$output" == *"CONTEXT FABRIC STATUS"* ]]
}

@test "status: shows working memory section" {
    run do_status
    [ "$status" -eq 0 ]
    [[ "$output" == *"WORKING MEMORY"* ]]
}

@test "status: shows project memory section" {
    run do_status
    [ "$status" -eq 0 ]
    [[ "$output" == *"PROJECT MEMORY"* ]]
}

@test "status: shows episodic memory section" {
    run do_status
    [ "$status" -eq 0 ]
    [[ "$output" == *"EPISODIC MEMORY"* ]]
}

# --- No session ---

@test "status: no session.yaml shows init message" {
    rm -f "$CONTEXT_DIR/working/session.yaml"
    run do_status
    [ "$status" -eq 0 ]
    [[ "$output" == *"No active session"* ]]
}

# --- With session ---

@test "status: shows session ID when session exists" {
    cat > "$CONTEXT_DIR/working/session.yaml" <<'EOF'
session_id: S-2026-0101-0001
status: active
tasks_touched: [T-001, T-002]
EOF
    run do_status
    [ "$status" -eq 0 ]
    [[ "$output" == *"S-2026-0101-0001"* ]]
}

# --- Counts ---

@test "status: reports zero counts on empty project" {
    run do_status
    [ "$status" -eq 0 ]
    [[ "$output" == *"Patterns: 0 failure"* ]]
    [[ "$output" == *"Decisions: 0"* ]]
    [[ "$output" == *"Learnings: 0"* ]]
}
