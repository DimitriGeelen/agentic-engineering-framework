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
source "$FRAMEWORK_ROOT/lib/paths.sh"

# Colors provided by lib/colors.sh (via paths.sh chain)

# Source enumerations (single source of truth)
source "$FRAMEWORK_ROOT/lib/enums.sh"

# === Extracted gate functions (T-415) ===
# Each function accesses outer-scope variables: TASK_FILE, TASK_ID, FORCE, colors

# Human Sovereignty Gate (R-033/T-198)
# Block agent from completing human-owned tasks without human interaction.
check_human_sovereignty() {
    local current_owner
    current_owner=$(grep "^owner:" "$TASK_FILE" | head -1 | sed 's/owner:[[:space:]]*//')
    if [ "$current_owner" = "human" ]; then
        if [ "$FORCE" = true ]; then
            echo -e "${YELLOW}WARNING: Completing human-owned task (--force bypass)${NC}"
        else
            echo -e "${RED}ERROR: Cannot complete human-owned task — sovereignty gate (R-033)${NC}" >&2
            echo "Task $TASK_ID has owner: human. Only the human can complete it." >&2
            echo "Options:" >&2
            echo "  1. Human completes: fw task update $TASK_ID --status work-completed --force" >&2
            echo "  2. Reassign first: fw task update $TASK_ID --owner agent --force" >&2
            exit 1
        fi
    fi
}

# Acceptance Criteria Gate (P-010)
# T-193: Supports ### Agent / ### Human AC split.
# Sets PARTIAL_COMPLETE=true if human ACs remain unchecked.
check_acceptance_criteria() {
    local ac_section has_agent_header has_human_header
    local agent_acs ac_total ac_checked ac_unchecked ac_label
    local human_acs placeholder_acs placeholder_count

    ac_section=$(sed -n '/^## Acceptance Criteria/,/^## /p' "$TASK_FILE" 2>/dev/null | sed '$d')
    [ -z "$ac_section" ] && return 0

    has_agent_header=$(echo "$ac_section" | grep -c '^### Agent' || true)
    has_human_header=$(echo "$ac_section" | grep -c '^### Human' || true)

    if [ "$has_agent_header" -gt 0 ]; then
        agent_acs=$(echo "$ac_section" | awk '/^### Agent/{f=1; next} /^### /{f=0} f')
        ac_total=$(echo "$agent_acs" | grep -cE '^\s*-\s*\[[ x]\]' || true)
        ac_checked=$(echo "$agent_acs" | grep -cE '^\s*-\s*\[x\]' || true)
        ac_unchecked=$((ac_total - ac_checked))
        ac_label="agent AC"

        HUMAN_AC_TOTAL=0
        HUMAN_AC_CHECKED=0
        if [ "$has_human_header" -gt 0 ]; then
            human_acs=$(echo "$ac_section" | awk '/^### Human/{f=1; next} /^### /{f=0} f')
            HUMAN_AC_TOTAL=$(echo "$human_acs" | grep -cE '^\s*-\s*\[[ x]\]' || true)
            HUMAN_AC_CHECKED=$(echo "$human_acs" | grep -cE '^\s*-\s*\[x\]' || true)
        fi
    else
        ac_total=$(echo "$ac_section" | grep -cE '^\s*-\s*\[[ x]\]' || true)
        ac_checked=$(echo "$ac_section" | grep -cE '^\s*-\s*\[x\]' || true)
        ac_unchecked=$((ac_total - ac_checked))
        ac_label="acceptance criteria"
        HUMAN_AC_TOTAL=0
        HUMAN_AC_CHECKED=0
    fi

    # Gate: unchecked ACs block completion
    if [ "$ac_total" -gt 0 ] && [ "$ac_unchecked" -gt 0 ]; then
        if [ "$FORCE" = true ]; then
            echo -e "${YELLOW}WARNING: $ac_unchecked/$ac_total $ac_label unchecked (--force bypass)${NC}"
        else
            echo -e "${RED}ERROR: Cannot complete — $ac_unchecked/$ac_total $ac_label unchecked:${NC}" >&2
            if [ "$has_agent_header" -gt 0 ]; then
                echo "$agent_acs" | grep -E '^\s*-\s*\[ \]' | sed 's/^/  /' >&2
            else
                echo "$ac_section" | grep -E '^\s*-\s*\[ \]' | sed 's/^/  /' >&2
            fi
            echo "" >&2
            echo "Options:" >&2
            echo "  1. Check the criteria in the task file, then retry" >&2
            echo "  2. Use --force to bypass (logged)" >&2
            exit 1
        fi
    elif [ "$ac_total" -gt 0 ]; then
        # Placeholder detection: reject skeleton/template ACs
        placeholder_acs=""
        if [ "$has_agent_header" -gt 0 ]; then
            placeholder_acs=$(echo "$agent_acs" | grep -iE '^\s*-\s*\[x\]\s*\[(First|Second|Third|Fourth|Fifth) criterion\]' || true)
            [ -z "$placeholder_acs" ] && placeholder_acs=$(echo "$agent_acs" | grep -iE '^\s*-\s*\[x\]\s*\[Criterion [0-9]+\]' || true)
        else
            placeholder_acs=$(echo "$ac_section" | grep -iE '^\s*-\s*\[x\]\s*\[(First|Second|Third|Fourth|Fifth) criterion\]' || true)
            [ -z "$placeholder_acs" ] && placeholder_acs=$(echo "$ac_section" | grep -iE '^\s*-\s*\[x\]\s*\[Criterion [0-9]+\]' || true)
        fi

        if [ -n "$placeholder_acs" ]; then
            if [ "$FORCE" = true ]; then
                echo -e "${YELLOW}WARNING: Skeleton/placeholder ACs detected (--force bypass)${NC}"
            else
                placeholder_count=$(echo "$placeholder_acs" | wc -l)
                echo -e "${RED}ERROR: Cannot complete — $placeholder_count $ac_label are skeleton placeholders:${NC}" >&2
                echo "$placeholder_acs" | sed 's/^/  /' >&2
                echo "" >&2
                echo "Replace placeholder text with real, specific acceptance criteria." >&2
                echo "Options:" >&2
                echo "  1. Edit the task file with real ACs, then retry" >&2
                echo "  2. Use --force to bypass (logged)" >&2
                exit 1
            fi
        else
            echo -e "${GREEN}Acceptance criteria: $ac_checked/$ac_total checked ✓${NC}"
        fi
    fi

    # Report human AC status if split mode (T-193)
    if [ "$has_agent_header" -gt 0 ] && [ "$HUMAN_AC_TOTAL" -gt 0 ]; then
        local human_ac_unchecked=$((HUMAN_AC_TOTAL - HUMAN_AC_CHECKED))
        if [ "$human_ac_unchecked" -gt 0 ]; then
            echo -e "${YELLOW}Human: $HUMAN_AC_CHECKED/$HUMAN_AC_TOTAL checked (not blocking)${NC}"
            PARTIAL_COMPLETE=true
        else
            echo -e "${GREEN}Human: $HUMAN_AC_CHECKED/$HUMAN_AC_TOTAL checked ✓${NC}"
        fi
    fi
}

# Verification Gate (P-011)
# Runs shell commands from ## Verification section before allowing work-completed.
run_verification_commands() {
    local verify_section verify_cmds verify_total verify_pass verify_fail verify_failures
    local cmd display_cmd exit_code

    verify_section=$(sed -n '/^## Verification/,/^## /p' "$TASK_FILE" 2>/dev/null | sed '$d')
    verify_section=$(echo "$verify_section" | tail -n +2)
    # Strip HTML comment blocks
    verify_section=$(echo "$verify_section" | python3 -c "
import sys, re
text = sys.stdin.read()
text = re.sub(r'<!--.*?-->', '', text, flags=re.DOTALL)
print(text)
" 2>/dev/null || echo "$verify_section")
    verify_cmds=$(echo "$verify_section" | grep -vE '^\s*$|^\s*#|^\s*```' || true)

    [ -z "$verify_cmds" ] && return 0

    verify_total=$(echo "$verify_cmds" | wc -l)
    verify_pass=0
    verify_fail=0
    verify_failures=""

    echo ""
    echo -e "${CYAN}=== Verification Gate (P-011) ===${NC}"
    echo "Running $verify_total verification command(s)..."
    echo ""

    while IFS= read -r cmd; do
        cmd=$(echo "$cmd" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
        [ -z "$cmd" ] && continue

        display_cmd="$cmd"
        if [ ${#display_cmd} -gt 80 ]; then
            display_cmd="${display_cmd:0:77}..."
        fi

        if eval "$cmd" > /tmp/verify-$$.out 2>&1; then
            echo -e "  ${GREEN}PASS${NC}: $display_cmd"
            verify_pass=$((verify_pass + 1))
        else
            exit_code=$?
            echo -e "  ${RED}FAIL${NC}: $display_cmd (exit $exit_code)"
            head -5 /tmp/verify-$$.out 2>/dev/null | sed 's/^/    /'
            verify_fail=$((verify_fail + 1))
            verify_failures="${verify_failures}\n  - $display_cmd (exit $exit_code)"
        fi
        rm -f /tmp/verify-$$.out
    done <<< "$verify_cmds"

    echo ""
    if [ "$verify_fail" -gt 0 ]; then
        if [ "$FORCE" = true ]; then
            echo -e "${YELLOW}WARNING: $verify_fail/$verify_total verification(s) failed (--force bypass)${NC}"
        else
            echo -e "${RED}ERROR: Cannot complete — $verify_fail/$verify_total verification(s) failed:${NC}" >&2
            echo -e "$verify_failures" >&2
            echo "" >&2
            echo "Options:" >&2
            echo "  1. Fix the issues and retry" >&2
            echo "  2. Update ## Verification commands if they are wrong" >&2
            echo "  3. Use --force to bypass (logged)" >&2
            exit 1
        fi
    else
        echo -e "${GREEN}Verification: $verify_pass/$verify_total passed ✓${NC}"
    fi
}

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
NEW_TYPE=""
REASON=""
FORCE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --status|-s) NEW_STATUS="$2"; shift 2 ;;
        --owner|-o) NEW_OWNER="$2"; shift 2 ;;
        --tags) NEW_TAGS="$2"; shift 2 ;;
        --add-tag) ADD_TAGS="$2"; shift 2 ;;
        --horizon) NEW_HORIZON="$2"; shift 2 ;;
        --type|-t) NEW_TYPE="$2"; shift 2 ;;
        --reason|-r) REASON="$2"; shift 2 ;;
        --force|-f) FORCE=true; shift ;;
        -h|--help)
            echo "Usage: update-task.sh T-XXX [options]"
            echo ""
            echo "Options:"
            echo "  --status, -s  New status ($VALID_STATUSES)"
            echo "  --owner, -o   New owner"
            echo "  --type, -t    Workflow type ($VALID_TYPES)"
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
    error "Task ID required"
    die "Usage: fw task update T-XXX --status <status>"
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
    if ! is_valid_status "$NEW_STATUS"; then
        error "Invalid status '$NEW_STATUS'"
        die "Valid: $VALID_STATUSES"
    fi

    if [ "$OLD_STATUS" = "$NEW_STATUS" ]; then
        if [ "$OLD_STATUS" = "work-completed" ] && [ "$(dirname "$TASK_FILE")" = "$TASKS_DIR/active" ]; then
            # T-193: Partial-complete re-run — check if human ACs now satisfied
            echo -e "${CYAN}Re-checking partial-complete status...${NC}"
            AC_SECTION=$(sed -n '/^## Acceptance Criteria/,/^## /p' "$TASK_FILE" 2>/dev/null | sed '$d')
            ALL_TOTAL=$(echo "$AC_SECTION" | grep -cE '^\s*-\s*\[[ x]\]' || true)
            ALL_CHECKED=$(echo "$AC_SECTION" | grep -cE '^\s*-\s*\[x\]' || true)
            ALL_UNCHECKED=$((ALL_TOTAL - ALL_CHECKED))

            if [ "$ALL_TOTAL" -gt 0 ] && [ "$ALL_UNCHECKED" -eq 0 ]; then
                echo -e "${GREEN}All ACs checked (including human) ✓${NC}"
                DEST="$TASKS_DIR/completed/$(basename "$TASK_FILE")"
                mv "$TASK_FILE" "$DEST"
                TASK_FILE="$DEST"
                echo -e "${GREEN}Moved to completed/${NC}"

                # Generate episodic if not already present
                if [ ! -f "$CONTEXT_DIR/episodic/$TASK_ID.yaml" ]; then
                    echo ""
                    echo -e "${YELLOW}=== Auto-trigger: Episodic Generation ===${NC}"
                    CONTEXT_AGENT="$FRAMEWORK_ROOT/agents/context/context.sh"
                    if [ -x "$CONTEXT_AGENT" ]; then
                        PROJECT_ROOT="$PROJECT_ROOT" "$CONTEXT_AGENT" generate-episodic "$TASK_ID" || true
                    fi
                fi
            else
                echo -e "${YELLOW}Still $ALL_UNCHECKED/$ALL_TOTAL ACs unchecked — task stays in active/${NC}"
                echo "Check human ACs in the task file, then re-run this command."
            fi
        else
            echo -e "${YELLOW}Status already '$NEW_STATUS' — no change${NC}"
        fi
    else
        # Validate transition using centralized state machine (lib/enums.sh)
        if ! is_valid_transition "$OLD_STATUS" "$NEW_STATUS"; then
            echo -e "${RED}ERROR: Invalid transition '$OLD_STATUS' → '$NEW_STATUS'${NC}" >&2
            echo "Valid transitions:" >&2
            for from_status in $VALID_STATUSES; do
                targets="$(valid_transitions_for "$from_status")"
                [[ -n "$targets" ]] && echo "  $from_status → ${targets// / | }" >&2
            done
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

        # === Human Sovereignty Gate (R-033/T-198) ===
        if [ "$NEW_STATUS" = "work-completed" ]; then
            check_human_sovereignty
        fi

        # === Acceptance Criteria Gate (P-010) ===
        PARTIAL_COMPLETE=false
        if [ "$NEW_STATUS" = "work-completed" ]; then
            check_acceptance_criteria
        fi

        # === Verification Gate (P-011) ===
        if [ "$NEW_STATUS" = "work-completed" ]; then
            run_verification_commands
        fi

        _sed_i "s/^status:.*/status: $NEW_STATUS/" "$TASK_FILE"
        echo "Status:  $OLD_STATUS → $NEW_STATUS"
        CHANGES+=("status: $OLD_STATUS → $NEW_STATUS")
    fi
fi

# Update owner
if [ -n "$NEW_OWNER" ]; then
    OLD_OWNER=$(grep "^owner:" "$TASK_FILE" | head -1 | sed 's/owner:[[:space:]]*//')
    # T-198/R-033: Owner protection — owner: human is sticky
    if [ "$OLD_OWNER" = "human" ] && [ "$NEW_OWNER" != "human" ]; then
        if [ "$FORCE" = true ]; then
            echo -e "${YELLOW}WARNING: Overriding human ownership (--force bypass)${NC}"
        else
            echo -e "${RED}ERROR: Cannot change owner from 'human' — human ownership is protected (R-033)${NC}" >&2
            echo "Only the human can reassign human-owned tasks." >&2
            echo "Use --force to bypass (logged)." >&2
            exit 1
        fi
    fi
    _sed_i "s/^owner:.*/owner: $NEW_OWNER/" "$TASK_FILE"
    echo "Owner:   $OLD_OWNER → $NEW_OWNER"
    CHANGES+=("owner: $OLD_OWNER → $NEW_OWNER")
fi

# Update workflow type
if [ -n "$NEW_TYPE" ]; then
    if ! is_valid_type "$NEW_TYPE"; then
        echo -e "${RED}ERROR: Invalid workflow type '$NEW_TYPE'${NC}" >&2
        echo "Valid types: $VALID_TYPES" >&2
        exit 1
    fi
    OLD_TYPE=$(grep "^workflow_type:" "$TASK_FILE" | head -1 | sed 's/workflow_type:[[:space:]]*//')
    _sed_i "s/^workflow_type:.*/workflow_type: $NEW_TYPE/" "$TASK_FILE"
    echo "Type:    ${OLD_TYPE:-unset} → $NEW_TYPE"
    CHANGES+=("workflow_type: ${OLD_TYPE:-unset} → $NEW_TYPE")
fi

# Update horizon
if [ -n "$NEW_HORIZON" ]; then
    if ! is_valid_horizon "$NEW_HORIZON"; then
        echo -e "${RED}ERROR: Invalid horizon '$NEW_HORIZON'${NC}" >&2
        echo "Valid horizons: $VALID_HORIZONS" >&2
        exit 1
    fi
    OLD_HORIZON=$(grep "^horizon:" "$TASK_FILE" 2>/dev/null | head -1 | sed 's/horizon:[[:space:]]*//' || true)
    if [ -n "$OLD_HORIZON" ]; then
        _sed_i "s/^horizon:.*/horizon: $NEW_HORIZON/" "$TASK_FILE"
    else
        # Add horizon field after status line (for tasks created before this field existed)
        _sed_i "/^status:.*/a\\
horizon: $NEW_HORIZON" "$TASK_FILE"
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
            _sed_i "s/^tags:.*/tags: $tag_yaml/" "$TASK_FILE"
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
        _sed_i "/^owner:.*/a\\
tags: $tag_yaml" "$TASK_FILE"
        echo "Tags:    $tag_yaml (added)"
        CHANGES+=("tags: $tag_yaml (added)")
    fi
fi

# Update last_update timestamp
_sed_i "s/^last_update:.*/last_update: $TIMESTAMP/" "$TASK_FILE"

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
    _sed_i "s/^date_finished:.*/date_finished: $TIMESTAMP/" "$TASK_FILE"
    echo ""
    echo -e "${GREEN}date_finished set to $TIMESTAMP${NC}"

    # Move to completed/ (or partial-complete: stay in active/)
    if [ "${PARTIAL_COMPLETE:-false}" = true ]; then
        # T-193: Agent done but human ACs pending — stay in active/
        _sed_i "s/^owner:.*/owner: human/" "$TASK_FILE"
        HUMAN_AC_UNCHECKED_REMAINING=$((HUMAN_AC_TOTAL - HUMAN_AC_CHECKED))
        echo -e "${YELLOW}Partial-complete: $HUMAN_AC_UNCHECKED_REMAINING human AC(s) pending verification${NC}"
        echo -e "${YELLOW}Task stays in active/ — owner set to human${NC}"
        echo "Finalize after verification: fw task update $TASK_ID --status work-completed"

        # T-325: Check human AC quality — warn if Steps blocks are missing
        HUMAN_AC_SECTION=$(sed -n '/^### Human/,/^## \|^### [^H]/p' "$TASK_FILE" 2>/dev/null | head -n -1)
        HUMAN_AC_COUNT=$(echo "$HUMAN_AC_SECTION" | grep -cE '^\s*-\s*\[[ x]\]' || true)
        HUMAN_AC_WITH_STEPS=$(echo "$HUMAN_AC_SECTION" | grep -cE '^\s+\*\*Steps:\*\*' || true)
        if [ "$HUMAN_AC_COUNT" -gt 0 ] && [ "$HUMAN_AC_WITH_STEPS" -lt "$HUMAN_AC_COUNT" ]; then
            MISSING=$((HUMAN_AC_COUNT - HUMAN_AC_WITH_STEPS))
            echo ""
            echo -e "${YELLOW}Human AC quality: $MISSING of $HUMAN_AC_COUNT criteria lack Steps/Expected blocks.${NC}"
            echo -e "${YELLOW}  Tip: Add Steps: with numbered instructions so the reviewer can act immediately.${NC}"
            echo -e "${YELLOW}  See CLAUDE.md 'Human AC Format Requirements' for the required format.${NC}"
        fi
    else
        DEST="$TASKS_DIR/completed/$(basename "$TASK_FILE")"
        if [ "$(dirname "$TASK_FILE")" != "$TASKS_DIR/completed" ]; then
            mv "$TASK_FILE" "$DEST"
            TASK_FILE="$DEST"
            echo -e "${GREEN}Moved to completed/${NC}"
        fi
    fi

    # === Clear focus if this was the focused task (T-354) ===
    # Only for full completion (not partial-complete — human still needs focus)
    if [ "${PARTIAL_COMPLETE:-false}" = false ]; then
        FOCUS_FILE="$CONTEXT_DIR/working/focus.yaml"
        if [ -f "$FOCUS_FILE" ]; then
            FOCUSED_TASK=$(grep "^current_task:" "$FOCUS_FILE" | sed 's/current_task:[[:space:]]*//')
            if [ "$FOCUSED_TASK" = "$TASK_ID" ]; then
                _sed_i "s/^current_task:.*/current_task: null/" "$FOCUS_FILE"
                echo -e "${YELLOW}Focus cleared (task completed). Set new focus: fw work-on T-XXX${NC}"
            fi
        fi
    fi

    # === Auto-populate components field (T-224) ===
    # Resolve git diff paths to component IDs via .fabric/components/*.yaml location field
    FABRIC_DIR="$PROJECT_ROOT/.fabric/components"
    if [ -d "$FABRIC_DIR" ]; then
        # Build location→id lookup from component cards
        # Build location→id lookup (temp file, POSIX-safe — no declare -A)
        LOC_TO_ID_FILE=$(mktemp)
        for card in "$FABRIC_DIR"/*.yaml; do
            [ -f "$card" ] || continue
            c_loc=$(grep "^location:" "$card" 2>/dev/null | sed 's/^location:[[:space:]]*//' | head -1)
            c_id=$(grep "^id:" "$card" 2>/dev/null | sed 's/^id:[[:space:]]*//' | head -1)
            if [ -n "$c_loc" ] && [ -n "$c_id" ]; then
                echo "${c_loc}=${c_id}" >> "$LOC_TO_ID_FILE"
            fi
        done

        # Get all files changed in commits for this task
        TASK_COMMITS=$(git log --all --oneline --grep="$TASK_ID" 2>/dev/null | awk '{print $1}')
        RESOLVED_COMPONENTS=""
        if [ -n "$TASK_COMMITS" ]; then
            ALL_PATHS=$(for c in $TASK_COMMITS; do git diff --name-only "${c}~1" "$c" 2>/dev/null; done | sort -u)
            for path in $ALL_PATHS; do
                # Skip metadata paths
                case "$path" in
                    .context/*|.tasks/*|.fabric/*|docs/*) continue ;;
                esac
                comp_id=$(grep "^${path}=" "$LOC_TO_ID_FILE" 2>/dev/null | head -1 | cut -d= -f2-)
                if [ -n "$comp_id" ]; then
                    RESOLVED_COMPONENTS="${RESOLVED_COMPONENTS:+$RESOLVED_COMPONENTS, }${comp_id}"
                fi
            done
        fi

        # Update components field if we found any
        if [ -n "$RESOLVED_COMPONENTS" ]; then
            if grep -q "^components:" "$TASK_FILE" 2>/dev/null; then
                _sed_i "s|^components:.*|components: [$RESOLVED_COMPONENTS]|" "$TASK_FILE"
            else
                # Add field after tags line
                _sed_i "/^tags:.*/a\\
components: [$RESOLVED_COMPONENTS]" "$TASK_FILE"
            fi
            COMP_COUNT=$(echo "$RESOLVED_COMPONENTS" | tr ',' '\n' | wc -l)
            echo -e "${GREEN}Components: $COMP_COUNT resolved from git history${NC}"
        fi
        rm -f "$LOC_TO_ID_FILE"
    fi

    # === Auto-capture decisions from task file (T-236) ===
    # Extract decisions from ## Decisions section and record to context fabric
    CONTEXT_AGENT="$FRAMEWORK_ROOT/agents/context/context.sh"
    if [ -x "$CONTEXT_AGENT" ] && [ -f "$TASK_FILE" ]; then
        # Extract "Chose:" lines from Decisions section as decision summaries
        IN_DECISIONS=false
        DECISION_COUNT=0
        while IFS= read -r line; do
            if echo "$line" | grep -q '^## Decisions'; then
                IN_DECISIONS=true
                continue
            fi
            if echo "$line" | grep -q '^## ' && [ "$IN_DECISIONS" = true ]; then
                break
            fi
            if [ "$IN_DECISIONS" = true ]; then
                # Match "**Chose:**" or "**Decision**:" patterns
                DECISION_TEXT=""
                if echo "$line" | grep -qE '\*\*Chose:\*\*'; then
                    DECISION_TEXT=$(echo "$line" | sed 's/.*\*\*Chose:\*\*[[:space:]]*//')
                elif echo "$line" | grep -qE '\*\*Decision\*\*:'; then
                    DECISION_TEXT=$(echo "$line" | sed 's/.*\*\*Decision\*\*:[[:space:]]*//')
                fi
                # Filter out template placeholders
                case "$DECISION_TEXT" in
                    *"[what was decided]"*|*"[topic]"*|*"[rationale]"*|*"TODO"*) DECISION_TEXT="" ;;
                esac
                if [ -n "$DECISION_TEXT" ] && [ ${#DECISION_TEXT} -gt 5 ]; then
                    PROJECT_ROOT="$PROJECT_ROOT" "$CONTEXT_AGENT" add-decision "$DECISION_TEXT" --task "$TASK_ID" --rationale "Auto-captured from task file on completion" 2>/dev/null && \
                        DECISION_COUNT=$((DECISION_COUNT + 1)) || true
                fi
            fi
        done < "$TASK_FILE"
        if [ "$DECISION_COUNT" -gt 0 ]; then
            echo -e "${GREEN}Auto-captured $DECISION_COUNT decision(s) from task file${NC}"
        fi
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
