#!/bin/bash
# Git Agent - Status subcommand
# Task-aware git status

do_status() {
    check_git_repo

    echo -e "${CYAN}=== Git Status (Task-Aware) ===${NC}"
    echo ""

    # Find active task context (most recently modified)
    local active_task=""
    local active_task_name=""
    shopt -s nullglob
    local latest_task=""
    local latest_time=0
    for f in "$TASKS_DIR/active"/*.md; do
        local mtime
        mtime=$(stat -c %Y "$f" 2>/dev/null || stat -f %m "$f" 2>/dev/null)
        if [ -n "$mtime" ] && [ "$mtime" -gt "$latest_time" ]; then
            latest_time=$mtime
            latest_task="$f"
        fi
    done
    shopt -u nullglob

    if [ -n "$latest_task" ]; then
        active_task=$(grep "^id:" "$latest_task" | head -1 | cut -d: -f2 | tr -d ' ')
        active_task_name=$(grep "^name:" "$latest_task" | head -1 | cut -d: -f2- | sed 's/^ *//')
        echo -e "Active task context: ${GREEN}$active_task${NC} ($active_task_name)"
        echo ""
    fi

    # Show git status
    git -C "$PROJECT_ROOT" status

    # Add helpful tip
    if [ -n "$active_task" ]; then
        echo ""
        echo -e "${CYAN}Tip:${NC} Commit with: git.sh commit -m \"$active_task: <description>\""
    else
        echo ""
        echo -e "${CYAN}Tip:${NC} Create a task first: ./agents/task-create/create-task.sh"
    fi
}
