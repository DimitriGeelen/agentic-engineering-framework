#!/bin/bash
# Context Agent - generate-episodic command
# Generate episodic summary for a completed task

do_generate_episodic() {
    ensure_context_dirs

    local task_id="${1:-}"

    if [ -z "$task_id" ]; then
        echo -e "${RED}Error: Task ID required${NC}"
        echo "Usage: $0 generate-episodic T-XXX"
        exit 1
    fi

    # Find task file (check completed first, then active)
    local task_file=$(find "$PROJECT_ROOT/.tasks/completed" -name "${task_id}-*.md" -type f 2>/dev/null | head -1)
    if [ -z "$task_file" ]; then
        task_file=$(find "$PROJECT_ROOT/.tasks/active" -name "${task_id}-*.md" -type f 2>/dev/null | head -1)
    fi

    if [ -z "$task_file" ]; then
        echo -e "${RED}Task not found: $task_id${NC}"
        exit 1
    fi

    # Extract frontmatter fields
    local task_name=$(grep "^name:" "$task_file" | sed 's/name: //')
    local workflow_type=$(grep "^workflow_type:" "$task_file" | sed 's/workflow_type: //')
    local created=$(grep "^created:" "$task_file" | sed 's/created: //')
    local last_update=$(grep "^last_update:" "$task_file" | sed 's/last_update: //')
    local tags=$(grep "^tags:" "$task_file" | sed 's/tags: //' | tr -d '[]')
    local description=$(grep "^description:" "$task_file" | sed 's/description: //' | sed 's/^> //')

    # Calculate duration (simplified - just use dates)
    local created_date=$(echo "$created" | cut -d'T' -f1)
    local completed_date=$(echo "$last_update" | cut -d'T' -f1)

    # Count updates
    local update_count=$(grep -c "^### " "$task_file" 2>/dev/null || echo 0)

    # Generate episodic file
    local episodic_file="$CONTEXT_DIR/episodic/${task_id}.yaml"

    cat > "$episodic_file" << EOF
# Episodic Memory - ${task_id}: ${task_name}
# Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")

task_id: $task_id
task_name: "$task_name"
workflow_type: $workflow_type

# Timeline
created: $created
completed: $last_update
duration_days: 0  # TODO: Calculate from dates

# Summary
summary: |
  $description

# Key outcomes
outcomes:
  - "Task completed"
  # TODO: Extract from task updates

# What worked well
successes: []
  # TODO: Extract from task

# What didn't work (initially)
challenges: []
  # TODO: Extract from task

# Decisions made during this task
decisions: []
  # TODO: Extract from task design record

# Files created or significantly modified
artifacts:
  created: []
  modified: []

# Related tasks
related_tasks:
  blocked: []
  absorbed: []
  spawned: []

# Tags for retrieval
tags: [$tags]

# Metadata
updates_count: $update_count
source_file: $task_file
EOF

    echo -e "${GREEN}Episodic summary generated: $episodic_file${NC}"
    echo ""
    echo "Note: This is a basic summary. For richer episodic memory:"
    echo "  - Add outcomes, successes, challenges manually"
    echo "  - Or use an LLM to analyze the task file and enrich the summary"
}
