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

# T-4373: emit a string as a YAML single-quoted scalar that is valid for any
# input. Inside single quotes only ' is special (doubled); CR/LF collapse to a
# space so the entry stays on one line; other C0 control chars (not allowed in
# YAML scalars) are dropped. Backslashes, double quotes and colons pass verbatim.
_bypass_yaml_sq() {
    local s="$1"
    s="${s//$'\r\n'/ }"
    s="${s//$'\r'/ }"
    s="${s//$'\n'/ }"
    s=$(printf '%s' "$s" | tr -d '\000-\010\013\014\016-\037\177')
    s="${s//\'/\'\'}"
    printf "'%s'" "$s"
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

    # F-21: the file can also exist ALREADY with the pre-fix flow-style
    # `bypasses: []` header (written by an older `fw init`, or by a project
    # created before this fix). Appending block-sequence items under a flow
    # scalar is invalid YAML — normalize the header to the bare-key form this
    # function assumes before appending, so already-affected projects heal on
    # their next logged bypass instead of corrupting further.
    if grep -qx 'bypasses: \[\]' "$BYPASS_LOG" 2>/dev/null; then
        sed -i 's/^bypasses: \[\]$/bypasses:/' "$BYPASS_LOG"
    fi

    # T-4349: match the indent the existing sequence uses. A PyYAML re-dump
    # emits `- timestamp:` at column 0 (indentless); a 2-space item appended
    # after that is a parse error. Default to the 2-space layout for new files.
    local item_indent="  "
    if grep -qE '^-[[:space:]]' "$BYPASS_LOG" 2>/dev/null; then
        item_indent=""
    fi

    local action_q reason_q
    action_q=$(_bypass_yaml_sq "$action")
    reason_q=$(_bypass_yaml_sq "$reason")

    # Append the entry
    cat >> "$BYPASS_LOG" << EOF
${item_indent}- timestamp: $timestamp
${item_indent}  action: $action_q
${item_indent}  commit: $commit
${item_indent}  authorized_by: $authorized_by
${item_indent}  reason: $reason_q
${item_indent}  retroactive_task: $retroactive_task
EOF

    # F-21: a writer that can produce an unparseable audit trail without
    # noticing is worse than the corruption itself — validate what was just
    # written and surface it loudly rather than silently. Best-effort: skip
    # if python3/PyYAML aren't available rather than blocking the commit flow
    # the bypass log exists to audit.
    # T-4349: a failed parse is now a hard error (non-zero return), not a warning.
    if command -v python3 >/dev/null 2>&1; then
        if ! python3 -c "import yaml; yaml.safe_load(open('$BYPASS_LOG'))" 2>/dev/null; then
            echo -e "${RED}ERROR: $BYPASS_LOG is not valid YAML after this write.${NC}" >&2
            echo "  The bypass entry was appended but the file no longer parses." >&2
            echo "  Inspect and repair it manually — this is the audit trail for Tier-2 bypasses." >&2
            return 1
        fi
    fi

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
