#!/bin/bash
# Handover Agent - Mechanical Operations
# Creates handover documents for session continuity

PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
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
AUTO_COMMIT=false
COMMIT_TASK=""
while [[ $# -gt 0 ]]; do
    case $1 in
        --session) SESSION_ID="$2"; shift 2 ;;
        --commit) AUTO_COMMIT=true; shift ;;
        --task|-t) COMMIT_TASK="$2"; shift 2 ;;
        --owner) AGENT_OWNER="$2"; shift 2 ;;
        -h|--help)
            echo "Usage: handover.sh [options]"
            echo ""
            echo "Options:"
            echo "  --session ID   Use specific session ID (default: auto-generated)"
            echo "  --commit       Auto-commit handover via git agent"
            echo "  --task, -t ID  Task ID for commit (default: T-012)"
            echo "  --owner NAME   Agent/provider name (default: \$AGENT_OWNER or claude-code)"
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
HANDOVER_FILE="$HANDOVER_DIR/$SESSION_ID.md"

# Ensure directories exist
mkdir -p "$HANDOVER_DIR"

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

    if [ -f "$PROJECT_ROOT/agents/git/git.sh" ]; then
        # Stage handover files
        git -C "$PROJECT_ROOT" add "$HANDOVER_FILE" "$HANDOVER_DIR/LATEST.md"

        # Commit via git agent
        "$PROJECT_ROOT/agents/git/git.sh" commit -m "$COMMIT_TASK: Session handover $SESSION_ID"
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
