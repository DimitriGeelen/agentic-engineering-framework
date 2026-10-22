#!/bin/bash
# lib/tasks.sh — Shared task file lookup helpers
#
# Provides find_task_file() and task_exists() to replace the
# find ... -name "${task_id}-*.md" pattern duplicated across 7+ files.
#
# Usage: source "$FRAMEWORK_ROOT/lib/tasks.sh"
#
# Requires: TASKS_DIR (set by lib/paths.sh)

# Guard against double-sourcing
[[ -n "${_FW_TASKS_LOADED:-}" ]] && return 0
_FW_TASKS_LOADED=1

# Find a task file by ID, searching active/ then completed/
# Usage: find_task_file T-042 [active|completed]
# Returns: absolute path on stdout, or empty string if not found
find_task_file() {
    local task_id="$1"
    local scope="${2:-}"  # "active", "completed", or empty for both
    local result

    local tasks_dir="${TASKS_DIR:-$PROJECT_ROOT/.tasks}"

    if [[ -n "$scope" ]]; then
        result=$(find "$tasks_dir/$scope" -name "${task_id}-*.md" -type f 2>/dev/null | head -1)
    else
        result=$(find "$tasks_dir/active" -name "${task_id}-*.md" -type f 2>/dev/null | head -1)
        [[ -z "$result" ]] && \
            result=$(find "$tasks_dir/completed" -name "${task_id}-*.md" -type f 2>/dev/null | head -1)
    fi
    # Not found is an empty stdout and a ZERO status (T-4594). Ending on a bare
    # `[[ -n ]] && echo` returned 1 here, and a caller doing `x=$(find_task_file …)`
    # under `set -e` died on that line before printing its own "not found" message.
    [[ -n "$result" ]] && echo "$result"
    return 0
}

# Check if a task exists (in active/ or completed/)
# Usage: task_exists T-042
task_exists() {
    [[ -n "$(find_task_file "$1")" ]]
}

# Get task name from a task file
# Usage: get_task_name_from_file /path/to/T-042-slug.md
get_task_name() {
    local task_file
    if [[ -f "$1" ]]; then
        task_file="$1"
    else
        task_file="$(find_task_file "$1")"
    fi
    [[ -n "$task_file" ]] && grep "^name:" "$task_file" 2>/dev/null | head -1 | sed 's/^name:[[:space:]]*//' | sed 's/^"//;s/"$//'
}
