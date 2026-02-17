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
    local update_count=$(echo "$updates_section" | grep -c "^### " || true)
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

    # Calculate wall-clock minutes from created → last_update
    local wall_minutes=0
    if [ -n "$created" ] && [ -n "$last_update" ]; then
        local start_epoch end_epoch
        start_epoch=$(date -d "$created" +%s 2>/dev/null) || start_epoch=0
        end_epoch=$(date -d "$last_update" +%s 2>/dev/null) || end_epoch=0
        if [ "$start_epoch" -gt 0 ] && [ "$end_epoch" -gt "$start_epoch" ]; then
            wall_minutes=$(( (end_epoch - start_epoch) / 60 ))
        fi
    fi

    # Derive git metrics for this task
    local commit_count=0
    local lines_added=0
    local lines_removed=0
    local files_changed_count=0
    if command -v git >/dev/null 2>&1 && [ -d "$PROJECT_ROOT/.git" ]; then
        commit_count=$(git -C "$PROJECT_ROOT" log --all --oneline --grep="$task_id:" 2>/dev/null | wc -l | tr -d ' ')
        local stat_output
        stat_output=$(git -C "$PROJECT_ROOT" log --all --grep="$task_id:" --numstat --format="" 2>/dev/null || true)
        if [ -n "$stat_output" ]; then
            lines_added=$(echo "$stat_output" | awk '{s+=$1} END {print s+0}')
            lines_removed=$(echo "$stat_output" | awk '{s+=$2} END {print s+0}')
            files_changed_count=$(echo "$stat_output" | awk 'NF>=3 {print $3}' | sort -u | wc -l | tr -d ' ')
        fi
    fi

    # Generate episodic file
    local episodic_file="$CONTEXT_DIR/episodic/${task_id}.yaml"
    local generated_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    cat > "$episodic_file" << EOF
# ============================================================================
# EPISODIC MEMORY - ${task_id}: ${task_name}
# ============================================================================
# STATUS: REQUIRES ENRICHMENT
#
# This is a SKELETON, not a complete summary. The sections marked [TODO]
# must be filled in by a human or LLM before this episodic is useful.
#
# To enrich: Read the source task file and fill in the TODO sections.
# When done: Change enrichment_status from "pending" to "complete"
# ============================================================================
# Generated: $generated_at

task_id: $task_id
task_name: "$task_name"
workflow_type: $workflow_type
enrichment_status: pending  # Change to "complete" after enrichment

# Timeline
created: $created
completed: $last_update
duration_days: $duration_days
updates_count: $update_count

# Summary
# [TODO] Write 2-3 sentences explaining what was accomplished and WHY it matters.
# Don't just copy the description - synthesize the journey from Updates section.
summary: |
  [TODO: Summarize what was done and why it matters. Source: $task_file]

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
# [TODO] List 1-3 things that worked well, with WHY they worked.
# Format: - description: "What worked" / why: "Why it worked"
successes:
  - description: "[TODO: What worked well?]"
    why: "[TODO: Why did it work?]"

# Challenges encountered
# [TODO] List challenges faced and how they were resolved.
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
# [TODO] Extract decisions from Design Record. Include rationale and alternatives rejected.
# Format: - decision: "What was decided" / rationale: "Why" / alternatives_rejected: ["Option B"]
decisions:
  - decision: "[TODO: Extract from Design Record]"
    rationale: "[TODO: Why this choice?]"
    alternatives_rejected: []

# Files created or significantly modified
# [TODO] List actual files created or modified during this task.
artifacts:
  created:
EOF

    # Add files
    if [ -n "$files_created" ]; then
        echo "$files_created" >> "$episodic_file"
    else
        echo "    - \"[TODO: List files created]\"" >> "$episodic_file"
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

# Passive metrics (derived automatically — do not edit)
metrics:
  wall_clock_minutes: $wall_minutes
  commits: $commit_count
  files_changed: $files_changed_count
  lines_added: $lines_added
  lines_removed: $lines_removed

# Metadata
source_file: $task_file
generated_by: context-agent
EOF

    echo -e "${GREEN}Episodic skeleton generated: $episodic_file${NC}"
    echo ""
    echo -e "${YELLOW}⚠ ENRICHMENT REQUIRED${NC}"
    echo "  This is a skeleton with [TODO] placeholders."
    echo "  Fill in the TODO sections, then set enrichment_status: complete"
    echo ""
    echo "Task: $task_name"
    echo "  Duration: $duration_days days ($wall_minutes min)"
    echo "  Updates: $update_count"
    echo "  Commits: $commit_count"
    echo "  Lines: +$lines_added -$lines_removed across $files_changed_count files"
    [ -n "$outcomes" ] && echo "  Outcomes: $(echo "$outcomes" | wc -l | tr -d ' ')"
    [ -n "$challenges" ] && echo "  Challenges: $(echo "$challenges" | wc -l | tr -d ' ')"
    echo ""
    echo "Source: $task_file"
}
