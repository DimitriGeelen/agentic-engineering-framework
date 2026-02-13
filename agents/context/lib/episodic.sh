#!/bin/bash
# Context Agent - generate-episodic command
# Generate rich episodic summary for a completed task

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

    # Parse Updates section for timeline events
    local updates_section=$(sed -n '/^## Updates/,/^## /p' "$task_file" | head -n -1)
    local update_count=$(echo "$updates_section" | grep -c "^### " || echo 0)
    update_count=$(echo "$update_count" | tr -d '[:space:]')

    # Extract outcomes from acceptance criteria (look for [x] items)
    local outcomes=""
    local ac_section=$(sed -n '/^## Specification Record/,/^## /p' "$task_file")
    local completed_criteria=$(echo "$ac_section" | grep -E "^\s*-\s*\[x\]" | sed 's/.*\[x\] /- /' | head -5)
    if [ -n "$completed_criteria" ]; then
        outcomes="$completed_criteria"
    fi

    # Identify challenges (look for "issues", "blocked", "failed", "error" in updates)
    local challenges=""
    local challenge_lines=$(echo "$updates_section" | grep -iE "(issue|blocked|fail|error|problem|bug|fix)" | head -3)
    if [ -n "$challenge_lines" ]; then
        challenges=$(echo "$challenge_lines" | sed 's/^.*— //' | sed 's/\[.*\]//' | tr -d '#' | sed 's/^/- /')
    fi

    # Extract files from updates (look for file paths)
    local files_created=""
    local files_modified=""
    local file_refs=$(echo "$updates_section" | grep -oE '\`[^`]+\.(sh|md|yaml|py|js|ts)\`' | tr -d '`' | sort -u | head -10)
    if [ -n "$file_refs" ]; then
        files_created=$(echo "$file_refs" | sed 's/^/    - "/' | sed 's/$/"/')
    fi

    # Calculate duration
    local created_date=$(echo "$created" | cut -d'T' -f1)
    local completed_date=$(echo "$last_update" | cut -d'T' -f1)
    local duration_days=0
    if [ "$created_date" != "$completed_date" ]; then
        # Simple day calculation (not perfect but good enough)
        duration_days=$(( ($(date -d "$completed_date" +%s) - $(date -d "$created_date" +%s)) / 86400 ))
    fi

    # Generate episodic file
    local episodic_file="$CONTEXT_DIR/episodic/${task_id}.yaml"
    local generated_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    cat > "$episodic_file" << EOF
# Episodic Memory - ${task_id}: ${task_name}
# Generated: $generated_at

task_id: $task_id
task_name: "$task_name"
workflow_type: $workflow_type

# Timeline
created: $created
completed: $last_update
duration_days: $duration_days
updates_count: $update_count

# Summary
summary: |
  $description

# Key outcomes (from acceptance criteria)
outcomes:
EOF

    # Add outcomes
    if [ -n "$outcomes" ]; then
        echo "$outcomes" | while read -r line; do
            [ -n "$line" ] && echo "  $line" >> "$episodic_file"
        done
    else
        echo "  - \"Task completed\"" >> "$episodic_file"
    fi

    cat >> "$episodic_file" << EOF

# What worked well
successes: []
  # Add manually or via LLM analysis

# Challenges encountered
challenges:
EOF

    # Add challenges
    if [ -n "$challenges" ]; then
        echo "$challenges" | while read -r line; do
            if [ -n "$line" ]; then
                echo "  - description: \"$(echo "$line" | sed 's/^- //')\"" >> "$episodic_file"
                echo "    resolution: \"See task updates\"" >> "$episodic_file"
            fi
        done
    else
        echo "  # No challenges detected (or add manually)" >> "$episodic_file"
    fi

    cat >> "$episodic_file" << EOF

# Decisions made during this task
decisions: []
  # Extract from Design Record or add manually

# Files created or significantly modified
artifacts:
  created:
EOF

    # Add files
    if [ -n "$files_created" ]; then
        echo "$files_created" >> "$episodic_file"
    else
        echo "    # Add file list manually" >> "$episodic_file"
    fi

    cat >> "$episodic_file" << EOF
  modified: []

# Related tasks
related_tasks:
  blocked: []
  absorbed: []
  spawned: []

# Tags for retrieval
tags: [$tags]

# Metadata
source_file: $task_file
generated_by: context-agent
EOF

    echo -e "${GREEN}Episodic summary generated: $episodic_file${NC}"
    echo ""
    echo "Summary:"
    echo "  Task: $task_name"
    echo "  Duration: $duration_days days"
    echo "  Updates: $update_count"
    [ -n "$outcomes" ] && echo "  Outcomes: $(echo "$outcomes" | wc -l | tr -d ' ')"
    [ -n "$challenges" ] && echo "  Challenges: $(echo "$challenges" | wc -l | tr -d ' ')"
}
