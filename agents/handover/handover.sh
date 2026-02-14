#!/bin/bash
# Handover Agent - Mechanical Operations
# Creates handover documents for session continuity

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FRAMEWORK_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PROJECT_ROOT="${PROJECT_ROOT:-$FRAMEWORK_ROOT}"
TASKS_DIR="$PROJECT_ROOT/.tasks"
CONTEXT_DIR="$PROJECT_ROOT/.context"
HANDOVER_DIR="$CONTEXT_DIR/handovers"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

# Parse arguments
SESSION_ID=""
AUTO_COMMIT=true
COMMIT_TASK=""
EMERGENCY_MODE=false
CHECKPOINT_MODE=false
while [[ $# -gt 0 ]]; do
    case $1 in
        --session) SESSION_ID="$2"; shift 2 ;;
        --commit) AUTO_COMMIT=true; shift ;;
        --no-commit) AUTO_COMMIT=false; shift ;;
        --task|-t) COMMIT_TASK="$2"; shift 2 ;;
        --owner) AGENT_OWNER="$2"; shift 2 ;;
        --emergency) EMERGENCY_MODE=true; AUTO_COMMIT=true; shift ;;
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
            echo "  --emergency    Emergency handover (auto-generated, no [TODO] sections)"
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

# ─── Emergency Mode: auto-generated handover with zero [TODO] sections ───
if [ "$EMERGENCY_MODE" = true ]; then
    HANDOVER_FILE="$HANDOVER_DIR/$SESSION_ID.md"
    echo -e "${RED}=== EMERGENCY Handover ===${NC}"
    echo "Session: $SESSION_ID"

    # Gather all data automatically
    PREDECESSOR=""
    if [ -f "$HANDOVER_DIR/LATEST.md" ]; then
        PREDECESSOR=$(grep "^session_id:" "$HANDOVER_DIR/LATEST.md" 2>/dev/null | cut -d: -f2 | tr -d ' ')
    fi

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
    UNCOMMITTED_FILES=$(git -C "$PROJECT_ROOT" status --short 2>/dev/null || echo "N/A")
    RECENT_DIFFS=$(git -C "$PROJECT_ROOT" log -5 --stat --oneline 2>/dev/null || echo "N/A")
    BRANCH=$(git -C "$PROJECT_ROOT" branch --show-current 2>/dev/null || echo "unknown")

    cat > "$HANDOVER_FILE" << EMERGENCY_EOF
---
session_id: $SESSION_ID
timestamp: $TIMESTAMP
type: emergency
predecessor: $PREDECESSOR
tasks_active: [$ACTIVE_TASKS]
uncommitted_changes: $UNCOMMITTED
owner: ${AGENT_OWNER:-claude-code}
---

# EMERGENCY Handover: $SESSION_ID

> Auto-generated due to context exhaustion risk. No manual sections.

## Where We Are

Emergency handover on branch \`$BRANCH\` with $UNCOMMITTED uncommitted change(s).

## Active Tasks

$(echo -e "$ACTIVE_DETAILS")

## Uncommitted Changes

\`\`\`
$UNCOMMITTED_FILES
\`\`\`

## Recent Commits (with stats)

\`\`\`
$RECENT_DIFFS
\`\`\`

## Recovery Instructions

1. Run \`fw resume status\` to synthesize full state
2. Check git log for recent work: \`git log --oneline -10\`
3. Review uncommitted changes above
4. Check active task files for inline updates
EMERGENCY_EOF

    cp "$HANDOVER_FILE" "$HANDOVER_DIR/LATEST.md"
    echo -e "${GREEN}Emergency handover created: $HANDOVER_FILE${NC}"

    # Reset tool counter
    if [ -f "$FRAMEWORK_ROOT/agents/context/checkpoint.sh" ]; then
        "$FRAMEWORK_ROOT/agents/context/checkpoint.sh" reset 2>/dev/null || true
    fi

    # Auto-commit
    if [ "$AUTO_COMMIT" = true ]; then
        COMMIT_TASK="${COMMIT_TASK:-T-012}"
        GIT_AGENT=""
        if [ -f "$FRAMEWORK_ROOT/agents/git/git.sh" ]; then
            GIT_AGENT="$FRAMEWORK_ROOT/agents/git/git.sh"
        fi
        if [ -n "$GIT_AGENT" ]; then
            git -C "$PROJECT_ROOT" add "$HANDOVER_FILE" "$HANDOVER_DIR/LATEST.md"
            PROJECT_ROOT="$PROJECT_ROOT" "$GIT_AGENT" commit -m "$COMMIT_TASK: Emergency handover $SESSION_ID"
        fi
    fi
    exit 0
fi

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
        COMMIT_TASK="${COMMIT_TASK:-T-012}"
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

# Add active tasks with their status
shopt -s nullglob
for f in "$TASKS_DIR/active"/*.md; do
    [ -f "$f" ] || continue
    task_id=$(grep "^id:" "$f" | head -1 | cut -d: -f2 | tr -d ' ')
    task_name=$(grep "^name:" "$f" | head -1 | cut -d: -f2- | sed 's/^ *//')
    task_status=$(grep "^status:" "$f" | head -1 | cut -d: -f2 | tr -d ' ')

    cat >> "$HANDOVER_FILE" << EOF
### $task_id: $task_name
- **Status:** $task_status
- **Last action:** [TODO: What was just done on this task]
- **Next step:** [TODO: What should happen next]
- **Blockers:** [TODO: Any blockers, or "None"]
- **Insight:** [TODO: Key understanding gained, if any]

EOF
done
shopt -u nullglob

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

[TODO: The single most important thing for next session to do first]

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

# Step 3: Update LATEST.md
cp "$HANDOVER_FILE" "$HANDOVER_DIR/LATEST.md"

echo ""
echo -e "${GREEN}=== Handover Created ===${NC}"
echo "File: $HANDOVER_FILE"
echo "Latest: $HANDOVER_DIR/LATEST.md"

# Handle auto-commit
if [ "$AUTO_COMMIT" = true ]; then
    # Default to T-012 (handover agent task) if not specified
    if [ -z "$COMMIT_TASK" ]; then
        COMMIT_TASK="T-012"
    fi

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
    echo "3. Commit with: ./agents/git/git.sh commit -m \"T-012: Session handover $SESSION_ID\""
    echo ""
    echo -e "${CYAN}Key sections to complete:${NC}"
    echo "- Where We Are (summary)"
    echo "- Work in Progress (last action, next step for each task)"
    echo "- Decisions Made (with rationale)"
    echo "- Suggested First Action (most important)"
fi
