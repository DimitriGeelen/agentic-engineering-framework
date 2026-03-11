#!/bin/bash
# Healing Agent - diagnose command
# Analyze task issues and suggest recovery actions

# Failure type keywords — ordered from MOST SPECIFIC to LEAST SPECIFIC
# This prevents generic keywords (like "error") from matching before specific ones
CLASSIFY_ORDER=(dependency external environment design code)

declare -A FAILURE_TYPES
FAILURE_TYPES[dependency]="dependency|package|module|import|require|version.conflict|pip.install|npm.install|missing.module"
FAILURE_TYPES[external]="api|service|network|third-party|external|upstream|rate.limit|endpoint"
FAILURE_TYPES[environment]="environment|config|\.env|path.not.found|permission.denied|access.denied|connection.refused"
FAILURE_TYPES[design]="design|architecture|approach|refactor|rethink|redesign|wrong.approach"
FAILURE_TYPES[code]="error|exception|bug|syntax|compile|runtime|crash|null|undefined|traceback"

classify_failure() {
    local text="$1"
    local text_lower=$(echo "$text" | tr '[:upper:]' '[:lower:]')

    # Score each type — count keyword matches
    local best_type="unknown"
    local best_score=0

    for type in "${CLASSIFY_ORDER[@]}"; do
        local score=0
        local keywords="${FAILURE_TYPES[$type]}"

        # Count how many keywords match
        IFS='|' read -ra kw_array <<< "$keywords"
        for kw in "${kw_array[@]}"; do
            if echo "$text_lower" | grep -qE "$kw"; then
                score=$((score + 1))
            fi
        done

        # Prefer specific types: if dependency has ANY match, it beats code
        # unless code has significantly more matches
        if [ "$score" -gt "$best_score" ]; then
            best_score=$score
            best_type=$type
        fi
    done

    echo "$best_type"
}

find_similar_patterns() {
    local failure_type="$1"
    local description="$2"

    # T-270: Semantic pattern matching via fw ask — replaces 80 lines of keyword matching
    local query="Find failure patterns similar to this issue (type: ${failure_type}): ${description}. List matching pattern IDs (FP-XXX) with their mitigations. If no patterns match, say so."
    local result
    result=$(python3 "$FRAMEWORK_ROOT/lib/ask.py" --concise --no-think --limit 5 "$query" 2>/dev/null) || true

    if [ -n "$result" ]; then
        echo "$result"
    else
        echo "Semantic search unavailable (Ollama not running or index not built)"
        echo "Start Ollama and rebuild index for pattern matching"
    fi
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
    local status=$(get_yaml_field "$task_file" "status")
    local task_name=$(get_yaml_field "$task_file" "name")

    echo -e "${CYAN}=== HEALING LOOP DIAGNOSIS ===${NC}"
    echo "Task: $task_id - $task_name"
    echo "Status: $status"
    echo ""

    if [ "$status" != "issues" ] && [ "$status" != "blocked" ]; then
        echo -e "${YELLOW}Note: Task is not in 'issues' or 'blocked' status${NC}"
        echo "Current status: $status"
        echo ""
    fi

    # Extract recent updates for analysis — get ALL content after last ### header
    local updates_section=$(sed -n '/^## Updates/,/^## [^U]/p' "$task_file")
    local latest_update=$(echo "$updates_section" | tac | sed '/^### /q' | tac)

    echo -e "${YELLOW}=== LATEST UPDATE ===${NC}"
    echo "$latest_update" | head -8
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

    echo -e "${CYAN}=== NEXT STEPS ===${NC}"
    echo "1. Apply fix based on suggestions above"
    echo "2. Update task status back to 'started-work'"
    echo "3. Run: healing.sh resolve $task_id --mitigation 'What you did'"
    echo ""
}
