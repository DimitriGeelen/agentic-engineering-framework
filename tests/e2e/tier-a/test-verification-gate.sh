#!/usr/bin/env bash
# Tier A Tests: Verification Gate (A10)
# Tests that task completion is blocked when verification commands fail.
#
# A10a: Verification gate blocks on failing command
# A10b: Verification gate passes on succeeding command

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../lib/setup.sh"
source "$SCRIPT_DIR/../lib/assert.sh"
source "$SCRIPT_DIR/../lib/teardown.sh"

SUITE_NAME="tier-a-verification-gate"

setup_test_dir

# We need a minimal framework structure for update-task.sh
mkdir -p "$TEST_DIR/.tasks/active" "$TEST_DIR/.tasks/completed"
mkdir -p "$TEST_DIR/.context/working" "$TEST_DIR/.context/episodic"

# Initialize git (update-task.sh may use git)
cd "$TEST_DIR"
git init -q
git add -A 2>/dev/null; git commit -q -m "init" --allow-empty 2>/dev/null || true
cd "$FRAMEWORK_ROOT"

UPDATE_SCRIPT="$FRAMEWORK_ROOT/agents/task-create/update-task.sh"

# ── A10a: Verification gate blocks on failing command ──

# Create task with a verification command that fails
cat > "$TEST_DIR/.tasks/active/T-998-test-verify-fail.md" << 'TASK'
---
id: T-998
name: "Test verify fail"
status: started-work
workflow_type: build
owner: agent
created: 2026-01-01T00:00:00Z
last_update: 2026-01-01T00:00:00Z
---
# T-998: Test verify fail

## Acceptance Criteria

### Agent
- [x] Test criterion

## Verification

false

## Decisions
TASK

assert_exit_code \
    "PROJECT_ROOT='$TEST_DIR' bash '$UPDATE_SCRIPT' T-998 --status work-completed 2>&1" \
    1 "A10a" "Verification gate blocks on failing command"

# Verify task is still in active (not moved to completed)
assert_file_exists "$TEST_DIR/.tasks/active/T-998-test-verify-fail.md" "A10a2" \
    "Task stays in active/ after verification failure"

# ── A10b: Verification gate passes on succeeding command ──

cat > "$TEST_DIR/.tasks/active/T-997-test-verify-pass.md" << 'TASK'
---
id: T-997
name: "Test verify pass"
status: started-work
workflow_type: build
owner: agent
created: 2026-01-01T00:00:00Z
last_update: 2026-01-01T00:00:00Z
---
# T-997: Test verify pass

## Acceptance Criteria

### Agent
- [x] Test criterion

## Verification

true

## Decisions
TASK

assert_exit_code \
    "PROJECT_ROOT='$TEST_DIR' bash '$UPDATE_SCRIPT' T-997 --status work-completed 2>&1" \
    0 "A10b" "Verification gate passes on succeeding command"

# ── Report ──

if [ "${JSON_OUTPUT:-false}" = true ]; then
    print_json_summary
else
    print_summary
fi
