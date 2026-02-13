#!/bin/bash
# Audit Agent - Mechanical Compliance Checks
# Evaluates framework compliance against specifications

PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TASKS_DIR="$PROJECT_ROOT/.tasks"
CONTEXT_DIR="$PROJECT_ROOT/.context"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Counters
PASS_COUNT=0
WARN_COUNT=0
FAIL_COUNT=0

# Priority actions
declare -a PRIORITY_ACTIONS

# Logging functions
pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    PASS_COUNT=$((PASS_COUNT + 1))
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
    echo "       Evidence: $2"
    echo "       Mitigation: $3"
    WARN_COUNT=$((WARN_COUNT + 1))
    PRIORITY_ACTIONS+=("$3")
}

fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    echo "       Evidence: $2"
    echo "       Mitigation: $3"
    FAIL_COUNT=$((FAIL_COUNT + 1))
    PRIORITY_ACTIONS+=("$3")
}

# Header
echo "=== AUDIT REPORT ==="
echo "Timestamp: $(date -Iseconds)"
echo "Project: $PROJECT_ROOT"
echo ""

# ============================================
# SECTION 1: STRUCTURE CHECKS
# ============================================
echo "=== STRUCTURE CHECKS ==="

# Check .tasks/ directory
if [ -d "$TASKS_DIR" ]; then
    pass "Tasks directory exists"
else
    fail "Tasks directory missing" \
         ".tasks/ not found" \
         "Run: mkdir -p .tasks/{active,completed,templates}"
fi

# Check subdirectories
for subdir in active completed templates; do
    if [ -d "$TASKS_DIR/$subdir" ]; then
        pass "Tasks/$subdir directory exists"
    else
        warn "Tasks/$subdir directory missing" \
             ".tasks/$subdir not found" \
             "Run: mkdir -p .tasks/$subdir"
    fi
done

# Check template exists
if [ -f "$TASKS_DIR/templates/default.md" ]; then
    pass "Task template exists"
else
    warn "Task template missing" \
         ".tasks/templates/default.md not found" \
         "Copy zzz-default.md to .tasks/templates/default.md"
fi

echo ""

# ============================================
# SECTION 2: TASK COMPLIANCE CHECKS
# ============================================
echo "=== TASK COMPLIANCE CHECKS ==="

# Required frontmatter fields
REQUIRED_FIELDS="id name description status workflow_type owner created last_update"

# Check each active task
task_count=0
valid_task_count=0

shopt -s nullglob
for task_file in "$TASKS_DIR/active"/*.md; do
    [ -f "$task_file" ] || continue
    task_count=$((task_count + 1))

    task_name=$(basename "$task_file")
    task_valid=true

    # Check required fields
    for field in $REQUIRED_FIELDS; do
        if ! grep -q "^$field:" "$task_file"; then
            warn "Task $task_name missing field: $field" \
                 "Field '$field' not found in frontmatter" \
                 "Add '$field:' to task frontmatter"
            task_valid=false
        fi
    done

    # Check status is valid
    status=$(grep "^status:" "$task_file" | head -1 | cut -d: -f2 | tr -d ' ')
    valid_statuses="captured refined started-work issues blocked work-completed"
    if ! echo "$valid_statuses" | grep -qw "$status"; then
        warn "Task $task_name has invalid status: $status" \
             "Status '$status' not in valid list" \
             "Valid statuses: $valid_statuses"
        task_valid=false
    fi

    # Check workflow_type is valid
    wf_type=$(grep "^workflow_type:" "$task_file" | head -1 | cut -d: -f2 | tr -d ' ')
    valid_types="specification design build test refactor decommission"
    if [ -n "$wf_type" ] && ! echo "$valid_types" | grep -qw "$wf_type"; then
        warn "Task $task_name has invalid workflow_type: $wf_type" \
             "Type '$wf_type' not in valid list" \
             "Valid types: $valid_types"
        task_valid=false
    fi

    # Check Updates section exists
    if ! grep -q "^## Updates" "$task_file"; then
        warn "Task $task_name missing Updates section" \
             "No '## Updates' header found" \
             "Add '## Updates' section to track work"
        task_valid=false
    fi

    if [ "$task_valid" = true ]; then
        valid_task_count=$((valid_task_count + 1))
    fi
done
shopt -u nullglob

if [ $task_count -eq 0 ]; then
    warn "No active tasks found" \
         ".tasks/active/ is empty" \
         "Create tasks for ongoing work"
else
    if [ $valid_task_count -eq $task_count ]; then
        pass "All $task_count active tasks are valid"
    else
        echo "       $valid_task_count of $task_count tasks fully valid"
    fi
fi

echo ""

# ============================================
# SECTION 2B: TASK QUALITY CHECKS (P-001, P-004)
# ============================================
echo "=== TASK QUALITY CHECKS ==="

quality_issues=0

shopt -s nullglob
for task_file in "$TASKS_DIR/active"/*.md; do
    [ -f "$task_file" ] || continue
    task_name=$(basename "$task_file")
    task_id=$(grep "^id:" "$task_file" | head -1 | cut -d: -f2 | tr -d ' ')
    task_status=$(grep "^status:" "$task_file" | head -1 | cut -d: -f2 | tr -d ' ')

    # Quality Check 1: Description length > 50 chars
    description=$(grep "^description:" "$task_file" | head -1 | cut -d: -f2-)
    # Handle multi-line description (YAML > syntax)
    if [ -z "$description" ] || [ "$description" = " >" ]; then
        # Multi-line: get next non-empty line
        description=$(sed -n '/^description:/,/^[a-z_]*:/p' "$task_file" | sed '1d;/^[a-z_]*:/d' | tr -d '\n' | sed 's/^[ ]*//')
    fi
    desc_len=${#description}
    if [ "$desc_len" -lt 50 ]; then
        warn "Task $task_id has short description ($desc_len chars)" \
             "Description should be >= 50 chars for clarity" \
             "Expand description in $task_name"
        quality_issues=$((quality_issues + 1))
    fi

    # Count updates (### headers in Updates section)
    updates_count=$(grep -c "^### " "$task_file" 2>/dev/null || true)
    updates_count=${updates_count:-0}
    # Ensure it's a clean integer
    updates_count=$(echo "$updates_count" | tr -d '[:space:]')

    # Quality Check 2: Updates section has entries for started-work tasks
    if [ "$task_status" = "started-work" ]; then
        if [ "$updates_count" -eq 0 ]; then
            warn "Task $task_id has no updates but status is started-work" \
                 "Started tasks should have at least 1 update entry" \
                 "Add update entry to $task_name"
            quality_issues=$((quality_issues + 1))
        fi
    fi

    # Quality Check 3: Tasks older than 7 days should have > 1 update
    created_date=$(grep "^created:" "$task_file" | head -1 | cut -d: -f2- | tr -d ' ' | cut -dT -f1)
    if [ -n "$created_date" ]; then
        created_ts=$(date -d "$created_date" +%s 2>/dev/null || date -j -f "%Y-%m-%d" "$created_date" +%s 2>/dev/null || echo 0)
        now_ts=$(date +%s)
        age_days=$(( (now_ts - created_ts) / 86400 ))
        if [ "$age_days" -gt 7 ] && [ "$task_status" != "work-completed" ]; then
            if [ "$updates_count" -lt 2 ]; then
                warn "Task $task_id is $age_days days old with only $updates_count updates" \
                     "Long-running tasks should show progress" \
                     "Add progress updates to $task_name"
                quality_issues=$((quality_issues + 1))
            fi
        fi
    fi
done
shopt -u nullglob

if [ "$quality_issues" -eq 0 ]; then
    pass "All active tasks meet quality thresholds"
fi

echo ""

# ============================================
# SECTION 3: GIT TRACEABILITY CHECKS
# ============================================
echo "=== GIT TRACEABILITY CHECKS ==="

if git -C "$PROJECT_ROOT" rev-parse --git-dir > /dev/null 2>&1; then
    total_commits=$(git -C "$PROJECT_ROOT" log --oneline 2>/dev/null | wc -l | tr -d ' ')
    task_commits=$(git -C "$PROJECT_ROOT" log --oneline 2>/dev/null | grep -E "T-[0-9]+" | wc -l | tr -d ' ')

    if [ "$total_commits" -gt 0 ]; then
        pct=$((task_commits * 100 / total_commits))

        if [ "$pct" -ge 80 ]; then
            pass "Git traceability: $pct% ($task_commits/$total_commits commits reference tasks)"
        elif [ "$pct" -ge 50 ]; then
            warn "Git traceability below target: $pct%" \
                 "$task_commits of $total_commits commits reference tasks" \
                 "Reference tasks in commit messages: git commit -m 'T-XXX: description'"
        else
            fail "Git traceability low: $pct%" \
                 "Only $task_commits of $total_commits commits reference tasks" \
                 "Enforce task references in commits"
        fi
    fi

    # Check for uncommitted changes
    if [ -n "$(git -C "$PROJECT_ROOT" status --porcelain)" ]; then
        warn "Uncommitted changes present" \
             "Working directory has modifications" \
             "Commit changes with task reference or stash"
    else
        pass "Working directory clean"
    fi

    # Quality Check: Verify task refs in commits exist as actual tasks
    orphan_refs=0
    while IFS= read -r commit_line; do
        task_ref=$(echo "$commit_line" | grep -oE "T-[0-9]+" | head -1)
        if [ -n "$task_ref" ]; then
            # Check if task file exists (active or completed)
            task_file=$(find "$TASKS_DIR" -name "${task_ref}-*.md" -type f 2>/dev/null | head -1)
            if [ -z "$task_file" ]; then
                if [ "$orphan_refs" -eq 0 ]; then
                    echo ""
                fi
                commit_sha=$(echo "$commit_line" | cut -d' ' -f1)
                warn "Commit $commit_sha references non-existent task $task_ref" \
                     "Task file for $task_ref not found in .tasks/" \
                     "Create task or fix commit reference"
                orphan_refs=$((orphan_refs + 1))
            fi
        fi
    done < <(git -C "$PROJECT_ROOT" log --oneline 2>/dev/null)

    if [ "$orphan_refs" -eq 0 ] && [ "$task_commits" -gt 0 ]; then
        pass "All commit task refs resolve to actual tasks"
    fi
else
    warn "Not a git repository" \
         "Git not initialized" \
         "Run: git init"
fi

echo ""

# ============================================
# SECTION 4: ENFORCEMENT CHECKS
# ============================================
echo "=== ENFORCEMENT CHECKS ==="

# Check for bypass log
if [ -f "$CONTEXT_DIR/bypass-log.yaml" ]; then
    pass "Bypass log exists"
else
    # Only warn if there are commits without task refs (potential bypasses)
    if [ "$total_commits" -gt "$task_commits" ] 2>/dev/null; then
        warn "No bypass log found" \
             "Commits exist without task refs but no bypass log" \
             "Create .context/bypass-log.yaml to document exceptions"
    fi
fi

# Check for commit-msg hook (validates task references)
if [ -f "$PROJECT_ROOT/.git/hooks/commit-msg" ]; then
    pass "Commit-msg hook installed"
else
    warn "No commit-msg hook" \
         ".git/hooks/commit-msg not found" \
         "Install hooks: ./agents/git/git.sh install-hooks"
fi

echo ""

# ============================================
# SECTION 5: LEARNING CAPTURE CHECKS
# ============================================
echo "=== LEARNING CAPTURE CHECKS ==="

# Check practices file
if [ -f "$PROJECT_ROOT/015-Practices.md" ]; then
    practice_count=$(grep -c "^## P-[0-9]" "$PROJECT_ROOT/015-Practices.md" 2>/dev/null || echo 0)
    if [ "$practice_count" -gt 0 ]; then
        pass "Practices documented: $practice_count practice(s)"

        # Check if practices have origins
        practices_with_origin=$(grep -c "Origin:" "$PROJECT_ROOT/015-Practices.md" 2>/dev/null || echo 0)
        if [ "$practices_with_origin" -ge "$practice_count" ]; then
            pass "All practices have traceable origins"

            # Quality Check: Verify practice origins reference existing tasks
            orphan_origins=0
            while IFS= read -r origin_line; do
                task_ref=$(echo "$origin_line" | grep -oE "T-[0-9]+" | head -1)
                if [ -n "$task_ref" ]; then
                    task_file=$(find "$TASKS_DIR" -name "${task_ref}-*.md" -type f 2>/dev/null | head -1)
                    if [ -z "$task_file" ]; then
                        practice_id=$(echo "$origin_line" | grep -oE "P-[0-9]+" | head -1)
                        warn "Practice ${practice_id:-unknown} references non-existent task $task_ref" \
                             "Origin task $task_ref not found in .tasks/" \
                             "Fix origin reference in 015-Practices.md"
                        orphan_origins=$((orphan_origins + 1))
                    fi
                fi
            done < <(grep "Origin:" "$PROJECT_ROOT/015-Practices.md" 2>/dev/null)

            if [ "$orphan_origins" -eq 0 ]; then
                pass "All practice origins resolve to actual tasks"
            fi
        else
            warn "Some practices missing origin" \
                 "$practices_with_origin of $practice_count have Origin: field" \
                 "Add 'Origin: T-XXX' to each practice"
        fi
    else
        warn "No practices captured yet" \
             "015-Practices.md exists but no P-XXX entries" \
             "Extract learnings from completed tasks into practices"
    fi
else
    warn "Practices file missing" \
         "015-Practices.md not found" \
         "Create practices file to capture learnings"
fi

echo ""

# ============================================
# SUMMARY
# ============================================
echo "=== SUMMARY ==="
echo -e "${GREEN}Pass:${NC} $PASS_COUNT"
echo -e "${YELLOW}Warn:${NC} $WARN_COUNT"
echo -e "${RED}Fail:${NC} $FAIL_COUNT"
echo ""

# Deduplicate and show priority actions
if [ ${#PRIORITY_ACTIONS[@]} -gt 0 ]; then
    echo "=== PRIORITY ACTIONS ==="
    printf '%s\n' "${PRIORITY_ACTIONS[@]}" | sort -u | head -5 | nl
fi

echo ""
echo "=== END AUDIT ==="

# Exit code based on findings
if [ $FAIL_COUNT -gt 0 ]; then
    exit 2
elif [ $WARN_COUNT -gt 0 ]; then
    exit 1
else
    exit 0
fi
