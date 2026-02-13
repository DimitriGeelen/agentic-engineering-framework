#!/bin/bash
# Git Agent - Commit subcommand
# Validates task references before committing

do_commit() {
    local message=""
    local task_id=""
    local bypass=false
    local bypass_reason=""
    local git_args=()

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -m)
                message="$2"
                shift 2
                ;;
            -t|--task)
                task_id="$2"
                shift 2
                ;;
            --bypass)
                bypass=true
                shift
                ;;
            --reason)
                bypass_reason="$2"
                shift 2
                ;;
            -h|--help)
                show_commit_help
                exit 0
                ;;
            *)
                # Pass through to git
                git_args+=("$1")
                shift
                ;;
        esac
    done

    check_git_repo

    # If task ID provided separately, prepend to message
    if [ -n "$task_id" ] && [ -n "$message" ]; then
        message="$task_id: $message"
    fi

    # Check if we have a message
    if [ -z "$message" ]; then
        echo -e "${RED}ERROR: Commit message required${NC}"
        echo "Use: git.sh commit -m \"T-XXX: your message\""
        exit 1
    fi

    # Handle bypass mode
    if [ "$bypass" = true ]; then
        if [ -z "$bypass_reason" ]; then
            echo -e "${YELLOW}WARNING: You are bypassing task enforcement.${NC}"
            echo ""
            read -p "Reason for bypass (required): " bypass_reason
            if [ -z "$bypass_reason" ]; then
                echo -e "${RED}ERROR: Bypass requires a reason${NC}"
                exit 1
            fi
        fi

        # Do the commit
        if git -C "$PROJECT_ROOT" commit -m "$message" "${git_args[@]}"; then
            local commit_sha
            commit_sha=$(git -C "$PROJECT_ROOT" rev-parse --short HEAD)

            # Log the bypass
            source "$LIB_DIR/bypass.sh"
            log_bypass_entry "$commit_sha" "$message" "$bypass_reason"

            echo ""
            echo -e "${YELLOW}REMINDER: Create a retroactive task for this work.${NC}"
            echo "Run: ./agents/task-create/create-task.sh --name \"Retroactive: $message\""
        else
            exit 1
        fi
        return
    fi

    # Extract task reference from message
    local found_task
    found_task=$(extract_task_id "$message")

    if [ -z "$found_task" ]; then
        echo ""
        echo -e "${RED}ERROR: No task reference found in commit message${NC}"
        echo ""
        echo "Your message: $message"
        echo ""
        echo "To fix:"
        echo "  1. Add task reference: git.sh commit -m \"T-XXX: $message\""
        echo "  2. Create a task: ./agents/task-create/create-task.sh"
        echo "  3. Emergency bypass: git.sh commit --bypass -m \"$message\""
        echo ""
        exit 1
    fi

    # Optionally validate task exists (warn only, don't block)
    if ! task_exists "$found_task"; then
        echo -e "${YELLOW}WARNING: Task $found_task not found in .tasks/${NC}"
        echo "Consider creating it: ./agents/task-create/create-task.sh"
        echo ""
    fi

    # Do the commit
    if git -C "$PROJECT_ROOT" commit -m "$message" "${git_args[@]}"; then
        # Update task timestamp
        update_task_timestamp "$found_task"

        local task_name
        task_name=$(get_task_name "$found_task")
        if [ -n "$task_name" ]; then
            echo ""
            echo -e "${GREEN}Task $found_task updated${NC} ($task_name)"
        fi
    else
        exit 1
    fi
}

show_commit_help() {
    cat << EOF
Git Agent - Commit Command

Usage: git.sh commit [options]

Options:
  -m MESSAGE      Commit message (must include T-XXX)
  -t, --task ID   Explicitly specify task (prepends to message)
  --bypass        Emergency bypass (prompts for reason, logs to bypass-log)
  --reason TEXT   Bypass reason (use with --bypass)
  -h, --help      Show this help

Examples:
  git.sh commit -m "T-003: Add bypass log"
  git.sh commit -t T-003 -m "Add bypass log"
  git.sh commit --bypass --reason "Production P1" -m "Emergency fix"

Note: Commits without task references are blocked unless --bypass is used.
      All bypasses are logged in .context/bypass-log.yaml
EOF
}
