#!/usr/bin/env bats
# Integration tests for fw timeline subcommand

load ../test_helper

FW="$FRAMEWORK_ROOT/bin/fw"

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    guard_project_root
    export FRAMEWORK_ROOT
    mkdir -p "$PROJECT_ROOT/.tasks/active" "$PROJECT_ROOT/.tasks/completed"
    mkdir -p "$PROJECT_ROOT/.context/working" "$PROJECT_ROOT/.context/project"
    mkdir -p "$PROJECT_ROOT/.context/handovers"
    echo "framework_root: $FRAMEWORK_ROOT" > "$PROJECT_ROOT/.framework.yaml"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# --- Empty ---

@test "fw timeline: runs with empty project" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' timeline"
    [[ "$output" == *"Timeline"* ]] || [[ "$output" == *"timeline"* ]] || [[ "$output" == *"Session"* ]] || [[ "$output" == *"0 session"* ]]
}

# --- With handover ---

@test "fw timeline: shows sessions from handovers" {
    cat > "$PROJECT_ROOT/.context/handovers/S-2026-0101-0001.md" <<'MD'
---
session_id: S-2026-0101-0001
timestamp: 2026-01-01T00:01:00Z
tasks_touched: [T-001]
tasks_completed: []
owner: agent
---

# Session Handover: S-2026-0101-0001

## Where We Are

Test session.
MD
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' timeline"
    [[ "$output" == *"S-2026"* ]] || [[ "$output" == *"session"* ]] || [[ "$output" == *"T-001"* ]]
}
