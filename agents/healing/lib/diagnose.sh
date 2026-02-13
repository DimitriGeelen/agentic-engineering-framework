#!/bin/bash
# Healing Agent - diagnose command
# Analyze task issues and suggest recovery actions

# Failure type keywords
declare -A FAILURE_TYPES
FAILURE_TYPES[code]="error|exception|bug|syntax|compile|runtime|crash|null|undefined"
FAILURE_TYPES[dependency]="dependency|package|module|import|require|version|conflict"
FAILURE_TYPES[environment]="environment|config|path|permission|access|connection|timeout"
FAILURE_TYPES[design]="design|architecture|approach|refactor|rethink|wrong|incorrect"
FAILURE_TYPES[external]="api|service|network|third-party|external|upstream"

classify_failure() {
    local text="$1"
    local text_lower=$(echo "$text" | tr '[:upper:]' '[:lower:]')

    for type in "${!FAILURE_TYPES[@]}"; do
        if echo "$text_lower" | grep -qE "${FAILURE_TYPES[$type]}"; then
            echo "$type"
            return
        fi
    done
    echo "unknown"
}

find_similar_patterns() {
    local failure_type="$1"
    local description="$2"

    if [ ! -f "$PATTERNS_FILE" ]; then
        return
    fi

    # Look for matching patterns in patterns.yaml
    local matches=""
    while IFS= read -r line; do
        if [[ "$line" =~ ^[[:space:]]*-[[:space:]]id:[[:space:]]FP- ]]; then
            # Start of a failure pattern
            local current_id=$(echo "$line" | grep -oE "FP-[0-9]+")
            local pattern_text=""
            local mitigation=""

            # Read next few lines for pattern and mitigation
            while IFS= read -r detail; do
                [[ "$detail" =~ ^[[:space:]]*-[[:space:]]id: ]] && break
                [[ "$detail" =~ pattern: ]] && pattern_text=$(echo "$detail" | sed 's/.*pattern: "//' | sed 's/"$//')
                [[ "$detail" =~ mitigation: ]] && mitigation=$(echo "$detail" | sed 's/.*mitigation: "//' | sed 's/"$//')
            done

            if [ -n "$pattern_text" ]; then
                matches="$matches$current_id: $pattern_text"$'\n'
                [ -n "$mitigation" ] && matches="$matches  Mitigation: $mitigation"$'\n'
            fi
        fi
    done < "$PATTERNS_FILE"

    echo "$matches"
}

do_diagnose() {
    local task_id="${1:-}"

    if [ -z "$task_id" ]; then
        echo -e "${RED}Error: Task ID required${NC}"
        echo "Usage: healing.sh diagnose T-XXX"
        exit 1
    fi

    # Find task file
    local task_file=$(find "$TASKS_DIR" -name "${task_id}-*.md" -type f 2>/dev/null | head -1)
    if [ -z "$task_file" ]; then
        echo -e "${RED}Task not found: $task_id${NC}"
        exit 1
    fi

    # Check task status
    local status=$(grep "^status:" "$task_file" | cut -d: -f2 | tr -d ' ')
    local task_name=$(grep "^name:" "$task_file" | sed 's/name: //')

    echo -e "${BLUE}=== HEALING LOOP DIAGNOSIS ===${NC}"
    echo "Task: $task_id - $task_name"
    echo "Status: $status"
    echo ""

    if [ "$status" != "issues" ] && [ "$status" != "blocked" ]; then
        echo -e "${YELLOW}Note: Task is not in 'issues' or 'blocked' status${NC}"
        echo "Current status: $status"
        echo ""
    fi

    # Extract recent updates for analysis
    local updates_section=$(sed -n '/^## Updates/,/^## /p' "$task_file" | tail -20)
    local latest_update=$(echo "$updates_section" | grep -A5 "^### " | tail -6)

    echo -e "${YELLOW}=== LATEST UPDATE ===${NC}"
    echo "$latest_update" | head -6
    echo ""

    # Classify the failure
    local failure_type=$(classify_failure "$latest_update")
    echo -e "${YELLOW}=== FAILURE CLASSIFICATION ===${NC}"
    echo "Type: $failure_type"

    case "$failure_type" in
        code)
            echo "Category: Code/Implementation error"
            echo "Typical causes: Syntax error, logic bug, null reference, type mismatch"
            ;;
        dependency)
            echo "Category: Dependency issue"
            echo "Typical causes: Missing package, version conflict, circular dependency"
            ;;
        environment)
            echo "Category: Environment/Configuration"
            echo "Typical causes: Missing config, wrong path, permission denied, connection refused"
            ;;
        design)
            echo "Category: Design/Architecture issue"
            echo "Typical causes: Wrong approach, needs refactoring, architectural mismatch"
            ;;
        external)
            echo "Category: External service issue"
            echo "Typical causes: API down, rate limit, network timeout, third-party error"
            ;;
        *)
            echo "Category: Unclassified"
            echo "Add more context to Updates section for better classification"
            ;;
    esac
    echo ""

    # Find similar patterns
    echo -e "${YELLOW}=== SIMILAR PATTERNS ===${NC}"
    local similar=$(find_similar_patterns "$failure_type" "$latest_update")
    if [ -n "$similar" ]; then
        echo "$similar"
    else
        echo "No matching patterns found in patterns.yaml"
        echo "This may be a new failure type - document it when resolved!"
    fi
    echo ""

    # Suggest recovery actions based on error escalation ladder
    echo -e "${YELLOW}=== SUGGESTED RECOVERY (Error Escalation Ladder) ===${NC}"
    echo ""
    echo "A. Don't repeat the same failure:"
    echo "   - Check patterns.yaml for known mitigations"
    echo "   - Review similar task episodic summaries"
    echo ""
    echo "B. Improve technique:"
    case "$failure_type" in
        code)
            echo "   - Add input validation"
            echo "   - Add error handling"
            echo "   - Write test case for this scenario"
            ;;
        dependency)
            echo "   - Pin dependency versions"
            echo "   - Add dependency check to build"
            echo "   - Consider alternative package"
            ;;
        environment)
            echo "   - Add environment validation on startup"
            echo "   - Create setup/check script"
            echo "   - Document required configuration"
            ;;
        design)
            echo "   - Revisit design record"
            echo "   - Consider alternative approach"
            echo "   - Get second opinion (spawn Plan agent)"
            ;;
        external)
            echo "   - Add retry logic with backoff"
            echo "   - Add circuit breaker"
            echo "   - Cache responses where possible"
            ;;
        *)
            echo "   - Add more logging"
            echo "   - Isolate the problem"
            echo "   - Break into smaller steps"
            ;;
    esac
    echo ""
    echo "C. Improve tooling:"
    echo "   - Add automated check for this condition"
    echo "   - Update audit agent to detect this"
    echo ""
    echo "D. Change ways of working:"
    echo "   - Add to pre-work checklist"
    echo "   - Create new practice from this lesson"
    echo ""

    echo -e "${BLUE}=== NEXT STEPS ===${NC}"
    echo "1. Apply fix based on suggestions above"
    echo "2. Update task status back to 'started-work'"
    echo "3. Run: healing.sh resolve $task_id --mitigation 'What you did'"
    echo ""
}
