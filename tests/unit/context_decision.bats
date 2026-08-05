#!/usr/bin/env bats
# Unit tests for agents/context/lib/decision.sh
#
# Tests the do_add_decision() function:
#   - Argument parsing (decision text, --task, --rationale, --rejected)
#   - Error handling (missing text)
#   - ID generation (D-XXX or PD-XXX)
#   - File creation and appending
#   - Output formatting

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    guard_project_root
    export FRAMEWORK_ROOT
    export CONTEXT_DIR="$PROJECT_ROOT/.context"
    mkdir -p "$PROJECT_ROOT/.tasks/active" "$PROJECT_ROOT/.context/working" "$PROJECT_ROOT/.context/project"

    # Disable colors for test output matching
    RED='' GREEN='' YELLOW='' CYAN='' NC=''

    # Stub ensure_context_dirs
    ensure_context_dirs() { mkdir -p "$CONTEXT_DIR/working" "$CONTEXT_DIR/project"; }
    export -f ensure_context_dirs

    # Source dependencies
    export TASKS_DIR="$PROJECT_ROOT/.tasks"
    source "$FRAMEWORK_ROOT/lib/compat.sh"
    source "$FRAMEWORK_ROOT/agents/context/lib/decision.sh"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# --- Error handling ---

@test "add decision: no text shows error" {
    run do_add_decision
    [ "$status" -eq 1 ]
    [[ "$output" == *"Decision text required"* ]]
}

@test "add decision: unknown option shows error" {
    run do_add_decision --badopt value
    [ "$status" -eq 1 ]
    [[ "$output" == *"Unknown option"* ]]
}

# --- File creation ---

@test "add decision: creates decisions.yaml when missing" {
    rm -f "$CONTEXT_DIR/project/decisions.yaml"
    run do_add_decision "Use YAML for config"
    [ "$status" -eq 0 ]
    [ -f "$CONTEXT_DIR/project/decisions.yaml" ]
}

@test "add decision: creates first entry with D-001 ID in framework project" {
    # T-1258: DO NOT set PROJECT_ROOT=FRAMEWORK_ROOT — it destroys the real
    # decisions.yaml (same bug class that destroys learnings.yaml; see T-1258 RCA).
    # Instead, simulate "framework mode" by aliasing FRAMEWORK_ROOT to TEST_TEMP_DIR
    # so the id_prefix=D branch in do_add_decision is taken without touching the real framework.
    local save_framework_root="$FRAMEWORK_ROOT"
    export FRAMEWORK_ROOT="$TEST_TEMP_DIR"
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    export CONTEXT_DIR="$PROJECT_ROOT/.context"
    mkdir -p "$CONTEXT_DIR/project"
    rm -f "$CONTEXT_DIR/project/decisions.yaml"
    run do_add_decision "Use YAML for config"
    [ "$status" -eq 0 ]
    [[ "$output" == *"D-001"* ]]
    # Restore
    export FRAMEWORK_ROOT="$save_framework_root"
}

# --- ID sequencing ---

@test "add decision: second entry increments ID" {
    rm -f "$CONTEXT_DIR/project/decisions.yaml"
    do_add_decision "First decision"
    run do_add_decision "Second decision"
    [ "$status" -eq 0 ]
    [[ "$output" == *"PD-002"* ]]
    grep -q "id: PD-002" "$CONTEXT_DIR/project/decisions.yaml"
}

# --- Consumer project prefix ---

@test "add decision: uses PD- prefix in consumer project" {
    rm -f "$CONTEXT_DIR/project/decisions.yaml"
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    export FRAMEWORK_ROOT="/some/other/path"
    run do_add_decision "Consumer decision"
    [ "$status" -eq 0 ]
    [[ "$output" == *"PD-001"* ]]
    export FRAMEWORK_ROOT
}

# --- Optional arguments ---

@test "add decision: includes task reference" {
    rm -f "$CONTEXT_DIR/project/decisions.yaml"
    run do_add_decision "Use REST API" --task T-456
    [ "$status" -eq 0 ]
    [[ "$output" == *"Task: T-456"* ]]
    grep -q "task: T-456" "$CONTEXT_DIR/project/decisions.yaml"
}

@test "add decision: includes rationale" {
    rm -f "$CONTEXT_DIR/project/decisions.yaml"
    run do_add_decision "Use YAML" --rationale "Human readable"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Rationale: Human readable"* ]]
    grep -q "Human readable" "$CONTEXT_DIR/project/decisions.yaml"
}

@test "add decision: includes rejected alternatives" {
    rm -f "$CONTEXT_DIR/project/decisions.yaml"
    run do_add_decision "Use YAML" --rejected "JSON,TOML"
    [ "$status" -eq 0 ]
    grep -q "alternatives_rejected" "$CONTEXT_DIR/project/decisions.yaml"
}

@test "add decision: stores decision text in file" {
    rm -f "$CONTEXT_DIR/project/decisions.yaml"
    run do_add_decision "Adopt event sourcing pattern"
    [ "$status" -eq 0 ]
    grep -q "Adopt event sourcing pattern" "$CONTEXT_DIR/project/decisions.yaml"
}

# --- Output formatting ---

@test "add decision: shows confirmation" {
    rm -f "$CONTEXT_DIR/project/decisions.yaml"
    run do_add_decision "My test decision"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Decision recorded"* ]]
    [[ "$output" == *"My test decision"* ]]
}
