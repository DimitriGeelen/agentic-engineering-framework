#!/usr/bin/env bats
# Unit tests for agents/context/lib/focus.sh
#
# Tests the do_focus() function:
#   - No args: show current focus from focus.yaml
#   - With arg: set focus to a task (validates existence, updates focus.yaml + session.yaml)

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    export CONTEXT_DIR="$PROJECT_ROOT/.context"
    mkdir -p "$PROJECT_ROOT/.tasks/active" "$PROJECT_ROOT/.context/working"

    # Disable colors for test output matching
    RED='' GREEN='' YELLOW='' CYAN='' NC=''

    # Stub ensure_context_dirs
    ensure_context_dirs() { mkdir -p "$CONTEXT_DIR/working"; }
    export -f ensure_context_dirs

    # Source dependencies for find_task_file, get_task_name, _sed_i
    export TASKS_DIR="$PROJECT_ROOT/.tasks"
    source "$FRAMEWORK_ROOT/lib/compat.sh"
    source "$FRAMEWORK_ROOT/lib/tasks.sh"
    source "$FRAMEWORK_ROOT/agents/context/lib/focus.sh"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# --- Show focus (no args) ---

@test "show focus: no focus.yaml prints init message" {
    rm -f "$CONTEXT_DIR/working/focus.yaml"
    run do_focus
    [ "$status" -eq 0 ]
    [[ "$output" == *"not initialized"* ]]
}

@test "show focus: current_task is null prints no focus" {
    cat > "$CONTEXT_DIR/working/focus.yaml" <<'EOF'
current_task: null
priorities: []
blockers: []
EOF
    run do_focus
    [ "$status" -eq 0 ]
    [[ "$output" == *"No current focus set"* ]]
}

@test "show focus: current_task is empty prints no focus" {
    # Use trailing space after colon — YAML empty value that cut -d' ' parses as empty
    printf 'current_task: \npriorities: []\nblockers: []\n' > "$CONTEXT_DIR/working/focus.yaml"
    run do_focus
    [ "$status" -eq 0 ]
    [[ "$output" == *"No current focus set"* ]]
}

@test "show focus: current_task set shows task ID" {
    cat > "$CONTEXT_DIR/working/focus.yaml" <<'EOF'
current_task: T-042
priorities: []
blockers: []
EOF
    run do_focus
    [ "$status" -eq 0 ]
    [[ "$output" == *"Current focus: T-042"* ]]
}

@test "show focus: shows task name when task file exists" {
    cat > "$CONTEXT_DIR/working/focus.yaml" <<'EOF'
current_task: T-042
priorities: []
blockers: []
EOF
    cat > "$PROJECT_ROOT/.tasks/active/T-042-fix-login.md" <<'EOF'
---
id: T-042
name: Fix login bug
status: started-work
---
EOF
    run do_focus
    [ "$status" -eq 0 ]
    [[ "$output" == *"Current focus: T-042"* ]]
    [[ "$output" == *"Task: Fix login bug"* ]]
}

@test "show focus: no task name line when task file missing" {
    cat > "$CONTEXT_DIR/working/focus.yaml" <<'EOF'
current_task: T-042
priorities: []
blockers: []
EOF
    # No task file created
    run do_focus
    [ "$status" -eq 0 ]
    [[ "$output" == *"Current focus: T-042"* ]]
    # Should NOT contain "Task:" line since no file to read name from
    [[ "$output" != *"Task:"* ]]
}

# --- Set focus (with arg) ---

@test "set focus: fails for nonexistent task" {
    run do_focus T-999
    [ "$status" -eq 1 ]
    [[ "$output" == *"Task not found: T-999"* ]]
}

@test "set focus: creates focus.yaml when it does not exist" {
    rm -f "$CONTEXT_DIR/working/focus.yaml"
    create_test_task "$PROJECT_ROOT" "T-042" "fix-login"
    run do_focus T-042
    [ "$status" -eq 0 ]
    [ -f "$CONTEXT_DIR/working/focus.yaml" ]
    grep -q "^current_task: T-042" "$CONTEXT_DIR/working/focus.yaml"
    [[ "$output" == *"Focus set: T-042"* ]]
}

@test "set focus: updates existing focus.yaml" {
    cat > "$CONTEXT_DIR/working/focus.yaml" <<'EOF'
current_task: T-001
priorities: []
blockers: []
pending_decisions: []
reminders: []
EOF
    create_test_task "$PROJECT_ROOT" "T-042" "fix-login"
    run do_focus T-042
    [ "$status" -eq 0 ]
    grep -q "^current_task: T-042" "$CONTEXT_DIR/working/focus.yaml"
    # Old task should no longer be current
    ! grep -q "^current_task: T-001" "$CONTEXT_DIR/working/focus.yaml"
}

@test "set focus: shows task name in confirmation" {
    create_test_task "$PROJECT_ROOT" "T-042" "fix-login"
    run do_focus T-042
    [ "$status" -eq 0 ]
    [[ "$output" == *"Focus set: T-042"* ]]
    [[ "$output" == *"Task: "* ]]
}

@test "set focus: adds task to session.yaml tasks_touched" {
    create_test_task "$PROJECT_ROOT" "T-042" "fix-login"
    cat > "$CONTEXT_DIR/working/session.yaml" <<'EOF'
session_id: test-session
tasks_touched: []
EOF
    run do_focus T-042
    [ "$status" -eq 0 ]
    grep -q "tasks_touched:.*T-042" "$CONTEXT_DIR/working/session.yaml"
}

@test "set focus: does not duplicate task in tasks_touched" {
    create_test_task "$PROJECT_ROOT" "T-042" "fix-login"
    cat > "$CONTEXT_DIR/working/session.yaml" <<'EOF'
session_id: test-session
tasks_touched: [T-042]
EOF
    run do_focus T-042
    [ "$status" -eq 0 ]
    # Count occurrences of T-042 in the file — should still be just 1
    local count
    count=$(grep -o "T-042" "$CONTEXT_DIR/working/session.yaml" | wc -l)
    [ "$count" -eq 1 ]
}

@test "set focus: appends second task to tasks_touched" {
    create_test_task "$PROJECT_ROOT" "T-042" "fix-login"
    create_test_task "$PROJECT_ROOT" "T-050" "add-feature"
    cat > "$CONTEXT_DIR/working/session.yaml" <<'EOF'
session_id: test-session
tasks_touched: [T-042]
EOF
    run do_focus T-050
    [ "$status" -eq 0 ]
    grep -q "tasks_touched:.*T-042" "$CONTEXT_DIR/working/session.yaml"
    grep -q "tasks_touched:.*T-050" "$CONTEXT_DIR/working/session.yaml"
}

@test "set focus: created focus.yaml has expected structure" {
    rm -f "$CONTEXT_DIR/working/focus.yaml"
    create_test_task "$PROJECT_ROOT" "T-042" "fix-login"
    run do_focus T-042
    [ "$status" -eq 0 ]
    grep -q "^current_task: T-042" "$CONTEXT_DIR/working/focus.yaml"
    grep -q "^priorities:" "$CONTEXT_DIR/working/focus.yaml"
    grep -q "^blockers:" "$CONTEXT_DIR/working/focus.yaml"
    grep -q "^pending_decisions:" "$CONTEXT_DIR/working/focus.yaml"
    grep -q "^reminders:" "$CONTEXT_DIR/working/focus.yaml"
}

@test "set focus: works without session.yaml present" {
    create_test_task "$PROJECT_ROOT" "T-042" "fix-login"
    rm -f "$CONTEXT_DIR/working/session.yaml"
    run do_focus T-042
    [ "$status" -eq 0 ]
    [[ "$output" == *"Focus set: T-042"* ]]
    grep -q "^current_task: T-042" "$CONTEXT_DIR/working/focus.yaml"
}
