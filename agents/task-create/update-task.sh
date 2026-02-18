#!/bin/bash
# Task Update Agent - Status transitions with auto-triggers
#
# Updates task frontmatter and triggers structural actions:
#   issues/blocked  → auto-diagnose via healing agent
#   work-completed  → set date_finished, move to completed/, generate episodic
#
# Usage:
#   ./agents/task-create/update-task.sh T-XXX --status issues
#   ./agents/task-create/update-task.sh T-XXX --status work-completed
#   ./agents/task-create/update-task.sh T-XXX --owner claude-code
#   ./agents/task-create/update-task.sh T-XXX --status blocked --reason "Waiting on API key"

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PROJECT_ROOT="${PROJECT_ROOT:-$FRAMEWORK_ROOT}"
TASKS_DIR="$PROJECT_ROOT/.tasks"
CONTEXT_DIR="$PROJECT_ROOT/.context"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

VALID_STATUSES="captured started-work issues work-completed"
VALID_HORIZONS="now next later"

# Check for help before positional args
case "${1:-}" in
    -h|--help) set -- "--help" ;; # normalize
esac

# Parse arguments
TASK_ID=""
NEW_STATUS=""
NEW_OWNER=""
NEW_TAGS=""
ADD_TAGS=""
NEW_HORIZON=""
REASON=""
FORCE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --status|-s) NEW_STATUS="$2"; shift 2 ;;
        --owner|-o) NEW_OWNER="$2"; shift 2 ;;
        --tags) NEW_TAGS="$2"; shift 2 ;;
        --add-tag) ADD_TAGS="$2"; shift 2 ;;
        --horizon) NEW_HORIZON="$2"; shift 2 ;;
        --reason|-r) REASON="$2"; shift 2 ;;
        --force|-f) FORCE=true; shift ;;
        -h|--help)
            echo "Usage: update-task.sh T-XXX [options]"
            echo ""
            echo "Options:"
            echo "  --status, -s  New status ($VALID_STATUSES)"
            echo "  --owner, -o   New owner"
            echo "  --tags        Replace tags (comma-separated)"
            echo "  --add-tag     Add tag(s) to existing (comma-separated)"
            echo "  --horizon     Priority horizon: now, next, later"
            echo "  --reason, -r  Reason for status change (logged in Updates)"
            echo "  --force, -f   Bypass acceptance criteria + verification gates on work-completed"
            echo "  -h, --help    Show this help"
            echo ""
            echo "Auto-triggers:"
            echo "  issues           → healing agent diagnose"
            echo "  work-completed   → AC gate + verification gate, date_finished, move to completed/, episodic generation"
            exit 0
            ;;
        T-*) TASK_ID="$1"; shift ;;
        *) echo -e "${RED}Unknown option: $1${NC}"; exit 1 ;;
    esac
done

# Validate task ID
if [ -z "$TASK_ID" ]; then
    echo -e "${RED}ERROR: Task ID required${NC}" >&2
    echo "Usage: fw task update T-XXX --status <status>" >&2
    exit 1
fi

# Find task file
TASK_FILE=""
if [ -f "$TASKS_DIR/active/${TASK_ID}-"*.md ] 2>/dev/null; then
    TASK_FILE=$(ls "$TASKS_DIR/active/${TASK_ID}-"*.md 2>/dev/null | head -1)
elif [ -f "$TASKS_DIR/completed/${TASK_ID}-"*.md ] 2>/dev/null; then
    TASK_FILE=$(ls "$TASKS_DIR/completed/${TASK_ID}-"*.md 2>/dev/null | head -1)
fi

if [ -z "$TASK_FILE" ] || [ ! -f "$TASK_FILE" ]; then
    echo -e "${RED}ERROR: Task $TASK_ID not found${NC}" >&2
    exit 1
fi

# Read current state
OLD_STATUS=$(grep "^status:" "$TASK_FILE" | head -1 | sed 's/status:[[:space:]]*//')
TASK_NAME=$(grep "^name:" "$TASK_FILE" | head -1 | sed 's/name:[[:space:]]*//')
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

echo -e "${CYAN}=== Task Update ===${NC}"
echo "Task:    $TASK_ID ($TASK_NAME)"
echo "File:    $TASK_FILE"

# Track what changed
CHANGES=()

# Update status
if [ -n "$NEW_STATUS" ]; then
    # Validate status
    if ! echo "$VALID_STATUSES" | grep -qw "$NEW_STATUS"; then
        echo -e "${RED}ERROR: Invalid status '$NEW_STATUS'${NC}" >&2
        echo "Valid: $VALID_STATUSES" >&2
        exit 1
    fi

    if [ "$OLD_STATUS" = "$NEW_STATUS" ]; then
        echo -e "${YELLOW}Status already '$NEW_STATUS' — no change${NC}"
    else
        # Validate transition (4-status lifecycle: captured → started-work ↔ issues → work-completed)
        VALID_TRANSITION=false
        case "$OLD_STATUS:$NEW_STATUS" in
            captured:started-work)       VALID_TRANSITION=true ;;
            started-work:captured)       VALID_TRANSITION=true ;;  # Park: defer premature start
            started-work:issues)         VALID_TRANSITION=true ;;
            started-work:work-completed) VALID_TRANSITION=true ;;
            issues:started-work)         VALID_TRANSITION=true ;;
            issues:work-completed)       VALID_TRANSITION=true ;;
            # Legacy compat: refined/blocked → started-work (for old tasks)
            refined:started-work)        VALID_TRANSITION=true ;;
            blocked:started-work)        VALID_TRANSITION=true ;;
        esac

        if [ "$VALID_TRANSITION" = "false" ]; then
            echo -e "${RED}ERROR: Invalid transition '$OLD_STATUS' → '$NEW_STATUS'${NC}" >&2
            echo "Valid transitions:" >&2
            echo "  captured → started-work" >&2
            echo "  started-work → captured | issues | work-completed" >&2
            echo "  issues → started-work | work-completed" >&2
            exit 1
        fi

        # === Template Placeholder Warning (T-137) ===
        # Warn when starting work if AC section still has placeholder text
        if [ "$NEW_STATUS" = "started-work" ]; then
            if grep -q '<!-- Replace with specific' "$TASK_FILE" 2>/dev/null; then
                echo ""
                echo -e "${YELLOW}WARNING: Acceptance Criteria still has placeholder text${NC}"
                echo "  Fill in real criteria before completing this task."
                echo "  The completion gate (P-010) will check them."
                echo ""
            fi
        fi

        # === Acceptance Criteria Gate (P-010) ===
        if [ "$NEW_STATUS" = "work-completed" ]; then
            AC_SECTION=$(sed -n '/^## Acceptance Criteria/,/^## /p' "$TASK_FILE" 2>/dev/null | head -n -1)
            if [ -n "$AC_SECTION" ]; then
                AC_TOTAL=$(echo "$AC_SECTION" | grep -cE '^\s*-\s*\[[ x]\]' || true)
                AC_CHECKED=$(echo "$AC_SECTION" | grep -cE '^\s*-\s*\[x\]' || true)
                AC_UNCHECKED=$((AC_TOTAL - AC_CHECKED))

                if [ "$AC_TOTAL" -gt 0 ] && [ "$AC_UNCHECKED" -gt 0 ]; then
                    if [ "$FORCE" = true ]; then
                        echo -e "${YELLOW}WARNING: $AC_UNCHECKED/$AC_TOTAL acceptance criteria unchecked (--force bypass)${NC}"
                    else
                        echo -e "${RED}ERROR: Cannot complete — $AC_UNCHECKED/$AC_TOTAL acceptance criteria unchecked:${NC}" >&2
                        echo "$AC_SECTION" | grep -E '^\s*-\s*\[ \]' | sed 's/^/  /' >&2
                        echo "" >&2
                        echo "Options:" >&2
                        echo "  1. Check the criteria in the task file, then retry" >&2
                        echo "  2. Use --force to bypass (logged)" >&2
                        exit 1
                    fi
                elif [ "$AC_TOTAL" -gt 0 ]; then
                    echo -e "${GREEN}Acceptance criteria: $AC_CHECKED/$AC_TOTAL checked ✓${NC}"
                fi
            fi
        fi

        # === Verification Gate (P-011) ===
        # Runs shell commands from ## Verification section before allowing work-completed.
        # Each non-comment, non-empty line is executed. If any exits non-zero, completion is blocked.
        # Backward compatible: tasks without ## Verification pass through.
        if [ "$NEW_STATUS" = "work-completed" ]; then
            VERIFY_SECTION=$(sed -n '/^## Verification/,/^## /p' "$TASK_FILE" 2>/dev/null | head -n -1)
            # Strip the heading line itself
            VERIFY_SECTION=$(echo "$VERIFY_SECTION" | tail -n +2)
            # Strip HTML comment blocks (<!-- ... -->) then skip empty/comment lines
            VERIFY_SECTION=$(echo "$VERIFY_SECTION" | python3 -c "
import sys, re
text = sys.stdin.read()
text = re.sub(r'<!--.*?-->', '', text, flags=re.DOTALL)
print(text)
" 2>/dev/null || echo "$VERIFY_SECTION")
            VERIFY_CMDS=$(echo "$VERIFY_SECTION" | grep -vE '^\s*$|^\s*#' || true)

            if [ -n "$VERIFY_CMDS" ]; then
                VERIFY_TOTAL=$(echo "$VERIFY_CMDS" | wc -l)
                VERIFY_PASS=0
                VERIFY_FAIL=0
                VERIFY_FAILURES=""

                echo ""
                echo -e "${CYAN}=== Verification Gate (P-011) ===${NC}"
                echo "Running $VERIFY_TOTAL verification command(s)..."
                echo ""

                while IFS= read -r cmd; do
                    # Trim whitespace
                    cmd=$(echo "$cmd" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
                    [ -z "$cmd" ] && continue

                    # Display command (truncated for readability)
                    DISPLAY_CMD="$cmd"
                    if [ ${#DISPLAY_CMD} -gt 80 ]; then
                        DISPLAY_CMD="${DISPLAY_CMD:0:77}..."
                    fi

                    if eval "$cmd" > /tmp/verify-$$.out 2>&1; then
                        echo -e "  ${GREEN}PASS${NC}: $DISPLAY_CMD"
                        VERIFY_PASS=$((VERIFY_PASS + 1))
                    else
                        EXIT_CODE=$?
                        echo -e "  ${RED}FAIL${NC}: $DISPLAY_CMD (exit $EXIT_CODE)"
                        # Show first 5 lines of output for context
                        head -5 /tmp/verify-$$.out 2>/dev/null | sed 's/^/    /'
                        VERIFY_FAIL=$((VERIFY_FAIL + 1))
                        VERIFY_FAILURES="${VERIFY_FAILURES}\n  - $DISPLAY_CMD (exit $EXIT_CODE)"
                    fi
                    rm -f /tmp/verify-$$.out
                done <<< "$VERIFY_CMDS"

                echo ""
                if [ "$VERIFY_FAIL" -gt 0 ]; then
                    if [ "$FORCE" = true ]; then
                        echo -e "${YELLOW}WARNING: $VERIFY_FAIL/$VERIFY_TOTAL verification(s) failed (--force bypass)${NC}"
                    else
                        echo -e "${RED}ERROR: Cannot complete — $VERIFY_FAIL/$VERIFY_TOTAL verification(s) failed:${NC}" >&2
                        echo -e "$VERIFY_FAILURES" >&2
                        echo "" >&2
                        echo "Options:" >&2
                        echo "  1. Fix the issues and retry" >&2
                        echo "  2. Update ## Verification commands if they are wrong" >&2
                        echo "  3. Use --force to bypass (logged)" >&2
                        exit 1
                    fi
                else
                    echo -e "${GREEN}Verification: $VERIFY_PASS/$VERIFY_TOTAL passed ✓${NC}"
                fi
            fi
        fi

        sed -i "s/^status:.*/status: $NEW_STATUS/" "$TASK_FILE"
        echo "Status:  $OLD_STATUS → $NEW_STATUS"
        CHANGES+=("status: $OLD_STATUS → $NEW_STATUS")
    fi
fi

# Update owner
if [ -n "$NEW_OWNER" ]; then
    OLD_OWNER=$(grep "^owner:" "$TASK_FILE" | head -1 | sed 's/owner:[[:space:]]*//')
    sed -i "s/^owner:.*/owner: $NEW_OWNER/" "$TASK_FILE"
    echo "Owner:   $OLD_OWNER → $NEW_OWNER"
    CHANGES+=("owner: $OLD_OWNER → $NEW_OWNER")
fi

# Update horizon
if [ -n "$NEW_HORIZON" ]; then
    if ! echo "$VALID_HORIZONS" | grep -qw "$NEW_HORIZON"; then
        echo -e "${RED}ERROR: Invalid horizon '$NEW_HORIZON'${NC}" >&2
        echo "Valid horizons: $VALID_HORIZONS" >&2
        exit 1
    fi
    OLD_HORIZON=$(grep "^horizon:" "$TASK_FILE" 2>/dev/null | head -1 | sed 's/horizon:[[:space:]]*//' || true)
    if [ -n "$OLD_HORIZON" ]; then
        sed -i "s/^horizon:.*/horizon: $NEW_HORIZON/" "$TASK_FILE"
    else
        # Add horizon field after status line (for tasks created before this field existed)
        sed -i "/^status:.*/a horizon: $NEW_HORIZON" "$TASK_FILE"
    fi
    echo "Horizon: ${OLD_HORIZON:-unset} → $NEW_HORIZON"
    CHANGES+=("horizon: ${OLD_HORIZON:-unset} → $NEW_HORIZON")
fi

# Update tags (replace or add)
if [ -n "$NEW_TAGS" ] || [ -n "$ADD_TAGS" ]; then
    if grep -q "^tags:" "$TASK_FILE"; then
        if [ -n "$NEW_TAGS" ]; then
            # Replace all tags
            IFS=',' read -ra tag_items <<< "$NEW_TAGS"
            tag_yaml="["
            first=true
            for t in "${tag_items[@]}"; do
                t=$(echo "$t" | xargs)
                [ -z "$t" ] && continue
                if [ "$first" = true ]; then tag_yaml="${tag_yaml}${t}"; first=false
                else tag_yaml="${tag_yaml}, ${t}"; fi
            done
            tag_yaml="${tag_yaml}]"
            sed -i "s/^tags:.*/tags: $tag_yaml/" "$TASK_FILE"
            echo "Tags:    → $tag_yaml"
            CHANGES+=("tags: → $tag_yaml")
        elif [ -n "$ADD_TAGS" ]; then
            # Add to existing tags via python (safer YAML manipulation)
            python3 -c "
import re, sys
tag_input = sys.argv[1]
new_tags = [t.strip() for t in tag_input.split(',') if t.strip()]
with open(sys.argv[2]) as f:
    content = f.read()
m = re.search(r'^tags:\s*\[([^\]]*)\]', content, re.MULTILINE)
if m:
    existing = [t.strip() for t in m.group(1).split(',') if t.strip()]
    combined = list(dict.fromkeys(existing + new_tags))
    new_line = 'tags: [' + ', '.join(combined) + ']'
    content = content[:m.start()] + new_line + content[m.end():]
else:
    # No tags line — add after owner
    content = re.sub(r'^(owner:.*)', r'\1\ntags: [' + ', '.join(new_tags) + ']', content, count=1, flags=re.MULTILINE)
with open(sys.argv[2], 'w') as f:
    f.write(content)
" "$ADD_TAGS" "$TASK_FILE"
            echo "Tags:    +$ADD_TAGS"
            CHANGES+=("tags: +$ADD_TAGS")
        fi
    else
        # No tags field exists — add it
        IFS=',' read -ra tag_items <<< "${NEW_TAGS:-$ADD_TAGS}"
        tag_yaml="["
        first=true
        for t in "${tag_items[@]}"; do
            t=$(echo "$t" | xargs)
            [ -z "$t" ] && continue
            if [ "$first" = true ]; then tag_yaml="${tag_yaml}${t}"; first=false
            else tag_yaml="${tag_yaml}, ${t}"; fi
        done
        tag_yaml="${tag_yaml}]"
        sed -i "/^owner:.*/a tags: $tag_yaml" "$TASK_FILE"
        echo "Tags:    $tag_yaml (added)"
        CHANGES+=("tags: $tag_yaml (added)")
    fi
fi

# Update last_update timestamp
sed -i "s/^last_update:.*/last_update: $TIMESTAMP/" "$TASK_FILE"

# Append update entry
if [ ${#CHANGES[@]} -gt 0 ]; then
    {
        echo ""
        echo "### $TIMESTAMP — status-update [task-update-agent]"
        for change in "${CHANGES[@]}"; do
            echo "- **Change:** $change"
        done
        if [ -n "$REASON" ]; then
            echo "- **Reason:** $REASON"
        fi
    } >> "$TASK_FILE"
fi

# === AUTO-TRIGGERS ===

# Trigger 1: issues/blocked → healing diagnosis
if [ -n "$NEW_STATUS" ] && [ "$OLD_STATUS" != "$NEW_STATUS" ]; then
    if [ "$NEW_STATUS" = "issues" ] || [ "$NEW_STATUS" = "blocked" ]; then
        echo ""
        echo -e "${YELLOW}=== Auto-trigger: Healing Diagnosis ===${NC}"

        HEALING_AGENT="$FRAMEWORK_ROOT/agents/healing/healing.sh"
        if [ -x "$HEALING_AGENT" ]; then
            PROJECT_ROOT="$PROJECT_ROOT" "$HEALING_AGENT" diagnose "$TASK_ID" || true
        else
            echo -e "${YELLOW}Healing agent not found at $HEALING_AGENT${NC}"
            echo "Run manually: fw healing diagnose $TASK_ID"
        fi
    fi
fi

# Trigger 2: work-completed → finalize
if [ -n "$NEW_STATUS" ] && [ "$NEW_STATUS" = "work-completed" ] && [ "$OLD_STATUS" != "work-completed" ]; then
    # Set date_finished
    sed -i "s/^date_finished:.*/date_finished: $TIMESTAMP/" "$TASK_FILE"
    echo ""
    echo -e "${GREEN}date_finished set to $TIMESTAMP${NC}"

    # Move to completed/
    DEST="$TASKS_DIR/completed/$(basename "$TASK_FILE")"
    if [ "$(dirname "$TASK_FILE")" != "$TASKS_DIR/completed" ]; then
        mv "$TASK_FILE" "$DEST"
        TASK_FILE="$DEST"
        echo -e "${GREEN}Moved to completed/${NC}"
    fi

    # Generate episodic summary
    echo ""
    echo -e "${YELLOW}=== Auto-trigger: Episodic Generation ===${NC}"

    CONTEXT_AGENT="$FRAMEWORK_ROOT/agents/context/context.sh"
    if [ -x "$CONTEXT_AGENT" ]; then
        PROJECT_ROOT="$PROJECT_ROOT" "$CONTEXT_AGENT" generate-episodic "$TASK_ID" || true
    else
        echo -e "${YELLOW}Context agent not found${NC}"
        echo "Run manually: fw context generate-episodic $TASK_ID"
    fi
fi

echo ""
echo -e "${GREEN}=== Update Complete ===${NC}"
