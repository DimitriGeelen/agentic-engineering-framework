#!/bin/bash
# Healing Agent - patterns command
# Show known failure patterns and mitigations

do_patterns() {
    echo -e "${BLUE}=== KNOWN FAILURE PATTERNS ===${NC}"
    echo ""

    if [ ! -f "$PATTERNS_FILE" ]; then
        echo "No patterns file found at $PATTERNS_FILE"
        echo "Patterns are recorded when issues are resolved via 'healing.sh resolve'"
        return 0
    fi

    local pattern_count=0
    local current_id=""
    local current_pattern=""
    local current_mitigation=""
    local current_task=""
    local in_failure=false

    while IFS= read -r line || [ -n "$line" ]; do
        # Detect failure_patterns section
        if [[ "$line" == "failure_patterns:" ]]; then
            in_failure=true
            continue
        fi

        # Detect end of failure_patterns (start of another section)
        if [[ "$line" =~ ^[a-z_]+_patterns: ]] && [[ "$line" != "failure_patterns:" ]]; then
            # Print last pattern before exiting section
            if [ -n "$current_id" ]; then
                echo -e "${YELLOW}$current_id${NC}: $current_pattern"
                [ -n "$current_mitigation" ] && echo "  Mitigation: $current_mitigation"
                [ -n "$current_task" ] && echo "  From: $current_task"
                echo ""
                pattern_count=$((pattern_count + 1))
            fi
            in_failure=false
            current_id=""
            continue
        fi

        if [ "$in_failure" = true ]; then
            # Check for new pattern entry
            if [[ "$line" =~ ^[[:space:]]*-[[:space:]]id:[[:space:]]*(FP-[0-9]+) ]]; then
                # Print previous pattern if exists
                if [ -n "$current_id" ]; then
                    echo -e "${YELLOW}$current_id${NC}: $current_pattern"
                    [ -n "$current_mitigation" ] && echo "  Mitigation: $current_mitigation"
                    [ -n "$current_task" ] && echo "  From: $current_task"
                    echo ""
                    pattern_count=$((pattern_count + 1))
                fi
                # Start new pattern
                current_id="${BASH_REMATCH[1]}"
                current_pattern=""
                current_mitigation=""
                current_task=""
            elif [[ "$line" =~ pattern:[[:space:]]*\"(.*)\" ]]; then
                current_pattern="${BASH_REMATCH[1]}"
            elif [[ "$line" =~ mitigation:[[:space:]]*\"(.*)\" ]]; then
                current_mitigation="${BASH_REMATCH[1]}"
            elif [[ "$line" =~ learned_from:[[:space:]]*(T-[0-9]+) ]]; then
                current_task="${BASH_REMATCH[1]}"
            fi
        fi
    done < "$PATTERNS_FILE"

    # Print last pattern if we're still in failure section
    if [ -n "$current_id" ] && [ "$in_failure" = true ]; then
        echo -e "${YELLOW}$current_id${NC}: $current_pattern"
        [ -n "$current_mitigation" ] && echo "  Mitigation: $current_mitigation"
        [ -n "$current_task" ] && echo "  From: $current_task"
        echo ""
        pattern_count=$((pattern_count + 1))
    fi

    echo -e "${BLUE}Total failure patterns: $pattern_count${NC}"
    echo ""
    echo "To add a new pattern: healing.sh resolve T-XXX --mitigation 'fix description'"
}
