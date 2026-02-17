#!/bin/bash
# Audit Agent - Mechanical Compliance Checks
# Evaluates framework compliance against specifications

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FRAMEWORK_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PROJECT_ROOT="${PROJECT_ROOT:-$FRAMEWORK_ROOT}"
TASKS_DIR="$PROJECT_ROOT/.tasks"
CONTEXT_DIR="$PROJECT_ROOT/.context"
AUDITS_DIR="$CONTEXT_DIR/audits"

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

# ============================================
# SECTION 5: LEARNING CAPTURE CHECKS
# ============================================
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

# ============================================
# SECTION 6: EPISODIC MEMORY CHECKS
# ============================================
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

# ============================================
# SECTION 7: OBSERVATION INBOX CHECKS
# ============================================
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

# ============================================
# SECTION 8: GAPS REGISTER CHECKS
# ============================================
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

# ============================================
# SECTION 9: GRADUATION PIPELINE CHECK
# ============================================
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

# ============================================
# SECTION 6: ANTIFRAGILE LEARNING (D1)
# ============================================

# Ensure audits directory exists
mkdir -p "$AUDITS_DIR"

# Save this audit's results
AUDIT_FILE="$AUDITS_DIR/$AUDIT_DATE.yaml"

# Build YAML content
{
    echo "# Audit Results - $AUDIT_DATE"
    echo "timestamp: $AUDIT_TIMESTAMP"
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
