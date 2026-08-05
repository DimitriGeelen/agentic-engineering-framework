#!/bin/bash
# Common utilities for git agent

# Colors provided by lib/colors.sh (via paths.sh chain in git.sh)

# Task/YAML helpers provided by lib/tasks.sh and lib/yaml.sh (via paths.sh chain in git.sh)
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

# Resolve the git hooks directory for PROJECT_ROOT by asking git, not by
# string-concatenating "$PROJECT_ROOT/.git/hooks" (T-2812). The latter is
# only correct when .git is a directory sitting directly at PROJECT_ROOT —
# it is wrong for a project created inside an enclosing repo (no local
# .git at all), a worktree (.git is a file; hooks live in the common dir),
# and a submodule (hooks live under the superproject's .git/modules/<name>/).
# `git rev-parse --git-path hooks` resolves correctly for all three; its
# output is relative to PROJECT_ROOT when not already absolute.
resolve_git_hooks_dir() {
    local rel
    rel=$(git -C "$PROJECT_ROOT" rev-parse --git-path hooks 2>/dev/null) || return 1
    case "$rel" in
        /*) echo "$rel" ;;
        *) echo "$PROJECT_ROOT/$rel" ;;
    esac
}

# Extract task ID from message
extract_task_id() {
    local message="$1"
    echo "$message" | grep -oE "$TASK_PATTERN" | head -1
}

# Update task's last_update timestamp (only for active tasks)
update_task_timestamp() {
    local task_id="$1"
    local task_file
    task_file=$(find_task_file "$task_id" active)
    if [ -n "$task_file" ]; then
        local timestamp
        timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
        _sed_i "s/^last_update:.*$/last_update: $timestamp/" "$task_file"
    fi
}

# Ensure .context directory exists
ensure_context_dir() {
    mkdir -p "$CONTEXT_DIR"
}
