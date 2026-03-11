#!/bin/bash
# Healing Agent - suggest command
# Get suggestions for all tasks with issues

do_suggest() {
    echo -e "${CYAN}=== HEALING SUGGESTIONS ===${NC}"
    echo ""

    # Find tasks with issues or blocked status
    local issues_tasks=$(grep -rl "^status: issues" "$TASKS_DIR/active" 2>/dev/null)
    local blocked_tasks=$(grep -rl "^status: blocked" "$TASKS_DIR/active" 2>/dev/null)

    local all_problem_tasks="$issues_tasks"$'\n'"$blocked_tasks"
    all_problem_tasks=$(echo "$all_problem_tasks" | grep -v "^$" | sort -u)

    if [ -z "$all_problem_tasks" ]; then
        echo -e "${GREEN}No tasks with issues or blocked status!${NC}"
        echo ""
        echo "All active tasks are progressing normally."
        exit 0
    fi

    local count=0
    while IFS= read -r task_file; do
        [ -z "$task_file" ] && continue
        [ ! -f "$task_file" ] && continue

        local task_id=$(get_yaml_field "$task_file" "id")
        local task_name=$(get_yaml_field "$task_file" "name")
        local status=$(get_yaml_field "$task_file" "status")

        echo -e "${YELLOW}$task_id${NC}: $task_name"
        echo "  Status: $status"

        # Get latest update
        local latest=$(sed -n '/^## Updates/,/^## /p' "$task_file" | grep -A2 "^### " | tail -3 | head -2)
        if [ -n "$latest" ]; then
            echo "  Latest: $(echo "$latest" | tr '\n' ' ' | head -c 60)..."
        fi

        echo "  Action: Run 'healing.sh diagnose $task_id' for detailed analysis"
        echo ""
        ((count++))
    done <<< "$all_problem_tasks"

    echo -e "${CYAN}Total tasks needing attention: $count${NC}"
}
