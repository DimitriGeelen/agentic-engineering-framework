#!/bin/bash
# Git Agent - Bypass logging subcommand

do_log_bypass() {
    local commit=""
    local reason=""
    local action=""
    local authorized_by="human"
    local retroactive_task=""

    while [[ $# -gt 0 ]]; do
        case $1 in
            --commit|-c)
                commit="$2"
                shift 2
                ;;
            --reason|-r)
                reason="$2"
                shift 2
                ;;
            --action|-a)
                action="$2"
                shift 2
                ;;
            --authorized-by)
                authorized_by="$2"
                shift 2
                ;;
            --retroactive-task)
                retroactive_task="$2"
                shift 2
                ;;
            -h|--help)
                show_bypass_help
                exit 0
                ;;
            *)
                echo -e "${RED}Unknown option: $1${NC}"
                exit 1
                ;;
        esac
    done

    # Prompt for missing required fields
    if [ -z "$commit" ]; then
        read -p "Commit SHA (short): " commit
    fi

    if [ -z "$commit" ]; then
        echo -e "${RED}ERROR: Commit SHA required${NC}"
        exit 1
    fi

    # Get action from commit message if not provided
    if [ -z "$action" ]; then
        action=$(git -C "$PROJECT_ROOT" log -1 --format=%s "$commit" 2>/dev/null)
        if [ -z "$action" ]; then
            read -p "Action description: " action
        fi
    fi

    if [ -z "$reason" ]; then
        echo "Reason for bypass (required):"
        read -p "> " reason
    fi

    if [ -z "$reason" ]; then
        echo -e "${RED}ERROR: Bypass reason required${NC}"
        exit 1
    fi

    log_bypass_entry "$commit" "$action" "$reason" "$authorized_by" "$retroactive_task"
}

# Internal function to log a bypass entry
log_bypass_entry() {
    local commit="$1"
    local action="$2"
    local reason="$3"
    local authorized_by="${4:-human}"
    local retroactive_task="${5:-null}"

    ensure_context_dir

    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # Create bypass log if it doesn't exist
    if [ ! -f "$BYPASS_LOG" ]; then
        cat > "$BYPASS_LOG" << EOF
# Bypass Log - Agentic Engineering Framework
# Records all commits made without task references
# Reviewed by: audit agent

bypasses:
EOF
    fi

    # Append the entry
    cat >> "$BYPASS_LOG" << EOF
  - timestamp: $timestamp
    action: "$action"
    commit: $commit
    authorized_by: $authorized_by
    reason: "$reason"
    retroactive_task: $retroactive_task
EOF

    echo -e "${GREEN}Bypass logged${NC}"
    echo "  File: $BYPASS_LOG"
    echo "  Commit: $commit"
    echo "  Reason: $reason"
}

show_bypass_help() {
    cat << EOF
Git Agent - Log Bypass Command

Usage: git.sh log-bypass [options]

Options:
  -c, --commit SHA       Commit SHA to log (prompts if not provided)
  -r, --reason TEXT      Reason for bypass (prompts if not provided)
  -a, --action TEXT      Action description (defaults to commit message)
  --authorized-by WHO    Who authorized (default: human)
  --retroactive-task ID  Task created after the fact (default: null)
  -h, --help             Show this help

Examples:
  git.sh log-bypass --commit acb4594 --reason "Bootstrap exception"
  git.sh log-bypass  # Interactive mode

The bypass log is stored in .context/bypass-log.yaml and reviewed by audit.
EOF
}
