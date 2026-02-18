# tests/test_helper.bash — shared setup for all bats tests
#
# Source this at the top of every .bats file:
#   load test_helper

# Framework root — walk up from test file until we find agents/
_find_framework_root() {
    local dir="$BATS_TEST_DIRNAME"
    while [ "$dir" != "/" ]; do
        [ -d "$dir/agents" ] && [ -f "$dir/FRAMEWORK.md" ] && { echo "$dir"; return; }
        dir="$(dirname "$dir")"
    done
    echo "$BATS_TEST_DIRNAME"  # fallback
}
export FRAMEWORK_ROOT="$(_find_framework_root)"

# Ensure fw is on PATH
export PATH="$FRAMEWORK_ROOT/bin:$PATH"

# Create a temporary directory for each test (auto-cleaned)
setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# Helper: create a minimal project directory for testing
create_test_project() {
    local dir="${1:-$TEST_TEMP_DIR/project}"
    mkdir -p "$dir/.tasks/active" "$dir/.tasks/completed" "$dir/.context/working"
    echo "framework_root: $FRAMEWORK_ROOT" > "$dir/.framework.yaml"
    echo "$dir"
}

# Helper: create a minimal task file
create_test_task() {
    local project_dir="$1"
    local task_id="${2:-T-999}"
    local slug="${3:-test-task}"
    local file="$project_dir/.tasks/active/${task_id}-${slug}.md"
    cat > "$file" <<EOF
---
id: ${task_id}
name: "Test task"
description: "A test task"
status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
related_tasks: []
created: 2026-01-01T00:00:00Z
last_update: 2026-01-01T00:00:00Z
date_finished: null
---

# ${task_id}: Test task

## Context

Test context.

## Acceptance Criteria

- [ ] Test criterion

## Verification

echo "ok"
EOF
    echo "$file"
}
