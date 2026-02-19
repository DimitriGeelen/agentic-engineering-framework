#!/bin/bash
# Audit Agent - Mechanical Compliance Checks
# Evaluates framework compliance against specifications
#
# Usage:
#   audit.sh                              # Full audit with terminal output
#   audit.sh --section structure,quality   # Run only specified sections
#   audit.sh --output /path/to/dir        # Write YAML report to custom dir
#   audit.sh --quiet                      # Suppress terminal output (cron-friendly)
#   audit.sh --cron                       # Shorthand for --output .context/audits/cron --quiet
#   audit.sh schedule install|remove|status  # Manage cron schedule
#
# Sections: structure, compliance, quality, traceability, enforcement,
#           learning, episodic, observations, gaps, handover, graduation,
#           research, oe-research

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FRAMEWORK_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PROJECT_ROOT="${PROJECT_ROOT:-$FRAMEWORK_ROOT}"
TASKS_DIR="$PROJECT_ROOT/.tasks"
CONTEXT_DIR="$PROJECT_ROOT/.context"
AUDITS_DIR="$CONTEXT_DIR/audits"

# --- Schedule Subcommand (dispatch before heavy init) ---
if [ "${1:-}" = "schedule" ]; then
    shift
    CRON_FILE="/etc/cron.d/agentic-audit"
    FW_PATH="$(readlink -f "$FRAMEWORK_ROOT/bin/fw" 2>/dev/null || echo "$FRAMEWORK_ROOT/bin/fw")"

    case "${1:-status}" in
        install)
            if ! command -v crontab >/dev/null 2>&1 && [ ! -d /etc/cron.d ]; then
                echo "ERROR: cron not available on this system" >&2
                exit 1
            fi
            mkdir -p "$CONTEXT_DIR/audits/cron"
            cat > "$CRON_FILE" << CRONEOF
# Agentic Engineering Framework — Scheduled Audits (T-184)
# Installed by: fw audit schedule install
# Manages: periodic quality checks independent of agent sessions
SHELL=/bin/bash
PATH=/usr/local/bin:/usr/bin:/bin

# Task quality + structure integrity + research OE (every 30 min)
*/30 * * * * root PROJECT_ROOT="$PROJECT_ROOT" "$FW_PATH" audit --section structure,compliance,quality,oe-research --cron 2>/dev/null

# Git traceability + episodic completeness (hourly)
0 * * * * root PROJECT_ROOT="$PROJECT_ROOT" "$FW_PATH" audit --section traceability,episodic --cron 2>/dev/null

# Observations + gaps (every 6 hours)
0 */6 * * * root PROJECT_ROOT="$PROJECT_ROOT" "$FW_PATH" audit --section observations,gaps --cron 2>/dev/null

# Full audit (daily at 8am)
0 8 * * * root PROJECT_ROOT="$PROJECT_ROOT" "$FW_PATH" audit --cron 2>/dev/null

# Retention: prune cron audit files older than 7 days (daily at 9am)
0 9 * * * root find "$CONTEXT_DIR/audits/cron" -name "*.yaml" -mtime +7 -delete 2>/dev/null
CRONEOF
            chmod 644 "$CRON_FILE"
            echo "Cron schedule installed: $CRON_FILE"
            echo ""
            echo "Schedule:"
            echo "  Every 30min: structure, compliance, quality, oe-research"
            echo "  Hourly:      traceability, episodic"
            echo "  Every 6h:    observations, gaps"
            echo "  Daily 8am:   full audit"
            echo "  Daily 9am:   retention cleanup (>7 days)"
            echo ""
            echo "Reports: $CONTEXT_DIR/audits/cron/"
            ;;
        remove)
            if [ -f "$CRON_FILE" ]; then
                rm -f "$CRON_FILE"
                echo "Cron schedule removed: $CRON_FILE"
            else
                echo "No cron schedule installed."
            fi
            ;;
        status)
            if [ -f "$CRON_FILE" ]; then
                echo "Cron schedule: INSTALLED ($CRON_FILE)"
                echo ""
                grep -v "^#" "$CRON_FILE" | grep -v "^$" | grep -v "^SHELL\|^PATH" | while read -r line; do
                    echo "  $line"
                done
                echo ""
                # Show latest cron audit
                local_latest=$(ls -t "$CONTEXT_DIR/audits/cron/"*.yaml 2>/dev/null | head -1)
                if [ -n "$local_latest" ]; then
                    echo "Latest cron audit: $(basename "$local_latest")"
                    grep -E "^  (pass|warn|fail):" "$local_latest" 2>/dev/null | sed 's/^/  /'
                else
                    echo "No cron audit reports yet."
                fi
            else
                echo "Cron schedule: NOT INSTALLED"
                echo ""
                echo "Install with: fw audit schedule install"
            fi
            ;;
        *)
            echo "Usage: fw audit schedule {install|remove|status}"
            exit 1
            ;;
    esac
    exit 0
fi

# --- Argument Parsing ---
SECTIONS=""       # Comma-separated section names (empty = all)
OUTPUT_DIR=""     # Custom output directory (empty = default AUDITS_DIR)
QUIET=false       # Suppress terminal output

while [[ $# -gt 0 ]]; do
    case $1 in
        --section|--sections) SECTIONS="$2"; shift 2 ;;
        --output) OUTPUT_DIR="$2"; shift 2 ;;
        --quiet) QUIET=true; shift ;;
        --cron) OUTPUT_DIR="$CONTEXT_DIR/audits/cron"; QUIET=true; shift ;;
        -h|--help)
            echo "Usage: audit.sh [options]"
            echo ""
            echo "Options:"
            echo "  --section NAMES   Comma-separated sections to run (default: all)"
            echo "  --output DIR      Write YAML report to custom directory"
            echo "  --quiet           Suppress terminal output (for cron)"
            echo "  --cron            Shorthand for --output .context/audits/cron --quiet"
            echo ""
            echo "Sections: structure, compliance, quality, traceability, enforcement,"
            echo "          learning, episodic, observations, gaps, handover, graduation"
            echo ""
            echo "Subcommands:"
            echo "  schedule install  Install cron entries for periodic audits"
            echo "  schedule remove   Remove cron entries"
            echo "  schedule status   Show current schedule and latest results"
            exit 0
            ;;
        *) shift ;;
    esac
done

# Section filter: returns 0 (true) if section should run
should_run_section() {
    [ -z "$SECTIONS" ] && return 0
    echo ",$SECTIONS," | grep -q ",$1,"
}

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Counters
PASS_COUNT=0
WARN_COUNT=0
FAIL_COUNT=0

# Priority actions
declare -a PRIORITY_ACTIONS

# Findings for history (format: "LEVEL|CHECK|MESSAGE")
declare -a FINDINGS

# Timestamp for this audit
AUDIT_TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
AUDIT_DATE=$(date +"%Y-%m-%d")
AUDIT_DATETIME=$(date +"%Y-%m-%d-%H%M")

# Logging functions
pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    PASS_COUNT=$((PASS_COUNT + 1))
    FINDINGS+=("PASS|$1|")
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
    echo "       Evidence: $2"
    echo "       Mitigation: $3"
    WARN_COUNT=$((WARN_COUNT + 1))
    PRIORITY_ACTIONS+=("$3")
    FINDINGS+=("WARN|$1|$3")
}

fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    echo "       Evidence: $2"
    echo "       Mitigation: $3"
    FAIL_COUNT=$((FAIL_COUNT + 1))
    PRIORITY_ACTIONS+=("$3")
    FINDINGS+=("FAIL|$1|$3")
}

# Quiet mode: suppress terminal output (findings still collected for YAML)
if [ "$QUIET" = true ]; then
    exec 3>&1 1>/dev/null
fi

# Header
echo "=== AUDIT REPORT ==="
echo "Timestamp: $(date -Iseconds)"
echo "Project: $PROJECT_ROOT"
[ -n "$SECTIONS" ] && echo "Sections: $SECTIONS"
echo ""

# ============================================
# SECTION 1: STRUCTURE CHECKS
# ============================================
if should_run_section "structure"; then
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
fi # end structure

# ============================================
# SECTION 2: TASK COMPLIANCE CHECKS
# ============================================
if should_run_section "compliance"; then
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
    valid_types="specification design build test refactor decommission inception"
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
fi # end compliance

# ============================================
# SECTION 2B: TASK QUALITY CHECKS (P-001, P-004)
# ============================================
if should_run_section "quality"; then
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
        created_ts=$(date -d "$created_date" +%s 2>/dev/null || date -j -f "%Y-%m-%d" "$created_date" +%s 2>/dev/null || true)
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

    # Quality Check 4: Acceptance Criteria section exists with at least one checkbox
    # Skip for captured tasks (not yet fleshed out) and inception tasks (use Go/No-Go instead)
    task_workflow=$(grep "^workflow_type:" "$task_file" | head -1 | cut -d: -f2 | tr -d ' ')
    if [ "$task_status" != "captured" ] && [ "$task_workflow" != "inception" ]; then
        ac_checkboxes=$(grep -c '\- \[[ x]\]' "$task_file" 2>/dev/null || true)
        ac_checkboxes=$(echo "$ac_checkboxes" | tr -d '[:space:]')
        if [ "$ac_checkboxes" -eq 0 ]; then
            warn "Task $task_id has no acceptance criteria checkboxes" \
                 "Tasks in progress need measurable completion criteria" \
                 "Add '## Acceptance Criteria' with checkboxes to $task_name"
            quality_issues=$((quality_issues + 1))
        fi
    fi

    # Quality Check 5: Verification section exists for started-work+ tasks
    if [ "$task_status" = "started-work" ] || [ "$task_status" = "issues" ]; then
        has_verification=$(grep -c '^## Verification' "$task_file" 2>/dev/null || true)
        has_verification=$(echo "$has_verification" | tr -d '[:space:]')
        if [ "$has_verification" -eq 0 ]; then
            warn "Task $task_id has no ## Verification section" \
                 "Verification commands enable the structural gate (P-011)" \
                 "Add '## Verification' with shell commands to $task_name"
            quality_issues=$((quality_issues + 1))
        fi
    fi

    # Quality Check 6: Context section is not a template placeholder
    if [ "$task_status" != "captured" ]; then
        has_placeholder=$(grep -c '\[Link to design docs' "$task_file" 2>/dev/null || true)
        has_placeholder=$(echo "$has_placeholder" | tr -d '[:space:]')
        if [ "$has_placeholder" -gt 0 ]; then
            warn "Task $task_id has unfilled placeholder in Context section" \
                 "Context should describe the task's background, not contain template text" \
                 "Replace placeholder in $task_name with actual context"
            quality_issues=$((quality_issues + 1))
        fi
    fi
done
shopt -u nullglob

if [ "$quality_issues" -eq 0 ]; then
    pass "All active tasks meet quality thresholds"
fi

echo ""
fi # end quality

# ============================================
# SECTION 3: GIT TRACEABILITY CHECKS
# ============================================
if should_run_section "traceability"; then
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
fi # end traceability

# ============================================
# SECTION 4: ENFORCEMENT CHECKS
# ============================================
if should_run_section "enforcement"; then
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

# Tier 0 Checking: Consequential actions must ALWAYS have task refs
# Patterns from 011-EnforcementConfig.md
TIER0_PATTERNS="deploy-to-production|delete-|destroy-|modify-firewall|modify-secrets|database-migrate"

tier0_violations=0

# Check git history for Tier 0 patterns without task refs
if git -C "$PROJECT_ROOT" rev-parse --git-dir > /dev/null 2>&1; then
    while IFS= read -r commit_line; do
        commit_sha=$(echo "$commit_line" | cut -d' ' -f1)
        commit_msg=$(echo "$commit_line" | cut -d' ' -f2-)

        # Check if commit message contains Tier 0 patterns
        if echo "$commit_msg" | grep -qiE "$TIER0_PATTERNS"; then
            # Check if commit has task reference
            if ! echo "$commit_msg" | grep -qE "T-[0-9]+"; then
                fail "Tier 0 action without task ref: $commit_sha" \
                     "Commit '$commit_msg' contains consequential action pattern" \
                     "Tier 0 actions MUST have task refs - document in bypass-log with explanation"
                tier0_violations=$((tier0_violations + 1))
            fi
        fi
    done < <(git -C "$PROJECT_ROOT" log --oneline 2>/dev/null)
fi

# Check bypass log for any Tier 0 patterns (these should never be bypassed)
if [ -f "$CONTEXT_DIR/bypass-log.yaml" ]; then
    while IFS= read -r bypass_action; do
        if echo "$bypass_action" | grep -qiE "$TIER0_PATTERNS"; then
            action_text=$(echo "$bypass_action" | sed 's/.*action: "//' | sed 's/".*//')
            fail "Tier 0 action in bypass log" \
                 "Bypass log contains: $action_text" \
                 "Tier 0 actions should NEVER be bypassed - review and remediate"
            tier0_violations=$((tier0_violations + 1))
        fi
    done < <(grep "action:" "$CONTEXT_DIR/bypass-log.yaml" 2>/dev/null)
fi

if [ "$tier0_violations" -eq 0 ]; then
    pass "No Tier 0 violations detected"
fi

echo ""
fi # end enforcement

# ============================================
# SECTION 5: LEARNING CAPTURE CHECKS
# ============================================
if should_run_section "learning"; then
echo "=== LEARNING CAPTURE CHECKS ==="

# Check practices file (supports both 015-Practices.md and practices.yaml)
PRACTICES_MD="$PROJECT_ROOT/015-Practices.md"
PRACTICES_YAML="$PROJECT_ROOT/.context/project/practices.yaml"

if [ -f "$PRACTICES_MD" ]; then
    practice_count=$(grep -c "^## P-[0-9]" "$PRACTICES_MD" 2>/dev/null || true)
    if [ "$practice_count" -gt 0 ]; then
        pass "Practices documented: $practice_count practice(s) in 015-Practices.md"

        # Check if practices have origins
        practices_with_origin=$(grep -c "Origin:" "$PRACTICES_MD" 2>/dev/null || true)
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
            done < <(grep "Origin:" "$PRACTICES_MD" 2>/dev/null)

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
elif [ -f "$PRACTICES_YAML" ]; then
    practice_count=$(python3 -c "
import yaml
with open('$PRACTICES_YAML') as f:
    data = yaml.safe_load(f) or {}
print(len(data.get('practices', [])))
" 2>/dev/null || true)
    if [ "$practice_count" -gt 0 ]; then
        pass "Practices documented: $practice_count practice(s) in practices.yaml"
    else
        pass "Practices file exists (practices.yaml, no entries yet)"
    fi
else
    warn "Practices file missing" \
         "No 015-Practices.md or .context/project/practices.yaml found" \
         "Run: fw init --force (or create practices file manually)"
fi

echo ""
fi # end learning

# ============================================
# SECTION 6: EPISODIC MEMORY CHECKS
# ============================================
if should_run_section "episodic"; then
echo "=== EPISODIC MEMORY CHECKS ==="

episodic_dir="$CONTEXT_DIR/episodic"

# Check 1: Every completed task should have an episodic summary
missing_episodic=0
if [ -d "$TASKS_DIR/completed" ]; then
    shopt -s nullglob
    for task_file in "$TASKS_DIR/completed"/*.md; do
        [ -f "$task_file" ] || continue
        task_id=$(grep "^id:" "$task_file" | head -1 | sed 's/id: //' | tr -d ' ')
        [ -z "$task_id" ] && continue

        episodic_file="$episodic_dir/${task_id}.yaml"
        if [ ! -f "$episodic_file" ]; then
            warn "Completed task $task_id has no episodic summary" \
                 "$episodic_file not found" \
                 "Run: ./agents/context/context.sh generate-episodic $task_id"
            missing_episodic=$((missing_episodic + 1))
        fi
    done
    shopt -u nullglob
fi

if [ "$missing_episodic" -eq 0 ]; then
    pass "All completed tasks have episodic summaries"
fi

# Check 2: Episodic quality (non-empty required fields, enrichment status)
low_quality_episodic=0
pending_enrichment=0

if [ -d "$episodic_dir" ]; then
    shopt -s nullglob
    for episodic_file in "$episodic_dir"/*.yaml; do
        [ -f "$episodic_file" ] || continue
        filename=$(basename "$episodic_file")
        # Skip template
        [ "$filename" = "TEMPLATE.yaml" ] && continue

        task_id=$(basename "$episodic_file" .yaml)

        # Check enrichment status
        enrichment_status=$(grep "^enrichment_status:" "$episodic_file" 2>/dev/null | sed 's/enrichment_status: //' | tr -d ' ')
        if [ "$enrichment_status" = "pending" ]; then
            pending_enrichment=$((pending_enrichment + 1))
        fi

        # Check summary is not empty/TODO placeholder
        # Only flag if the first content line starts with [TODO (actual unfilled placeholder)
        summary_first_line=$(sed -n '/^summary:/,/^[a-z_]*:/p' "$episodic_file" 2>/dev/null | grep -v "^summary:" | grep -v "^\s*#" | grep -v "^\s*$" | head -1 | sed 's/^[[:space:]]*//')
        if [ -z "$summary_first_line" ] || echo "$summary_first_line" | grep -q "^\[TODO"; then
            low_quality_episodic=$((low_quality_episodic + 1))
        fi
    done
    shopt -u nullglob
fi

if [ "$pending_enrichment" -gt 0 ]; then
    warn "$pending_enrichment episodic summaries pending enrichment" \
         "Files with enrichment_status: pending" \
         "Enrich episodics with actual content, then set enrichment_status: complete"
fi

if [ "$low_quality_episodic" -gt 0 ] && [ "$pending_enrichment" -eq 0 ]; then
    warn "$low_quality_episodic episodics have empty or TODO summaries" \
         "Summary field is empty or contains [TODO]" \
         "Fill in summary field with actual task description"
fi

if [ "$pending_enrichment" -eq 0 ] && [ "$low_quality_episodic" -eq 0 ]; then
    episodic_count=$(find "$episodic_dir" -name "T-*.yaml" -type f 2>/dev/null | wc -l)
    if [ "$episodic_count" -gt 0 ]; then
        pass "All $episodic_count episodic summaries have quality content"
    fi
fi

# Check 3: Orphaned episodic files (no matching task)
orphaned_episodic=0
if [ -d "$episodic_dir" ]; then
    shopt -s nullglob
    for episodic_file in "$episodic_dir"/T-*.yaml; do
        [ -f "$episodic_file" ] || continue
        task_id=$(basename "$episodic_file" .yaml)
        task_file=$(find "$TASKS_DIR" -name "${task_id}-*.md" -type f 2>/dev/null | head -1)
        if [ -z "$task_file" ]; then
            warn "Orphaned episodic: $task_id has no matching task file" \
                 "$episodic_file has no corresponding task" \
                 "Remove orphaned episodic or create matching task"
            orphaned_episodic=$((orphaned_episodic + 1))
        fi
    done
    shopt -u nullglob
fi

if [ "$orphaned_episodic" -eq 0 ] && [ -d "$episodic_dir" ]; then
    pass "No orphaned episodic files"
fi

echo ""
fi # end episodic

# ============================================
# SECTION 7: OBSERVATION INBOX CHECKS
# ============================================
if should_run_section "observations"; then
echo "=== OBSERVATION INBOX CHECKS ==="

INBOX_FILE="$CONTEXT_DIR/inbox.yaml"

if [ -f "$INBOX_FILE" ]; then
    pending_obs=$(grep -c 'status: pending' "$INBOX_FILE" 2>/dev/null) || pending_obs=0
    urgent_obs=0
    stale_obs=0

    if [ "$pending_obs" -gt 0 ]; then
        # Check for urgent pending observations
        # Count blocks that have both status: pending and urgent: true
        urgent_obs=$(python3 -c "
import re
with open('$INBOX_FILE') as f:
    content = f.read()
blocks = re.split(r'\n  - ', content)
urgent = sum(1 for b in blocks[1:] if 'status: pending' in b and 'urgent: true' in b)
print(urgent)
" 2>/dev/null || true)

        # Check for stale observations (>7 days old)
        stale_obs=$(python3 -c "
import re
from datetime import datetime, timedelta
with open('$INBOX_FILE') as f:
    content = f.read()
blocks = re.split(r'\n  - ', content)
cutoff = datetime.utcnow() - timedelta(days=7)
stale = 0
for b in blocks[1:]:
    if 'status: pending' not in b:
        continue
    m = re.search(r'captured: (\S+)', b)
    if m:
        try:
            ts = datetime.fromisoformat(m.group(1).replace('Z', '+00:00')).replace(tzinfo=None)
            if ts < cutoff:
                stale += 1
        except:
            pass
print(stale)
" 2>/dev/null || true)

        if [ "$urgent_obs" -gt 0 ]; then
            warn "$urgent_obs urgent observation(s) still pending" \
                 "Urgent items in .context/inbox.yaml need attention" \
                 "Run: fw note triage"
        fi

        if [ "$stale_obs" -gt 0 ]; then
            warn "$stale_obs observation(s) pending for >7 days" \
                 "Stale observations in .context/inbox.yaml" \
                 "Run: fw note triage — promote or dismiss stale items"
        fi

        if [ "$urgent_obs" -eq 0 ] && [ "$stale_obs" -eq 0 ]; then
            pass "Observation inbox: $pending_obs pending (none stale or urgent)"
        fi
    else
        pass "Observation inbox clean (0 pending)"
    fi
else
    pass "No observation inbox (not yet initialized)"
fi

echo ""
fi # end observations

# ============================================
# SECTION 8: GAPS REGISTER CHECKS
# ============================================
if should_run_section "gaps"; then
echo "=== GAPS REGISTER CHECKS ==="

GAPS_FILE="$CONTEXT_DIR/project/gaps.yaml"

if [ -f "$GAPS_FILE" ]; then
    watching_count=$(grep -c 'status: watching' "$GAPS_FILE" 2>/dev/null) || watching_count=0
    triggered_gaps=0

    if [ "$watching_count" -gt 0 ]; then
        # Run auto-checkable triggers
        triggered_gaps=$(python3 << PYEOF
import yaml, subprocess, os

project_root = os.environ.get('PROJECT_ROOT', '$PROJECT_ROOT')

with open('$GAPS_FILE') as f:
    data = yaml.safe_load(f)

triggered = 0
for gap in data.get('gaps', []):
    if gap.get('status') != 'watching':
        continue
    tc = gap.get('trigger_check', {})
    if tc.get('type') != 'auto':
        continue

    check_cmd = tc.get('check', '')
    threshold = tc.get('threshold', '')
    if not check_cmd:
        continue

    # Substitute variables
    check_cmd = check_cmd.replace('$' + 'PROJECT_ROOT', project_root)

    try:
        result = subprocess.run(check_cmd, shell=True, capture_output=True, text=True, timeout=5)
        value = int(result.stdout.strip())

        # Parse threshold
        if threshold.startswith('>= '):
            target = int(threshold.split('>= ')[1].split()[0])
            if value >= target:
                print(f"  TRIGGERED: {gap['id']} — {gap['title']}")
                print(f"    Value: {value}, Threshold: {threshold}")
                print(f"    Action: Review gap and decide — build or simplify")
                triggered += 1
        elif threshold.startswith('> '):
            target = int(threshold.split('> ')[1].split()[0])
            if value > target:
                print(f"  TRIGGERED: {gap['id']} — {gap['title']}")
                print(f"    Value: {value}, Threshold: {threshold}")
                print(f"    Action: Review gap and decide — build or simplify")
                triggered += 1
    except:
        pass

print(triggered)
PYEOF
)
        # Extract just the count (last line)
        trigger_count=$(echo "$triggered_gaps" | tail -1)
        trigger_output=$(echo "$triggered_gaps" | head -n -1)

        if [ -n "$trigger_output" ]; then
            echo "$trigger_output"
            warn "Gap trigger(s) fired — review gaps register" \
                 "Auto-check found trigger conditions met" \
                 "Review .context/project/gaps.yaml and decide: build or simplify"
        fi

        if [ "${trigger_count:-0}" -eq 0 ]; then
            pass "Gaps register: $watching_count watching, no triggers fired"
        fi
    else
        pass "Gaps register: no gaps being watched"
    fi
else
    echo -e "  ${CYAN}SKIP${NC}  No gaps register (.context/project/gaps.yaml)"
fi

echo ""
fi # end gaps

# ============================================
# SECTION 8b: HANDOVER OPEN QUESTIONS (G-002)
# ============================================
if should_run_section "handover"; then
echo "=== HANDOVER OPEN QUESTIONS CHECK ==="

HANDOVER_FILE="$CONTEXT_DIR/handovers/LATEST.md"

if [ -f "$HANDOVER_FILE" ]; then
    # Extract open questions section (between ## Open Questions and next ##)
    open_questions=$(sed -n '/^## Open Questions/,/^## /p' "$HANDOVER_FILE" | grep -v "^## " | grep -v "^\[TODO" | grep -v "^$" | grep -v "^1\. \[Question")

    if [ -n "$open_questions" ]; then
        # Count real items (numbered lines or bullet points with content)
        oq_count=$(echo "$open_questions" | grep -cE "^[0-9]+\.|^- " 2>/dev/null) || oq_count=0

        if [ "$oq_count" -gt 0 ]; then
            # Check how many are tracked in gaps.yaml or tasks
            untracked=0
            while IFS= read -r line; do
                # Extract the question text (strip numbering/bullets)
                question=$(echo "$line" | sed 's/^[0-9]*\.\s*//; s/^- //')
                [ -z "$question" ] && continue

                # Check if any keyword from the question appears in gaps or active tasks
                tracked=false
                for keyword in $(echo "$question" | tr ' ' '\n' | grep -E '^[A-Z]' | head -3); do
                    if grep -qi "$keyword" "$CONTEXT_DIR/project/gaps.yaml" 2>/dev/null; then
                        tracked=true
                        break
                    fi
                    if grep -rqi "$keyword" "$TASKS_DIR/active/" 2>/dev/null; then
                        tracked=true
                        break
                    fi
                done

                if [ "$tracked" = false ]; then
                    untracked=$((untracked + 1))
                fi
            done <<< "$(echo "$open_questions" | grep -E "^[0-9]+\.|^- ")"

            if [ "$untracked" -gt 0 ]; then
                warn "Handover has $untracked open question(s) with no matching gap or task" \
                     "$untracked of $oq_count open questions in LATEST.md appear untracked" \
                     "Register via 'fw gaps add' or 'fw task create' — see LATEST.md Open Questions section"
            else
                pass "Handover open questions: $oq_count tracked in gaps/tasks"
            fi
        else
            pass "Handover open questions: none (section empty or template placeholder)"
        fi
    else
        pass "Handover open questions: none"
    fi
else
    echo -e "  ${CYAN}SKIP${NC}  No handover file found"
fi

echo ""
fi # end handover

# ============================================
# SECTION 9: GRADUATION PIPELINE CHECK
# ============================================
if should_run_section "graduation"; then
echo "=== GRADUATION PIPELINE CHECKS ==="

LEARNINGS_FILE="$CONTEXT_DIR/project/learnings.yaml"
if [ -f "$LEARNINGS_FILE" ]; then
    learning_count=$(grep -c '^  - id: L-' "$LEARNINGS_FILE" 2>/dev/null) || learning_count=0

    if [ "$learning_count" -ge 20 ]; then
        # Check for promotion candidates using fw promote
        promote_output=$(PROJECT_ROOT="$PROJECT_ROOT" "$FRAMEWORK_ROOT/bin/fw" promote suggest 2>/dev/null) || true
        ready_count=$(echo "$promote_output" | grep -c "ready for promotion" 2>/dev/null) || ready_count=0
        almost_count=$(echo "$promote_output" | grep -c "^  " 2>/dev/null) || almost_count=0

        if echo "$promote_output" | grep -q "No learnings currently meet"; then
            pass "Graduation pipeline: $learning_count learnings, no promotions ready yet"
        else
            warn "Learnings ready for promotion — review graduation candidates" \
                 "$learning_count learnings, promotion candidates available" \
                 "Run: fw promote suggest"
        fi
    else
        pass "Graduation pipeline: $learning_count learnings (threshold: 20)"
    fi
else
    echo -e "  ${CYAN}SKIP${NC}  No learnings file"
fi

echo ""
fi # end graduation

# ============================================
# SECTION 10: INCEPTION RESEARCH ARTIFACT CHECK (T-178/T-185)
# ============================================
if should_run_section "research"; then
echo "=== INCEPTION RESEARCH CHECKS ==="

# Check completed inception tasks for research artifacts in docs/reports/
missing_research=0
if [ -d "$TASKS_DIR/completed" ] && [ -d "$PROJECT_ROOT/docs/reports" ]; then
    shopt -s nullglob
    for task_file in "$TASKS_DIR/completed"/*.md; do
        [ -f "$task_file" ] || continue
        task_workflow=$(grep "^workflow_type:" "$task_file" | head -1 | cut -d: -f2 | tr -d ' ')
        [ "$task_workflow" != "inception" ] && continue

        task_id=$(grep "^id:" "$task_file" | head -1 | sed 's/id: //' | tr -d ' ')
        [ -z "$task_id" ] && continue

        # Check if any docs/reports/ file references this task ID
        has_artifact=false
        for report in "$PROJECT_ROOT/docs/reports"/*.md; do
            if echo "$(basename "$report")" | grep -qi "$task_id"; then
                has_artifact=true
                break
            fi
        done

        # Also check if task body mentions docs/reports/
        if [ "$has_artifact" = false ]; then
            if grep -q "docs/reports/" "$task_file" 2>/dev/null; then
                has_artifact=true
            fi
        fi

        # Also check episodic for artifact references
        if [ "$has_artifact" = false ] && [ -f "$CONTEXT_DIR/episodic/${task_id}.yaml" ]; then
            if grep -q "docs/reports/" "$CONTEXT_DIR/episodic/${task_id}.yaml" 2>/dev/null; then
                has_artifact=true
            fi
        fi

        if [ "$has_artifact" = false ]; then
            warn "Inception task $task_id has no research artifact in docs/reports/" \
                 "Completed inception with no persisted research output" \
                 "Save research findings: docs/reports/${task_id}-*.md"
            missing_research=$((missing_research + 1))
        fi
    done
    shopt -u nullglob
fi

if [ "$missing_research" -eq 0 ]; then
    inception_count=$(grep -rl "^workflow_type: inception" "$TASKS_DIR/completed/" 2>/dev/null | wc -l | tr -d ' ')
    if [ "$inception_count" -gt 0 ]; then
        pass "All $inception_count completed inceptions have research artifacts"
    else
        pass "No completed inception tasks to check"
    fi
fi

echo ""
fi # end research

# ============================================
# SECTION 11: RESEARCH PERSISTENCE OE TESTS (C-001/C-002/C-003, T-194)
# ============================================
if should_run_section "oe-research"; then
echo "=== RESEARCH PERSISTENCE OE CHECKS ==="

# C-001 OE: Active inception tasks with started-work should have docs/reports/ artifact
c001_missing=0
shopt -s nullglob
for task_file in "$TASKS_DIR/active"/*.md; do
    [ -f "$task_file" ] || continue
    task_workflow=$(grep "^workflow_type:" "$task_file" | head -1 | cut -d: -f2 | tr -d ' ')
    [ "$task_workflow" != "inception" ] && continue
    task_status=$(grep "^status:" "$task_file" | head -1 | cut -d: -f2 | tr -d ' ')
    [ "$task_status" != "started-work" ] && continue
    task_id=$(grep "^id:" "$task_file" | head -1 | sed 's/id: //' | tr -d ' ')
    [ -z "$task_id" ] && continue

    artifact=$(find "$PROJECT_ROOT/docs/reports/" -name "${task_id}-*" -type f 2>/dev/null | head -1)
    if [ -z "$artifact" ]; then
        warn "C-001: Inception $task_id has no research artifact in docs/reports/" \
             "Active inception task without persisted research" \
             "Create docs/reports/${task_id}-*.md — the thinking trail IS the artifact"
        c001_missing=$((c001_missing + 1))
    else
        # Check artifact is referenced in task Updates section
        artifact_ref=$(grep -c 'docs/reports/' "$task_file" 2>/dev/null || true)
        artifact_ref=$(echo "$artifact_ref" | tr -d '[:space:]')
        if [ "$artifact_ref" -eq 0 ]; then
            warn "C-001: Inception $task_id has artifact but task doesn't reference it" \
                 "$(basename "$artifact") exists but not linked in task Updates" \
                 "Add artifact reference to ## Updates section of $task_id"
        fi
    fi
done
shopt -u nullglob

if [ "$c001_missing" -eq 0 ]; then
    inception_active=$(grep -rl "^workflow_type: inception" "$TASKS_DIR/active/" 2>/dev/null | while read f; do grep -l "^status: started-work" "$f" 2>/dev/null; done | wc -l | tr -d ' ')
    if [ "$inception_active" -gt 0 ]; then
        pass "C-001: All $inception_active active inceptions have research artifacts"
    else
        pass "C-001: No active inception tasks to check"
    fi
fi

# C-002 OE: Check commit-msg hook has research artifact check installed
if grep -q "inception-research-warnings" "$PROJECT_ROOT/.git/hooks/commit-msg" 2>/dev/null; then
    pass "C-002: commit-msg hook has research artifact check"
else
    warn "C-002: commit-msg hook missing research artifact check" \
         "Hook at .git/hooks/commit-msg doesn't contain C-002 gate" \
         "Reinstall hooks: fw git install-hooks (or manually add C-002)"
fi

# C-002 OE: Check warning log for recent inception commits without research
WARN_LOG="$CONTEXT_DIR/working/.inception-research-warnings"
if [ -f "$WARN_LOG" ]; then
    recent_warns=$(grep "$(date +%Y-%m-%d)" "$WARN_LOG" 2>/dev/null | wc -l | tr -d ' ')
    if [ "$recent_warns" -gt 0 ]; then
        warn "C-002: $recent_warns inception commit(s) today without docs/reports/ artifact" \
             "Warnings logged in .inception-research-warnings" \
             "Review commits and ensure research is persisted"
    else
        pass "C-002: No research warnings today"
    fi
else
    pass "C-002: No research warnings logged (clean or first run)"
fi

# C-003 OE: Check checkpoint hook is wired and firing
CHECKPOINT_LOG="$CONTEXT_DIR/working/.inception-checkpoint-log"
if grep -q "inception-research-counter\|INCEPTION_RESEARCH_INTERVAL\|C-003" "$PROJECT_ROOT/agents/context/checkpoint.sh" 2>/dev/null; then
    pass "C-003: Research checkpoint logic present in checkpoint.sh"
else
    warn "C-003: Research checkpoint logic missing from checkpoint.sh" \
         "checkpoint.sh doesn't contain C-003 inception research check" \
         "Add C-003 research checkpoint to checkpoint.sh post-tool handler"
fi

if [ -f "$CHECKPOINT_LOG" ]; then
    today_prompts=$(grep "$(date +%Y-%m-%d)" "$CHECKPOINT_LOG" 2>/dev/null | wc -l | tr -d ' ')
    echo "       C-003 checkpoint prompts today: $today_prompts"
fi

echo ""
fi # end oe-research

# ============================================
# SUMMARY (always runs)
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

# ============================================
# YAML OUTPUT (always runs)
# ============================================

# Determine output directory and filename
EFFECTIVE_OUTPUT_DIR="${OUTPUT_DIR:-$AUDITS_DIR}"
mkdir -p "$EFFECTIVE_OUTPUT_DIR"

# Cron audits use datetime filenames (multiple per day); manual audits use date
if [ -n "$OUTPUT_DIR" ]; then
    AUDIT_FILE="$EFFECTIVE_OUTPUT_DIR/$AUDIT_DATETIME.yaml"
else
    AUDIT_FILE="$EFFECTIVE_OUTPUT_DIR/$AUDIT_DATE.yaml"
fi

# Build YAML content
{
    echo "# Audit Results - $AUDIT_DATETIME"
    echo "timestamp: $AUDIT_TIMESTAMP"
    [ -n "$SECTIONS" ] && echo "sections: \"$SECTIONS\""
    echo "summary:"
    echo "  pass: $PASS_COUNT"
    echo "  warn: $WARN_COUNT"
    echo "  fail: $FAIL_COUNT"
    echo "findings:"
    for finding in "${FINDINGS[@]}"; do
        level=$(echo "$finding" | cut -d'|' -f1)
        check=$(echo "$finding" | cut -d'|' -f2)
        mitigation=$(echo "$finding" | cut -d'|' -f3)
        echo "  - level: $level"
        echo "    check: \"$check\""
        if [ -n "$mitigation" ]; then
            echo "    mitigation: \"$mitigation\""
        fi
    done
} > "$AUDIT_FILE"

# Update LATEST-CRON symlink (only in custom output dirs, not default audits)
if [ -n "$OUTPUT_DIR" ]; then
    ln -sf "$(basename "$AUDIT_FILE")" "$EFFECTIVE_OUTPUT_DIR/LATEST-CRON.yaml" 2>/dev/null || true
fi

# Trend detection: Compare with previous audits
echo ""
echo "=== TREND ANALYSIS ==="

# Get previous audit files (excluding today)
shopt -s nullglob
previous_audits=("$AUDITS_DIR"/*.yaml)
shopt -u nullglob

# Filter to only files before today
past_audits=()
for f in "${previous_audits[@]}"; do
    fname=$(basename "$f" .yaml)
    if [ "$fname" != "$AUDIT_DATE" ] && [ -f "$f" ]; then
        past_audits+=("$f")
    fi
done

if [ ${#past_audits[@]} -eq 0 ]; then
    echo "First audit recorded. Trends will appear after multiple audits."
else
    # Count how many times each warning/failure has appeared
    declare -A issue_counts

    for audit_file in "${past_audits[@]}"; do
        while IFS= read -r line; do
            if [[ "$line" =~ ^[[:space:]]+check:[[:space:]]* ]]; then
                check_name=$(echo "$line" | sed 's/.*check: "//' | sed 's/"$//')
                issue_counts["$check_name"]=$((${issue_counts["$check_name"]:-0} + 1))
            fi
        done < <(grep -A1 "level: WARN\|level: FAIL" "$audit_file" 2>/dev/null)
    done

    # Find repeated issues (appeared 3+ times)
    repeated_issues=()
    for check in "${!issue_counts[@]}"; do
        if [ "${issue_counts[$check]}" -ge 3 ]; then
            repeated_issues+=("$check (${issue_counts[$check]} times)")
        fi
    done

    if [ ${#repeated_issues[@]} -gt 0 ]; then
        echo -e "${YELLOW}Repeated issues detected (candidates for practice):${NC}"
        for issue in "${repeated_issues[@]}"; do
            echo "  - $issue"
        done
        echo ""
        echo -e "${CYAN}Consider creating a practice to address these recurring issues.${NC}"
        echo "Run: fw context add-learning \"description\" --task T-XXX"
    else
        echo -e "${GREEN}No repeated issues detected across ${#past_audits[@]} previous audit(s).${NC}"
    fi

    # Show trend summary
    echo ""
    echo "Audit history: ${#past_audits[@]} previous audit(s) + today"
fi

echo ""
echo "Audit saved to: $AUDIT_FILE"

# Retention: prune cron audit files older than 7 days
if [ -n "$OUTPUT_DIR" ] && [ -d "$OUTPUT_DIR" ]; then
    find "$OUTPUT_DIR" -name "*.yaml" -mtime +7 -delete 2>/dev/null || true
fi

echo ""
echo "=== END AUDIT ==="

# Restore stdout if quiet mode was active
if [ "$QUIET" = true ]; then
    exec 1>&3
fi

# Exit code based on findings
if [ $FAIL_COUNT -gt 0 ]; then
    exit 2
elif [ $WARN_COUNT -gt 0 ]; then
    exit 1
else
    exit 0
fi
