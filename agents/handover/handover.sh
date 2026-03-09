#!/bin/bash
# Handover Agent - Mechanical Operations
# Creates handover documents for session continuity

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FRAMEWORK_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# Resolve PROJECT_ROOT from git toplevel — framework/ is typically a subdirectory,
# not the project root. Fall back to FRAMEWORK_ROOT for standalone installs.
PROJECT_ROOT="${PROJECT_ROOT:-$(git -C "$FRAMEWORK_ROOT" rev-parse --show-toplevel 2>/dev/null || echo "$FRAMEWORK_ROOT")}"
TASKS_DIR="$PROJECT_ROOT/.tasks"
CONTEXT_DIR="$PROJECT_ROOT/.context"
HANDOVER_DIR="$CONTEXT_DIR/handovers"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

_resolve_commit_task() {
    # If task already set by --task flag, keep it
    if [ -n "$COMMIT_TASK" ]; then return; fi
    # Check if T-012 exists (framework's own handover task)
    if [ -n "$(ls "$TASKS_DIR/active/T-012-"*.md "$TASKS_DIR/completed/T-012-"*.md 2>/dev/null)" ]; then
        COMMIT_TASK="T-012"
        return
    fi
    # Look for any task with "handover" in its slug
    local handover_task
    handover_task=$(ls "$TASKS_DIR/active/"*handover*.md "$TASKS_DIR/completed/"*handover*.md 2>/dev/null | head -1)
    if [ -n "$handover_task" ]; then
        COMMIT_TASK=$(basename "$handover_task" | grep -oE "T-[0-9]+" | head -1)
        if [ -n "$COMMIT_TASK" ]; then return; fi
    fi
    # Auto-create a handover maintenance task for this project
    if [ -x "$FRAMEWORK_ROOT/agents/task-create/create-task.sh" ]; then
        local create_output
        create_output=$(PROJECT_ROOT="$PROJECT_ROOT" "$FRAMEWORK_ROOT/agents/task-create/create-task.sh" \
            --name "Session handover maintenance" --type build --owner agent \
            --description "Ongoing task for session handover commits" 2>&1)
        COMMIT_TASK=$(echo "$create_output" | grep "^ID:" | awk '{print $2}')
        if [ -n "$COMMIT_TASK" ]; then
            echo -e "${CYAN}Auto-created handover task: $COMMIT_TASK${NC}"
            return
        fi
    fi
    # Use focused task as last resort
    local focus_file="$CONTEXT_DIR/working/focus.yaml"
    if [ -f "$focus_file" ]; then
        local focused
        focused=$(grep '^task_id:' "$focus_file" 2>/dev/null | awk '{print $2}' | tr -d '"')
        if [ -n "$focused" ] && [ "$focused" != "null" ] && [ "$focused" != "none" ]; then
            COMMIT_TASK="$focused"
            return
        fi
    fi
    # Absolute fallback — use T-000 placeholder (will pass hook regex)
    COMMIT_TASK="T-000"
}

# Parse arguments
SESSION_ID=""
AUTO_COMMIT=true
COMMIT_TASK=""
CHECKPOINT_MODE=false
while [[ $# -gt 0 ]]; do
    case $1 in
        --session) SESSION_ID="$2"; shift 2 ;;
        --commit) AUTO_COMMIT=true; shift ;;
        --no-commit) AUTO_COMMIT=false; shift ;;
        --task|-t) COMMIT_TASK="$2"; shift 2 ;;
        --owner) AGENT_OWNER="$2"; shift 2 ;;
        --emergency) AUTO_COMMIT=true; shift ;;  # Deprecated (D-028): treated as normal handover
        --checkpoint) CHECKPOINT_MODE=true; AUTO_COMMIT=true; shift ;;
        -h|--help)
            echo "Usage: handover.sh [options]"
            echo ""
            echo "Options:"
            echo "  --session ID   Use specific session ID (default: auto-generated)"
            echo "  --commit       Auto-commit handover via git agent (default)"
            echo "  --no-commit    Skip auto-commit"
            echo "  --task, -t ID  Task ID for commit (default: T-012)"
            echo "  --owner NAME   Agent/provider name (default: \$AGENT_OWNER or claude-code)"
            echo "  --checkpoint   Mid-session checkpoint (does not replace LATEST.md)"
            echo "  -h, --help     Show this help"
            exit 0
            ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

# Generate session ID if not provided
if [ -z "$SESSION_ID" ]; then
    SESSION_ID="S-$(date +%Y-%m%d-%H%M)"
fi

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Ensure directories exist
mkdir -p "$HANDOVER_DIR"

# ─── Checkpoint Mode: lightweight mid-session snapshot ───
if [ "$CHECKPOINT_MODE" = true ]; then
    HANDOVER_FILE="$HANDOVER_DIR/CHECKPOINT-$SESSION_ID.md"
    echo -e "${CYAN}=== Checkpoint Handover ===${NC}"
    echo "Session: $SESSION_ID"

    ACTIVE_TASKS=""
    ACTIVE_DETAILS=""
    shopt -s nullglob
    for f in "$TASKS_DIR/active"/*.md; do
        [ -f "$f" ] || continue
        task_id=$(grep "^id:" "$f" | head -1 | cut -d: -f2 | tr -d ' ')
        task_name=$(grep "^name:" "$f" | head -1 | cut -d: -f2- | sed 's/^ *//')
        task_status=$(grep "^status:" "$f" | head -1 | cut -d: -f2 | tr -d ' ')
        [ -n "$task_id" ] && ACTIVE_TASKS="$ACTIVE_TASKS$task_id, "
        ACTIVE_DETAILS="$ACTIVE_DETAILS- **$task_id**: $task_name ($task_status)\n"
    done
    shopt -u nullglob
    ACTIVE_TASKS="${ACTIVE_TASKS%, }"

    UNCOMMITTED=$(git -C "$PROJECT_ROOT" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
    RECENT_COMMITS=$(git -C "$PROJECT_ROOT" log -5 --pretty=format:"- %h %s" 2>/dev/null)

    cat > "$HANDOVER_FILE" << CHECKPOINT_EOF
---
session_id: $SESSION_ID
timestamp: $TIMESTAMP
type: checkpoint
tasks_active: [$ACTIVE_TASKS]
uncommitted_changes: $UNCOMMITTED
owner: ${AGENT_OWNER:-claude-code}
---

# Checkpoint: $SESSION_ID

## Active Tasks

$(echo -e "$ACTIVE_DETAILS")

## Recent Commits

$RECENT_COMMITS
CHECKPOINT_EOF

    echo -e "${GREEN}Checkpoint created: $HANDOVER_FILE${NC}"
    # Note: checkpoints do NOT replace LATEST.md

    # Reset tool counter
    if [ -f "$FRAMEWORK_ROOT/agents/context/checkpoint.sh" ]; then
        "$FRAMEWORK_ROOT/agents/context/checkpoint.sh" reset 2>/dev/null || true
    fi

    # Auto-commit
    if [ "$AUTO_COMMIT" = true ]; then
        _resolve_commit_task
        GIT_AGENT=""
        if [ -f "$FRAMEWORK_ROOT/agents/git/git.sh" ]; then
            GIT_AGENT="$FRAMEWORK_ROOT/agents/git/git.sh"
        fi
        if [ -n "$GIT_AGENT" ]; then
            git -C "$PROJECT_ROOT" add "$HANDOVER_FILE"
            PROJECT_ROOT="$PROJECT_ROOT" "$GIT_AGENT" commit -m "$COMMIT_TASK: Checkpoint handover $SESSION_ID"
        fi
    fi
    exit 0
fi

# ─── Normal Mode ───
HANDOVER_FILE="$HANDOVER_DIR/$SESSION_ID.md"

echo -e "${CYAN}=== Handover Agent ===${NC}"
echo "Session: $SESSION_ID"
echo "Timestamp: $TIMESTAMP"
echo ""

# Step 1: Gather automatic data
echo -e "${YELLOW}Gathering state...${NC}"

# Get predecessor (previous handover)
PREDECESSOR=""
if [ -f "$HANDOVER_DIR/LATEST.md" ]; then
    PREDECESSOR=$(grep "^session_id:" "$HANDOVER_DIR/LATEST.md" 2>/dev/null | cut -d: -f2 | tr -d ' ')
fi

# Get active tasks
ACTIVE_TASKS=""
shopt -s nullglob
for f in "$TASKS_DIR/active"/*.md; do
    [ -f "$f" ] || continue
    task_id=$(grep "^id:" "$f" | head -1 | cut -d: -f2 | tr -d ' ')
    if [ -n "$task_id" ]; then
        ACTIVE_TASKS="$ACTIVE_TASKS$task_id, "
    fi
done
shopt -u nullglob
ACTIVE_TASKS="${ACTIVE_TASKS%, }"  # Remove trailing comma

# Get git info
UNCOMMITTED=$(git -C "$PROJECT_ROOT" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
LAST_COMMIT=$(git -C "$PROJECT_ROOT" log -1 --pretty=format:"%h %s" 2>/dev/null)
RECENT_COMMITS=$(git -C "$PROJECT_ROOT" log -5 --pretty=format:"- %h %s" 2>/dev/null)

# Get tasks touched recently (modified in last day)
TASKS_TOUCHED=""
for f in $(find "$TASKS_DIR" -name "*.md" -mmin -1440 -type f 2>/dev/null); do
    task_id=$(grep "^id:" "$f" | head -1 | cut -d: -f2 | tr -d ' ')
    if [ -n "$task_id" ]; then
        TASKS_TOUCHED="$TASKS_TOUCHED$task_id, "
    fi
done
TASKS_TOUCHED="${TASKS_TOUCHED%, }"

# Step 1.5: EPISODIC COMPLETENESS GATE
# Check that recently completed tasks have enriched episodic summaries
echo ""
echo -e "${YELLOW}Checking episodic completeness...${NC}"

EPISODIC_DIR="$CONTEXT_DIR/episodic"
EPISODIC_WARNINGS=()

# Find completed tasks modified in last 24 hours (likely completed this session)
shopt -s nullglob
for f in "$TASKS_DIR/completed"/*.md; do
    # Only check files modified in last day
    if [ -z "$(find "$f" -mmin -1440 2>/dev/null)" ]; then
        continue
    fi

    task_id=$(grep "^id:" "$f" | head -1 | cut -d: -f2 | tr -d ' ')
    [ -z "$task_id" ] && continue

    episodic_file="$EPISODIC_DIR/${task_id}.yaml"

    # Check 1: Does episodic file exist?
    if [ ! -f "$episodic_file" ]; then
        EPISODIC_WARNINGS+=("$task_id: Missing episodic summary")
        continue
    fi

    # Check 2: Is it enriched (not pending)?
    enrichment_status=$(grep "^enrichment_status:" "$episodic_file" 2>/dev/null | cut -d: -f2 | tr -d ' ')

    if [ "$enrichment_status" = "pending" ]; then
        EPISODIC_WARNINGS+=("$task_id: Episodic not enriched (status: pending)")
    elif [ -z "$enrichment_status" ]; then
        # Old format without enrichment_status - check if summary is empty
        summary_line=$(grep -A 1 "^summary:" "$episodic_file" | tail -1)
        if echo "$summary_line" | grep -qE '^\s*>\s*$|\[TODO'; then
            EPISODIC_WARNINGS+=("$task_id: Episodic has empty/TODO summary")
        fi
    fi
done
shopt -u nullglob

# Report episodic warnings
if [ ${#EPISODIC_WARNINGS[@]} -gt 0 ]; then
    echo -e "${YELLOW}⚠ EPISODIC CONTEXT GAPS DETECTED${NC}"
    echo ""
    for warning in "${EPISODIC_WARNINGS[@]}"; do
        echo "  - $warning"
    done
    echo ""
    echo "These gaps will cause context loss. Consider:"
    echo "  - Run: ./agents/context/context.sh generate-episodic T-XXX"
    echo "  - Then enrich the [TODO] sections before this handover"
    echo ""
else
    echo -e "${GREEN}✓ All recent completed tasks have enriched episodics${NC}"
fi

# Step 1.6: Observation inbox status
INBOX_FILE="$CONTEXT_DIR/inbox.yaml"
PENDING_OBS=0
URGENT_OBS=0
if [ -f "$INBOX_FILE" ]; then
    PENDING_OBS=$(grep -c 'status: pending' "$INBOX_FILE" 2>/dev/null) || PENDING_OBS=0
    URGENT_OBS=$(python3 -c "
import re
with open('$INBOX_FILE') as f:
    content = f.read()
blocks = re.split(r'\n  - ', content)
urgent = sum(1 for b in blocks[1:] if 'status: pending' in b and 'urgent: true' in b)
print(urgent)
" 2>/dev/null || echo 0)
fi

if [ "$PENDING_OBS" -gt 0 ]; then
    if [ "$URGENT_OBS" -gt 0 ]; then
        echo -e "${YELLOW}⚠ Observation inbox: $PENDING_OBS pending ($URGENT_OBS urgent)${NC}"
    else
        echo -e "${CYAN}Observation inbox: $PENDING_OBS pending${NC}"
    fi
    echo "  Run: fw note triage"
else
    echo -e "${GREEN}✓ Observation inbox clean${NC}"
fi

# Step 1.7: Gaps register status
GAPS_FILE="$CONTEXT_DIR/project/gaps.yaml"
WATCHING_GAPS=0
if [ -f "$GAPS_FILE" ]; then
    WATCHING_GAPS=$(grep -c 'status: watching' "$GAPS_FILE" 2>/dev/null) || WATCHING_GAPS=0
    if [ "$WATCHING_GAPS" -gt 0 ]; then
        echo -e "${CYAN}Gaps register: $WATCHING_GAPS watching${NC}"
    fi
fi

# Step 2: Create handover template
echo -e "${YELLOW}Creating handover document...${NC}"

cat > "$HANDOVER_FILE" << EOF
---
session_id: $SESSION_ID
timestamp: $TIMESTAMP
predecessor: $PREDECESSOR
tasks_active: [$ACTIVE_TASKS]
tasks_touched: [$TASKS_TOUCHED]
tasks_completed: []
uncommitted_changes: $UNCOMMITTED
owner: ${AGENT_OWNER:-claude-code}
session_narrative: ""
---

# Session Handover: $SESSION_ID

## Where We Are

[TODO: 2-3 sentences summarizing current state and immediate situation]

## Work in Progress

EOF

# Add active tasks sorted by horizon (now > next > later)
python3 << PYEOF >> "$HANDOVER_FILE"
import os, re, glob

tasks_dir = "$TASKS_DIR/active"
horizon_order = {'now': 0, 'next': 1, 'later': 2}
tasks = []

for f in sorted(glob.glob(os.path.join(tasks_dir, '*.md'))):
    with open(f) as fh:
        content = fh.read()
    tid = re.search(r'^id:\s*(.+)', content, re.M)
    tname = re.search(r'^name:\s*(.+)', content, re.M)
    tstatus = re.search(r'^status:\s*(.+)', content, re.M)
    thoriz = re.search(r'^horizon:\s*(.+)', content, re.M)
    if not tid:
        continue
    h = thoriz.group(1).strip() if thoriz else 'now'
    tasks.append((horizon_order.get(h, 0), tid.group(1).strip(),
                  tname.group(1).strip() if tname else '',
                  tstatus.group(1).strip() if tstatus else '',
                  h))

tasks.sort(key=lambda t: (t[0], t[1]))
current_horizon = None
for _, tid, tname, tstatus, h in tasks:
    if h != current_horizon:
        current_horizon = h
        print(f'<!-- horizon: {h} -->')
        print()
    print(f'### {tid}: {tname}')
    print(f'- **Status:** {tstatus} (horizon: {h})')
    print(f'- **Last action:** [TODO: What was just done on this task]')
    print(f'- **Next step:** [TODO: What should happen next]')
    print(f'- **Blockers:** [TODO: Any blockers, or "None"]')
    print(f'- **Insight:** [TODO: Key understanding gained, if any]')
    print()
PYEOF

# Add inception section if any inception tasks exist
inception_count=0
shopt -s nullglob
for f in "$TASKS_DIR/active"/*.md; do
    [ -f "$f" ] || continue
    if grep -q "workflow_type: inception" "$f" 2>/dev/null; then
        inception_count=$((inception_count + 1))
    fi
done
shopt -u nullglob
if [ "$inception_count" -gt 0 ]; then
    {
        echo "## Inception Phases"
        echo ""
        echo "**$inception_count inception task(s) pending decision** — run \`fw inception status\` for details."
        echo ""
    } >> "$HANDOVER_FILE"
fi

# Step 2.1: Surface partial-complete tasks (T-372 — blind completion anti-pattern)
# Tasks that are work-completed but have unchecked Human ACs
PARTIAL_COMPLETE_SECTION=$(python3 << 'PCEOF'
import glob, re, os

tasks_dir = os.environ.get("TASKS_DIR", ".tasks")
partial = []
for f in sorted(glob.glob(os.path.join(tasks_dir, "active", "*.md"))):
    with open(f) as fh:
        content = fh.read()
    if "status: work-completed" not in content:
        continue
    # Find ### Human section
    human_match = re.search(r'### Human\n(.*?)(?=\n### |\n## |\Z)', content, re.DOTALL)
    if not human_match:
        continue
    human_section = human_match.group(1)
    unchecked = len(re.findall(r'^\s*-\s*\[ \]', human_section, re.M))
    if unchecked == 0:
        continue
    tid = re.search(r'^id:\s*(\S+)', content, re.M)
    tname = re.search(r'^name:\s*"?(.+?)"?\s*$', content, re.M)
    if tid:
        # Extract first unchecked AC text (truncated)
        first_ac = re.search(r'^\s*-\s*\[ \]\s*(.+)', human_section, re.M)
        ac_preview = first_ac.group(1)[:60] if first_ac else "?"
        partial.append((tid.group(1), tname.group(1) if tname else "?", unchecked, ac_preview))

if partial:
    print("## Human Review Pending")
    print()
    print(f"**{len(partial)} task(s) with unchecked Human ACs** — these need human review before closing.")
    print()
    for tid, tname, count, preview in partial:
        print(f"- **{tid}**: {tname} ({count} unchecked)")
        print(f"  - e.g.: {preview}")
    print()
    print("Review each task's `### Human` section, check the boxes, then: `fw task update T-XXX --status work-completed`")
    print()
PCEOF
)

if [ -n "$PARTIAL_COMPLETE_SECTION" ]; then
    echo "$PARTIAL_COMPLETE_SECTION" >> "$HANDOVER_FILE"
fi

# Add observation inbox status if any pending
if [ "$PENDING_OBS" -gt 0 ]; then
    {
        echo "## Observation Inbox"
        echo ""
        if [ "$URGENT_OBS" -gt 0 ]; then
            echo "**$PENDING_OBS pending observations ($URGENT_OBS urgent)** — run \`fw note triage\` before starting new work."
        else
            echo "**$PENDING_OBS pending observations** — review with \`fw note list\` or \`fw note triage\`."
        fi
        echo ""
        # List pending observation summaries
        python3 << PYEOF
import re
with open("$INBOX_FILE") as f:
    content = f.read()
blocks = re.split(r'\n  - ', content)
for b in blocks[1:]:
    if 'status: pending' not in b:
        continue
    obs_id = re.search(r'id: (OBS-\d+)', b)
    text = re.search(r'text: "(.*?)"', b)
    urgent = 'urgent: true' in b
    if obs_id and text:
        prefix = "[URGENT] " if urgent else ""
        print(f"- {prefix}{obs_id.group(1)}: {text.group(1)}")
PYEOF
        echo ""
    } >> "$HANDOVER_FILE"
fi

# Add gaps register summary if any watching
if [ "$WATCHING_GAPS" -gt 0 ]; then
    {
        echo "## Gaps Register"
        echo ""
        echo "**$WATCHING_GAPS spec-reality gap(s) being watched** — see \`.context/project/gaps.yaml\`"
        echo ""
        python3 << PYEOF
import yaml
with open("$GAPS_FILE") as f:
    data = yaml.safe_load(f)
for gap in data.get('gaps', []):
    if gap.get('status') != 'watching':
        continue
    sev = gap.get('severity', 'unknown')
    print(f"- **{gap['id']}** [{sev}]: {gap['title']}")
PYEOF
        echo ""
        echo "Run \`fw audit\` to check if any trigger conditions are met."
        echo ""
    } >> "$HANDOVER_FILE"
fi

cat >> "$HANDOVER_FILE" << EOF
## Decisions Made This Session

[TODO: List key decisions with rationale and rejected alternatives]

1. **[Decision]**
   - Why: [rationale]
   - Alternatives rejected: [what else was considered]

## Things Tried That Failed

[TODO: Document failed approaches to prevent repetition]

1. **[Approach]** — [why it didn't work]

## Open Questions / Blockers

[TODO: List unresolved questions and blockers]

1. [Question or blocker]

## Gotchas / Warnings for Next Session

[TODO: Things the next session should watch out for]

- [Gotcha]

## Suggested First Action

[TODO: The single most important thing for next session to do first. Only suggest from horizon: now or next tasks. Do NOT suggest horizon: later tasks.]

## Files Changed This Session

[TODO: List created and modified files]

- Created:
- Modified:

## Recent Commits

$RECENT_COMMITS

---

## Handover Quality Feedback (for next session to complete)

- Did this handover help? [ ]
- What was missing?
- What was unnecessary?
EOF

# Step 3: Update LATEST.md (symlink so edits to session file auto-reflect)
ln -sf "$(basename "$HANDOVER_FILE")" "$HANDOVER_DIR/LATEST.md"

echo ""
echo -e "${GREEN}=== Handover Created ===${NC}"
echo "File: $HANDOVER_FILE"
echo "Latest: $HANDOVER_DIR/LATEST.md"

# Handle auto-commit
if [ "$AUTO_COMMIT" = true ]; then
    _resolve_commit_task

    echo ""
    echo -e "${YELLOW}Auto-committing handover...${NC}"

    # Resolve git agent: FRAMEWORK_ROOT (set by this script), then PROJECT_ROOT fallback
    GIT_AGENT=""
    if [ -n "${FRAMEWORK_ROOT:-}" ] && [ -f "$FRAMEWORK_ROOT/agents/git/git.sh" ]; then
        GIT_AGENT="$FRAMEWORK_ROOT/agents/git/git.sh"
    elif [ -f "$PROJECT_ROOT/agents/git/git.sh" ]; then
        GIT_AGENT="$PROJECT_ROOT/agents/git/git.sh"
    fi

    if [ -n "$GIT_AGENT" ]; then
        # Stage handover files
        git -C "$PROJECT_ROOT" add "$HANDOVER_FILE" "$HANDOVER_DIR/LATEST.md"

        # Commit via git agent
        PROJECT_ROOT="$PROJECT_ROOT" "$GIT_AGENT" commit -m "$COMMIT_TASK: Session handover $SESSION_ID"
    else
        echo -e "${RED}Git agent not found. Manual commit required.${NC}"
        echo "Run: git commit -m \"$COMMIT_TASK: Session handover $SESSION_ID\""
    fi
else
    echo ""
    echo -e "${YELLOW}Next steps:${NC}"
    echo "1. Edit $HANDOVER_FILE to fill in [TODO] sections"
    echo "2. Review and refine the synthesis"
    _resolve_commit_task
    echo "3. Commit with: fw git commit -m \"$COMMIT_TASK: Session handover $SESSION_ID\""
    echo ""
    echo -e "${CYAN}Key sections to complete:${NC}"
    echo "- Where We Are (summary)"
    echo "- Work in Progress (last action, next step for each task)"
    echo "- Decisions Made (with rationale)"
    echo "- Suggested First Action (most important)"
fi
