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

# guard_project_root — refuse to build fixture paths on an empty, "/", or
# out-of-temp-dir PROJECT_ROOT (T-2787/T-2788).
#
# Call this immediately after assigning PROJECT_ROOT in any bats setup() or
# helper, before the first mkdir/write against it. Checks against a known OS
# temp prefix rather than the literal $TEST_TEMP_DIR name, because several
# call sites mint their own local mktemp var (e.g. $TEST_TMP) instead of
# reusing the shared one — the invariant that matters is "inside some
# process-private temp dir", not "inside this specific variable".
guard_project_root() {
    local root="${1:-${PROJECT_ROOT:-}}"
    local tmp_prefix="${TMPDIR:-/tmp}"
    tmp_prefix="${tmp_prefix%/}"
    if [ -z "$root" ] || [ "$root" = "/" ]; then
        echo "GUARD: PROJECT_ROOT is empty or '/' (got '${root:-<empty>}') — refusing to build fixture paths on it. T-2788 guard tripped in ${BATS_TEST_NAME:-<unknown>}." >&2
        exit 1
    fi
    case "$root" in
        "$tmp_prefix"/*|/tmp/*|/var/folders/*|/private/tmp/*|/private/var/folders/*) : ;;
        *)
            echo "GUARD: PROJECT_ROOT='$root' is not inside a test temp directory (expected under '$tmp_prefix', /tmp, or /var/folders) — refusing to build fixture paths on it. T-2788 guard tripped in ${BATS_TEST_NAME:-<unknown>}." >&2
            exit 1
            ;;
    esac
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
