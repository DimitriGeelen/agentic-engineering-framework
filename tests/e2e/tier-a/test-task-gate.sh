#!/usr/bin/env bash
# Tier A Tests: Task Gate Enforcement (A1, A2)
# Tests check-active-task.sh blocks/allows based on focus state.
#
# A1: Task gate blocks Write without active task (exit 2)
# A2: Task gate passes with active task (exit 0)
# A2b: Task gate allows exempt paths without task (exit 0)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../lib/setup.sh"
source "$SCRIPT_DIR/../lib/assert.sh"
source "$SCRIPT_DIR/../lib/teardown.sh"

SUITE_NAME="tier-a-task-gate"

setup_test_dir

# Copy framework libs (hook sources lib/paths.sh, lib/tasks.sh)
cp -r "$FRAMEWORK_ROOT/lib" "$TEST_DIR/" 2>/dev/null || true
mkdir -p "$TEST_DIR/agents/context"

HOOK_SCRIPT="$FRAMEWORK_ROOT/agents/context/check-active-task.sh"

# Helper: simulate hook input for a Write tool call
make_input() {
    local path="$1"
    printf '{"tool_name":"Write","tool_input":{"file_path":"%s"}}' "$path"
}

# ── A1: Task gate blocks Write without active task ──

# Ensure no focus is set (field is 'current_task', not 'task_id')
mkdir -p "$TEST_DIR/.context/working"
cat > "$TEST_DIR/.context/working/focus.yaml" << 'EOF'
---
current_task: ""
EOF

# Run hook with PROJECT_ROOT pointing to test dir
assert_exit_code \
    "echo '$(make_input "$TEST_DIR/src/main.py")' | PROJECT_ROOT='$TEST_DIR' bash '$HOOK_SCRIPT'" \
    2 "A1" "Task gate blocks Write without active task"

# ── A2: Task gate passes with active task ──

# Create a task and set focus
mkdir -p "$TEST_DIR/.tasks/active"
cat > "$TEST_DIR/.tasks/active/T-999-test-task.md" << 'TASK'
---
id: T-999
name: "Test task"
status: started-work
workflow_type: build
owner: agent
---
# T-999: Test task

## Acceptance Criteria

### Agent
- [ ] Test passes successfully

## Verification

true
TASK

cat > "$TEST_DIR/.context/working/focus.yaml" << 'FOCUS'
---
current_task: "T-999"
task_name: "Test task"
set_at: "2026-01-01T00:00:00Z"
FOCUS

assert_exit_code \
    "echo '$(make_input "$TEST_DIR/src/main.py")' | PROJECT_ROOT='$TEST_DIR' bash '$HOOK_SCRIPT'" \
    0 "A2" "Task gate passes with active task"

# ── A2b: Task gate allows exempt paths without task ──

# Clear focus again
cat > "$TEST_DIR/.context/working/focus.yaml" << 'EOF'
---
current_task: ""
EOF

assert_exit_code \
    "echo '$(make_input "$TEST_DIR/.context/working/session.yaml")' | PROJECT_ROOT='$TEST_DIR' bash '$HOOK_SCRIPT'" \
    0 "A2b" "Task gate allows exempt .context/ path"

assert_exit_code \
    "echo '$(make_input "$TEST_DIR/.tasks/active/T-999.md")' | PROJECT_ROOT='$TEST_DIR' bash '$HOOK_SCRIPT'" \
    0 "A2c" "Task gate allows exempt .tasks/ path"

# ── Report ──

if [ "${JSON_OUTPUT:-false}" = true ]; then
    print_json_summary
else
    print_summary
fi
