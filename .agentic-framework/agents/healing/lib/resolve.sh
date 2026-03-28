#!/bin/bash
# Healing Agent - resolve command
# Mark issue resolved and log pattern for future learning

do_resolve() {
    local task_id=""
    local mitigation=""
    local pattern_name=""

    # Parse arguments
    while [ $# -gt 0 ]; do
        case "$1" in
            --mitigation)
                mitigation="$2"
                shift 2
                ;;
            --pattern)
                pattern_name="$2"
                shift 2
                ;;
            -*)
                echo -e "${RED}Unknown option: $1${NC}"
                exit 1
                ;;
            *)
                task_id="$1"
                shift
                ;;
        esac
    done

    if [ -z "$task_id" ]; then
        echo -e "${RED}Error: Task ID required${NC}"
        echo "Usage: healing.sh resolve T-XXX --mitigation 'What you did'"
        exit 1
    fi

    # Find task file
    local task_file=$(find "$TASKS_DIR" -name "${task_id}-*.md" -type f 2>/dev/null | head -1)
    if [ -z "$task_file" ]; then
        echo -e "${RED}Task not found: $task_id${NC}"
        exit 1
    fi

    local task_name=$(get_yaml_field "$task_file" "name")
    local status=$(get_yaml_field "$task_file" "status")

    echo -e "${CYAN}=== RESOLUTION RECORDING ===${NC}"
    echo "Task: $task_id - $task_name"
    echo ""

    # If no mitigation provided, prompt for it
    if [ -z "$mitigation" ]; then
        echo "What was the mitigation/fix?"
        read -r mitigation
    fi

    if [ -z "$mitigation" ]; then
        echo -e "${RED}Mitigation is required to record the resolution${NC}"
        exit 1
    fi

    # Get pattern name if not provided
    if [ -z "$pattern_name" ]; then
        echo "Short name for this failure pattern (e.g., 'timestamp-update-loop'):"
        read -r pattern_name
    fi

    if [ -z "$pattern_name" ]; then
        pattern_name="resolved-issue-$task_id"
    fi

    # Add failure pattern to patterns.yaml
    if [ -f "$PATTERNS_FILE" ]; then
        # Get next FP ID
        local max_id=$(grep "^  - id: FP-" "$PATTERNS_FILE" | sed 's/.*FP-0*//' | sort -n | tail -1)
        local next_id=$((${max_id:-0} + 1))
        local fp_id=$(printf "FP-%03d" $next_id)

        local date=$(date -u +"%Y-%m-%d")

        # Insert new pattern before the success_patterns or comment line
        local temp_file=$(mktemp)
        awk -v id="$fp_id" -v pattern="$pattern_name" -v task="$task_id" -v date="$date" -v mitigation="$mitigation" '
            /^success_patterns:/ {
                print "  - id: " id
                print "    pattern: \"" pattern "\""
                print "    description: \"Issue resolved in " task "\""
                print "    learned_from: " task
                print "    date_learned: " date
                print "    mitigation: \"" mitigation "\""
                print ""
                inserted = 1
            }
            { print }
        ' "$PATTERNS_FILE" > "$temp_file"
        mv "$temp_file" "$PATTERNS_FILE"

        echo -e "${GREEN}Pattern recorded: $fp_id${NC}"
        echo "  Pattern: $pattern_name"
        echo "  Mitigation: $mitigation"
        echo ""
    else
        echo -e "${YELLOW}Warning: patterns.yaml not found, pattern not recorded${NC}"
    fi

    # Add learning to learnings.yaml
    local learnings_file="$CONTEXT_DIR/project/learnings.yaml"
    if [ -f "$learnings_file" ]; then
        local max_lid=$(grep "^  - id: L-" "$learnings_file" | sed 's/.*L-0*//' | sort -n | tail -1)
        local next_lid=$((${max_lid:-0} + 1))
        local l_id=$(printf "L-%03d" $next_lid)
        local date=$(date -u +"%Y-%m-%d")

        # Append learning
        cat >> "$learnings_file" << EOF

  - id: $l_id
    learning: "$mitigation"
    source: healing-loop
    task: $task_id
    date: $date
    context: "Resolved issue in $task_id"
    application: "Apply when encountering similar $pattern_name issues"
EOF

        echo -e "${GREEN}Learning recorded: $l_id${NC}"
    fi

    # Update task with resolution note
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local update_entry="
### ${timestamp} — issue-resolved [healing-agent]
- **Action:** Issue resolved via healing loop
- **Output:** Pattern $fp_id recorded
- **Mitigation:** $mitigation
- **Context:** Resolution logged for future reference"

    # Append to task file Updates section
    echo "$update_entry" >> "$task_file"

    echo ""
    echo -e "${GREEN}Resolution complete!${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Update task status to 'started-work': sed -i 's/^status:.*/status: started-work/' '$task_file'"
    echo "2. Continue work on the task"
    echo "3. The pattern and learning are now available for future reference"
}
