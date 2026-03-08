#!/bin/bash
# Common utilities for git agent

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Paths
TASKS_DIR="$PROJECT_ROOT/.tasks"
CONTEXT_DIR="$PROJECT_ROOT/.context"
BYPASS_LOG="$CONTEXT_DIR/bypass-log.yaml"

# Task reference pattern
TASK_PATTERN='T-[0-9]+'

# Check if we're in a git repo
check_git_repo() {
    if ! git -C "$PROJECT_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
        echo -e "${RED}ERROR: Not a git repository${NC}"
        echo "Run 'git init' first"
        exit 1
    fi
}

# Extract task ID from message
extract_task_id() {
    local message="$1"
    echo "$message" | grep -oE "$TASK_PATTERN" | head -1
}

# Check if task exists
task_exists() {
    local task_id="$1"
    local task_file
    task_file=$(find "$TASKS_DIR" -name "${task_id}-*.md" -type f 2>/dev/null | head -1)
    [ -n "$task_file" ]
}

# Get task name from ID
get_task_name() {
    local task_id="$1"
    local task_file
    task_file=$(find "$TASKS_DIR" -name "${task_id}-*.md" -type f 2>/dev/null | head -1)
    if [ -n "$task_file" ]; then
        grep "^name:" "$task_file" | head -1 | cut -d: -f2- | sed 's/^ *//'
    fi
}

# Update task's last_update timestamp (only for active tasks)
update_task_timestamp() {
    local task_id="$1"
    local task_file
    # Only update active tasks, not completed ones
    task_file=$(find "$TASKS_DIR/active" -name "${task_id}-*.md" -type f 2>/dev/null | head -1)
    if [ -n "$task_file" ]; then
        local timestamp
        timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
        # Update last_update in frontmatter
        _sed_i "s/^last_update:.*$/last_update: $timestamp/" "$task_file"
    fi
}

# Ensure .context directory exists
ensure_context_dir() {
    mkdir -p "$CONTEXT_DIR"
}
