#!/bin/bash
# Context Agent - generate-episodic command
# Generate rich episodic summary for a completed task
#
# Hybrid approach (D-023): Git owns timeline/metrics/artifacts,
# task file owns AC + decisions, episodic merges both automatically.

# =============================================================================
# Git-mining helper functions
# =============================================================================

# Extract commit messages as timeline (timestamp + subject)
mine_git_timeline() {
    local task_id="$1"
    git -C "$PROJECT_ROOT" log --all --grep="^${task_id}:" \
        --format="%ai %s" --reverse 2>/dev/null || true
}

# Extract challenges: commits with fix/revert/bug/error keywords
mine_git_challenges() {
    local task_id="$1"
    git -C "$PROJECT_ROOT" log --all --grep="^${task_id}:" \
        --format="%s" 2>/dev/null | \
        grep -iE "fix|revert|bug|issue|error" | \
        sed "s/^${task_id}: //" || true
}

# Extract unique files changed across all task commits
mine_git_artifacts() {
    local task_id="$1"
    git -C "$PROJECT_ROOT" log --all --grep="^${task_id}:" \
        --name-only --format="" 2>/dev/null | \
        sort -u | grep -v '^$' || true
}

# Deduplicated commit messages (strip task prefix)
mine_git_summary() {
    local task_id="$1"
    git -C "$PROJECT_ROOT" log --all --grep="^${task_id}:" \
        --format="%s" --reverse 2>/dev/null | \
        sed "s/^${task_id}: //" | \
        awk '!seen[$0]++' || true
}

# First and last commit timestamps (more accurate than frontmatter)
mine_git_timestamps() {
    local task_id="$1"
    local first last
    first=$(git -C "$PROJECT_ROOT" log --all --grep="^${task_id}:" \
        --format="%aI" --reverse 2>/dev/null | head -1)
    last=$(git -C "$PROJECT_ROOT" log --all --grep="^${task_id}:" \
        --format="%aI" 2>/dev/null | head -1)
    echo "${first:-}|${last:-}"
}

# =============================================================================
# Main generator
# =============================================================================

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

    # =========================================================================
    # Extract frontmatter fields
    # =========================================================================
    local task_name=$(grep "^name:" "$task_file" | sed 's/name: //')
    local workflow_type=$(grep "^workflow_type:" "$task_file" | sed 's/workflow_type: //')
    local created=$(grep "^created:" "$task_file" | sed 's/created: //')
    local last_update=$(grep "^last_update:" "$task_file" | sed 's/last_update: //')
    local tags=$(grep "^tags:" "$task_file" | sed 's/tags: //' | tr -d '[]')
    local description=$(grep "^description:" "$task_file" | sed 's/description: //' | sed 's/^> //')

    # Parse Updates section for count
    local updates_section=$(sed -n '/^## Updates/,/^## /p' "$task_file" | head -n -1)
    local update_count=$(echo "$updates_section" | grep -c "^### " || true)
    update_count=$(echo "$update_count" | tr -d '[:space:]')

    # =========================================================================
    # Parse Acceptance Criteria (new template) or Specification Record (old)
    # =========================================================================
    local outcomes=""
    local ac_completed_count=0
    local ac_total_count=0

    # Try new "Acceptance Criteria" section first
    local ac_section=$(sed -n '/^## Acceptance Criteria/,/^## /p' "$task_file" 2>/dev/null)
    if [ -z "$ac_section" ]; then
        # Fall back to old "Specification Record" section
        ac_section=$(sed -n '/^## Specification Record/,/^## /p' "$task_file" 2>/dev/null)
    fi

    if [ -n "$ac_section" ]; then
        local completed_criteria=$(echo "$ac_section" | grep -E '^\s*-\s*\[x\]' | sed 's/.*\[x\] /- /' | head -10)
        if [ -n "$completed_criteria" ]; then
            outcomes="$completed_criteria"
        fi
        ac_completed_count=$(echo "$ac_section" | grep -cE '^\s*-\s*\[x\]' || true)
        ac_total_count=$(echo "$ac_section" | grep -cE '^\s*-\s*\[[ x]\]' || true)
    fi

    # =========================================================================
    # Parse Decisions section from task file
    # =========================================================================
    local decisions_raw=""
    local has_decisions=false
    local decisions_section=$(sed -n '/^## Decisions/,/^## /p' "$task_file" 2>/dev/null | head -n -1)
    if [ -n "$decisions_section" ]; then
        # Check for actual content (not just comments/empty)
        local decision_content=$(echo "$decisions_section" | grep -v '^##' | grep -v '^<!--' | grep -v '^-->' | grep -v '^\s*$' | head -20)
        if [ -n "$decision_content" ]; then
            decisions_raw="$decision_content"
            has_decisions=true
        fi
    fi

    # =========================================================================
    # Git mining
    # =========================================================================
    local git_summary=""
    local git_challenges=""
    local git_artifacts=""
    local git_timeline=""
    local git_timestamps=""
    local commit_count=0
    local lines_added=0
    local lines_removed=0
    local files_changed_count=0

    if command -v git >/dev/null 2>&1 && [ -d "$PROJECT_ROOT/.git" ]; then
        git_summary=$(mine_git_summary "$task_id")
        git_challenges=$(mine_git_challenges "$task_id")
        git_artifacts=$(mine_git_artifacts "$task_id")
        git_timeline=$(mine_git_timeline "$task_id")
        git_timestamps=$(mine_git_timestamps "$task_id")

        commit_count=$(git -C "$PROJECT_ROOT" log --all --oneline --grep="$task_id:" 2>/dev/null | wc -l | tr -d ' ')
        local stat_output
        stat_output=$(git -C "$PROJECT_ROOT" log --all --grep="$task_id:" --numstat --format="" 2>/dev/null || true)
        if [ -n "$stat_output" ]; then
            lines_added=$(echo "$stat_output" | awk '{s+=$1} END {print s+0}')
            lines_removed=$(echo "$stat_output" | awk '{s+=$2} END {print s+0}')
            files_changed_count=$(echo "$stat_output" | awk 'NF>=3 {print $3}' | sort -u | wc -l | tr -d ' ')
        fi
    fi

    # Use git timestamps if available (more accurate than frontmatter)
    local git_first_commit=$(echo "$git_timestamps" | cut -d'|' -f1)
    local git_last_commit=$(echo "$git_timestamps" | cut -d'|' -f2)

    # =========================================================================
    # Calculate duration
    # =========================================================================
    local created_date=$(echo "$created" | cut -d'T' -f1)
    local completed_date=$(echo "$last_update" | cut -d'T' -f1)
    local duration_days=0
    if [ "$created_date" != "$completed_date" ]; then
        duration_days=$(( ($(date -d "$completed_date" +%s) - $(date -d "$created_date" +%s)) / 86400 )) 2>/dev/null || duration_days=0
    fi

    local wall_minutes=0
    if [ -n "$created" ] && [ -n "$last_update" ]; then
        local start_epoch end_epoch
        start_epoch=$(date -d "$created" +%s 2>/dev/null) || start_epoch=0
        end_epoch=$(date -d "$last_update" +%s 2>/dev/null) || end_epoch=0
        if [ "$start_epoch" -gt 0 ] && [ "$end_epoch" -gt "$start_epoch" ]; then
            wall_minutes=$(( (end_epoch - start_epoch) / 60 ))
        fi
    fi

    # =========================================================================
    # Determine enrichment status
    # =========================================================================
    local enrichment_status="pending"
    local status_comment=""

    if [ "$ac_completed_count" -gt 0 ] && [ "$has_decisions" = true ]; then
        enrichment_status="complete"
        status_comment="# AC checked + decisions recorded"
    elif [ "$ac_completed_count" -gt 0 ] && [ "$has_decisions" = false ]; then
        enrichment_status="auto-complete"
        status_comment="# Mechanical task — AC checked, no decisions to record"
    elif [ "$commit_count" -gt 0 ] && [ -n "$git_summary" ]; then
        enrichment_status="git-derived"
        status_comment="# Auto-filled from git; AC/decisions not in task file"
    else
        enrichment_status="pending"
        status_comment="# No git commits or AC found — needs manual enrichment"
    fi

    # =========================================================================
    # Build summary from git
    # =========================================================================
    local summary_text=""
    if [ -n "$git_summary" ]; then
        # Join commit messages into a narrative
        summary_text=$(echo "$git_summary" | paste -sd '. ' | sed 's/\. $/./')
    fi
    # Fall back to description if no git summary
    if [ -z "$summary_text" ]; then
        summary_text="${description:-[TODO: No git commits found. Summarize manually.]}"
    fi

    # =========================================================================
    # Generate episodic file
    # =========================================================================
    local episodic_file="$CONTEXT_DIR/episodic/${task_id}.yaml"
    local generated_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # Header changes based on enrichment status
    local header_status="AUTO-GENERATED"
    local header_note="Hybrid episodic: git-mined timeline/metrics + task-file decisions/AC."
    if [ "$enrichment_status" = "pending" ]; then
        header_status="REQUIRES ENRICHMENT"
        header_note="Limited data sources. Review and fill missing sections manually."
    fi

    cat > "$episodic_file" << HEREDOC
# ============================================================================
# EPISODIC MEMORY - ${task_id}: ${task_name}
# ============================================================================
# STATUS: ${header_status}
# ${header_note}
# Generated: $generated_at
# ============================================================================

task_id: $task_id
task_name: "$task_name"
workflow_type: $workflow_type
enrichment_status: $enrichment_status  $status_comment

# Timeline
created: $created
completed: $last_update
duration_days: $duration_days
updates_count: $update_count
HEREDOC

    # Add git timestamps if available
    if [ -n "$git_first_commit" ]; then
        echo "first_commit: $git_first_commit" >> "$episodic_file"
    fi
    if [ -n "$git_last_commit" ]; then
        echo "last_commit: $git_last_commit" >> "$episodic_file"
    fi

    # Summary section
    cat >> "$episodic_file" << HEREDOC

# Summary (auto-generated from git commit messages)
summary: |
  $summary_text

# Key outcomes
outcomes:
HEREDOC

    # Add outcomes from AC
    if [ -n "$outcomes" ]; then
        echo "$outcomes" | while read -r line; do
            [ -n "$line" ] && echo "  $line" >> "$episodic_file"
        done
    else
        echo "  - \"Task completed\"" >> "$episodic_file"
    fi

    # Challenges section — auto-filled from git
    echo "" >> "$episodic_file"
    echo "# Challenges (auto-detected from git: commits with fix/revert/bug/error)" >> "$episodic_file"
    echo "challenges:" >> "$episodic_file"
    if [ -n "$git_challenges" ]; then
        echo "$git_challenges" | while read -r line; do
            if [ -n "$line" ]; then
                # Escape quotes in the line
                local escaped=$(echo "$line" | sed 's/"/\\"/g')
                echo "  - description: \"$escaped\"" >> "$episodic_file"
                echo "    source: git-mined" >> "$episodic_file"
            fi
        done
    else
        echo "  # No challenges detected in commit messages" >> "$episodic_file"
    fi

    # Decisions section — from task file
    echo "" >> "$episodic_file"
    echo "# Decisions (from task file Decisions section)" >> "$episodic_file"
    echo "decisions:" >> "$episodic_file"
    if [ "$has_decisions" = true ]; then
        # Parse decision entries from markdown format
        # Expected format: ### date — topic / - **Chose:** / - **Why:** / - **Rejected:**
        echo "$decisions_raw" | while read -r line; do
            if echo "$line" | grep -q '^### '; then
                local topic=$(echo "$line" | sed 's/^### //' | sed 's/"/\\"/g')
                echo "  - decision: \"$topic\"" >> "$episodic_file"
            elif echo "$line" | grep -q '^\*\*Chose:\*\*\|^- \*\*Chose:\*\*'; then
                local chose=$(echo "$line" | sed 's/.*\*\*Chose:\*\* *//' | sed 's/"/\\"/g')
                echo "    chose: \"$chose\"" >> "$episodic_file"
            elif echo "$line" | grep -q '^\*\*Why:\*\*\|^- \*\*Why:\*\*'; then
                local why=$(echo "$line" | sed 's/.*\*\*Why:\*\* *//' | sed 's/"/\\"/g')
                echo "    rationale: \"$why\"" >> "$episodic_file"
            elif echo "$line" | grep -q '^\*\*Rejected:\*\*\|^- \*\*Rejected:\*\*'; then
                local rej=$(echo "$line" | sed 's/.*\*\*Rejected:\*\* *//' | sed 's/"/\\"/g')
                echo "    alternatives_rejected: [\"$rej\"]" >> "$episodic_file"
            fi
        done
    else
        echo "  # No decisions recorded (mechanical task or old template)" >> "$episodic_file"
    fi

    # Artifacts section — auto-filled from git
    echo "" >> "$episodic_file"
    echo "# Artifacts (auto-mined from git --name-only)" >> "$episodic_file"
    echo "artifacts:" >> "$episodic_file"
    if [ -n "$git_artifacts" ]; then
        echo "$git_artifacts" | while read -r line; do
            [ -n "$line" ] && echo "  - \"$line\"" >> "$episodic_file"
        done
    else
        echo "  # No artifacts found in git" >> "$episodic_file"
    fi

    # Git timeline section
    echo "" >> "$episodic_file"
    echo "# Timeline (auto-mined from git log)" >> "$episodic_file"
    echo "git_timeline:" >> "$episodic_file"
    if [ -n "$git_timeline" ]; then
        echo "$git_timeline" | while read -r line; do
            if [ -n "$line" ]; then
                # Format: "2026-02-17 14:00:00 +0100 T-116: message"
                local ts=$(echo "$line" | awk '{print $1"T"$2}')
                local msg=$(echo "$line" | cut -d' ' -f4-)
                local escaped_msg=$(echo "$msg" | sed 's/"/\\"/g')
                echo "  - time: \"$ts\"" >> "$episodic_file"
                echo "    action: \"$escaped_msg\"" >> "$episodic_file"
            fi
        done
    else
        echo "  # No git timeline available" >> "$episodic_file"
    fi

    # Successes — still needs judgment, but provide hint
    echo "" >> "$episodic_file"
    echo "# What worked well (requires judgment — [TODO] if enrichment_status is pending)" >> "$episodic_file"
    echo "successes:" >> "$episodic_file"
    if [ "$enrichment_status" = "pending" ]; then
        echo "  - description: \"[TODO: What worked well?]\"" >> "$episodic_file"
        echo "    why: \"[TODO: Why did it work?]\"" >> "$episodic_file"
    else
        echo "  # Completed successfully in $commit_count commit(s), $wall_minutes min" >> "$episodic_file"
    fi

    # Static sections
    cat >> "$episodic_file" << HEREDOC

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
generated_by: context-agent-hybrid
HEREDOC

    # =========================================================================
    # Output
    # =========================================================================
    local status_icon="✓"
    local status_label="Auto-generated"
    if [ "$enrichment_status" = "pending" ]; then
        status_icon="⚠"
        status_label="Needs enrichment"
    fi

    echo -e "${GREEN}Episodic generated: $episodic_file${NC}"
    echo ""
    echo "  Status: $status_icon $enrichment_status ($status_label)"
    echo "  Task: $task_name"
    echo "  Duration: $duration_days days ($wall_minutes min)"
    echo "  Updates: $update_count"
    echo "  Commits: $commit_count"
    echo "  Lines: +$lines_added -$lines_removed across $files_changed_count files"
    [ -n "$outcomes" ] && echo "  Outcomes: $(echo "$outcomes" | wc -l | tr -d ' ') AC checked"
    [ -n "$git_challenges" ] && echo "  Challenges: $(echo "$git_challenges" | wc -l | tr -d ' ') detected from git"
    [ -n "$git_artifacts" ] && echo "  Artifacts: $(echo "$git_artifacts" | wc -l | tr -d ' ') files tracked"
    [ "$has_decisions" = true ] && echo "  Decisions: recorded from task file"
    echo ""
    echo "Source: $task_file"
}
