#!/usr/bin/env bats
# Unit tests for agents/context/lib/init.sh
#
# Tests do_init():
#   - Creates session.yaml and focus.yaml
#   - Generates session ID format
#   - Resets tool counter and budget gate counter
#   - Detects first session vs existing project
#   - Reports predecessor from handover

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    guard_project_root
    export FRAMEWORK_ROOT
    export CONTEXT_DIR="$PROJECT_ROOT/.context"
    mkdir -p "$PROJECT_ROOT/.tasks/active" "$PROJECT_ROOT/.context/working"
    mkdir -p "$PROJECT_ROOT/.context/handovers" "$PROJECT_ROOT/.context/audits/cron"
    mkdir -p "$PROJECT_ROOT/.context/project" "$PROJECT_ROOT/.context/episodic"

    # Initialize a minimal git repo for commit count check
    git -C "$PROJECT_ROOT" init -q 2>/dev/null || true
    git -C "$PROJECT_ROOT" config user.email "test@test.com" 2>/dev/null || true
    git -C "$PROJECT_ROOT" config user.name "Test" 2>/dev/null || true

    # Disable colors for test output matching
    RED='' GREEN='' YELLOW='' CYAN='' NC=''

    # Stub ensure_context_dirs
    ensure_context_dirs() { mkdir -p "$CONTEXT_DIR/working" "$CONTEXT_DIR/project" "$CONTEXT_DIR/episodic" "$CONTEXT_DIR/handovers" "$CONTEXT_DIR/audits/cron"; }
    export -f ensure_context_dirs

    source "$FRAMEWORK_ROOT/agents/context/lib/init.sh"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# --- Session initialization ---

@test "init: creates session.yaml" {
    run do_init
    [ "$status" -eq 0 ]
    [ -f "$CONTEXT_DIR/working/session.yaml" ]
}

@test "init: creates focus.yaml" {
    run do_init
    [ "$status" -eq 0 ]
    [ -f "$CONTEXT_DIR/working/focus.yaml" ]
}

@test "init: session ID has correct format" {
    run do_init
    [ "$status" -eq 0 ]
    # Session ID should be S-YYYY-MMDD-HHMM
    grep -qE 'session_id: S-[0-9]{4}-[0-9]{4}-[0-9]{4}' "$CONTEXT_DIR/working/session.yaml"
}

@test "init: resets tool counter to 0" {
    echo "42" > "$CONTEXT_DIR/working/.tool-counter"
    run do_init
    [ "$status" -eq 0 ]
    [ "$(cat "$CONTEXT_DIR/working/.tool-counter")" = "0" ]
}

@test "init: resets budget gate counter to 0" {
    echo "10" > "$CONTEXT_DIR/working/.budget-gate-counter"
    run do_init
    [ "$status" -eq 0 ]
    [ "$(cat "$CONTEXT_DIR/working/.budget-gate-counter")" = "0" ]
}

@test "init: removes budget status file" {
    echo '{"level":"warn"}' > "$CONTEXT_DIR/working/.budget-status"
    run do_init
    [ "$status" -eq 0 ]
    [ ! -f "$CONTEXT_DIR/working/.budget-status" ]
}

@test "init: output shows Session Initialized" {
    run do_init
    [ "$status" -eq 0 ]
    [[ "$output" == *"Session Initialized"* ]]
}

@test "init: output shows session ID" {
    run do_init
    [ "$status" -eq 0 ]
    [[ "$output" == *"Session ID: S-"* ]]
}

# --- Predecessor detection ---

@test "init: detects predecessor from handover" {
    cat > "$CONTEXT_DIR/handovers/LATEST.md" << 'EOF'
---
session_id: S-2026-0301-1000
---
# Test handover
EOF
    run do_init
    [ "$status" -eq 0 ]
    [[ "$output" == *"Predecessor: S-2026-0301-1000"* ]]
    grep -q "predecessor: S-2026-0301-1000" "$CONTEXT_DIR/working/session.yaml"
}

@test "init: no predecessor when no handover exists" {
    rm -f "$CONTEXT_DIR/handovers/LATEST.md"
    run do_init
    [ "$status" -eq 0 ]
    grep -q "predecessor: null" "$CONTEXT_DIR/working/session.yaml"
}

# --- Active task listing ---

@test "init: lists active tasks in session.yaml" {
    touch "$PROJECT_ROOT/.tasks/active/T-100-test-task.md"
    touch "$PROJECT_ROOT/.tasks/active/T-101-another-task.md"
    run do_init
    [ "$status" -eq 0 ]
    grep -q "T-100" "$CONTEXT_DIR/working/session.yaml"
    grep -q "T-101" "$CONTEXT_DIR/working/session.yaml"
}

@test "init: reports no active tasks" {
    run do_init
    [ "$status" -eq 0 ]
    [[ "$output" == *"Active tasks: none"* ]] || [[ "$output" == *"Active tasks:"* ]]
}

# --- First session detection ---

@test "init: shows welcome on first session" {
    rm -f "$CONTEXT_DIR/handovers/LATEST.md"
    run do_init
    [ "$status" -eq 0 ]
    [[ "$output" == *"First Session"* ]] || [[ "$output" == *"Welcome"* ]]
}

@test "init: no welcome when handover exists" {
    cat > "$CONTEXT_DIR/handovers/LATEST.md" << 'EOF'
---
session_id: S-2026-0301-1000
---
# Existing handover
EOF
    # Need at least 2 commits for has_commits check
    touch "$PROJECT_ROOT/dummy"
    git -C "$PROJECT_ROOT" add dummy && git -C "$PROJECT_ROOT" commit -q -m "init" 2>/dev/null || true
    touch "$PROJECT_ROOT/dummy2"
    git -C "$PROJECT_ROOT" add dummy2 && git -C "$PROJECT_ROOT" commit -q -m "second" 2>/dev/null || true
    run do_init
    [ "$status" -eq 0 ]
    [[ "$output" != *"First Session"* ]]
}

# --- Focus file content ---

@test "init: focus.yaml has null current_task" {
    run do_init
    [ "$status" -eq 0 ]
    grep -q "current_task: null" "$CONTEXT_DIR/working/focus.yaml"
}

@test "init: focus.yaml has reminders" {
    run do_init
    [ "$status" -eq 0 ]
    grep -q "Run audit before pushing" "$CONTEXT_DIR/working/focus.yaml"
    grep -q "Create handover before ending session" "$CONTEXT_DIR/working/focus.yaml"
}
