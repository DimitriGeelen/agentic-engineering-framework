#!/bin/bash
# fw inception - Inception phase workflow
# Manages exploration-phase work: problem definition, assumptions, go/no-go

# Ensure _fw_cmd/_emit_user_command are available (T-1143)
[[ -z "${_FW_PATHS_LOADED:-}" ]] && source "${FRAMEWORK_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}/lib/paths.sh" 2>/dev/null || true

do_inception() {
    local subcmd="${1:-}"
    shift || true

    case "$subcmd" in
        start)
            do_inception_start "$@"
            ;;
        status)
            do_inception_status "$@"
            ;;
        decide)
            do_inception_decide "$@"
            ;;
        ""|-h|--help)
            show_inception_help
            ;;
        *)
            echo -e "${RED}Unknown inception subcommand: $subcmd${NC}"
            show_inception_help
            exit 1
            ;;
    esac
}

show_inception_help() {
    echo -e "${BOLD}fw inception${NC} - Inception phase workflow"
    echo ""
    echo -e "${BOLD}Commands:${NC}"
    echo "  start <name>                      Create inception task + set focus"
    echo "  status                            Show all inception tasks"
    echo "  decide <T-XXX> go|no-go|defer     Record go/no-go decision"
    echo ""
    echo -e "${BOLD}Options:${NC}"
    echo "  start --owner <owner>             Set task owner (default: human)"
    echo "  decide --rationale '<reason>'     Required: explain the decision"
    echo ""
    echo -e "${BOLD}Examples:${NC}"
    echo "  fw inception start 'Evaluate notification system'"
    echo "  fw inception status"
    echo "  fw inception decide T-085 go --rationale 'All assumptions validated'"
    echo "  fw inception decide T-085 no-go --rationale 'Cost exceeds value'"
}

do_inception_start() {
    local name="${1:-}"
    shift || true

    if [ -z "$name" ]; then
        echo -e "${RED}Usage: fw inception start '<name>' [--owner <owner>]${NC}"
        exit 1
    fi

    # Parse optional args
    local owner="human"
    while [[ $# -gt 0 ]]; do
        case $1 in
            --owner) owner="$2"; shift 2 ;;
            *) shift ;;
        esac
    done

    # Create inception task using create-task.sh
    # T-554: Inception tasks start as captured (not started-work).
    # Use fw work-on T-XXX to explicitly start work when ready.
    local output
    output=$("$AGENTS_DIR/task-create/create-task.sh" \
        --name "$name" \
        --description "Inception: $name" \
        --type inception \
        --owner "$owner" 2>&1)

    echo "$output"

    # Extract task ID and set focus
    local task_id
    task_id=$(echo "$output" | grep "^ID:" | sed 's/ID:[[:space:]]*//')
    if [ -n "$task_id" ]; then
        "$AGENTS_DIR/context/context.sh" focus "$task_id"
        echo ""
        echo -e "${YELLOW}Next steps:${NC}"
        echo "1. Fill in Problem Statement, Constraints, Plan, Criteria"
        echo "2. Register assumptions:"
        echo "     fw assumption add 'Users want X' --task $task_id"
        echo "3. Conduct exploration (spikes, prototypes, research)"
        echo "4. Record decision:"
        echo "     fw inception decide $task_id go --rationale '...'"
    fi
}

do_inception_status() {
    python3 << 'PYINCEPTION'
import os, yaml

GREEN = '\033[0;32m'
YELLOW = '\033[1;33m'
CYAN = '\033[0;36m'
BOLD = '\033[1m'
NC = '\033[0m'

project_root = os.environ.get('PROJECT_ROOT', '.')
tasks = []

for status_dir in ['active', 'completed']:
    task_dir = os.path.join(project_root, '.tasks', status_dir)
    if not os.path.isdir(task_dir):
        continue
    for fn in sorted(os.listdir(task_dir)):
        if not fn.endswith('.md'):
            continue
        path = os.path.join(task_dir, fn)
        try:
            with open(path) as f:
                text = f.read()
            if not text.startswith('---'):
                continue
            end = text.index('---', 3)
            fm = yaml.safe_load(text[3:end]) or {}
            if fm.get('workflow_type') != 'inception':
                continue

            # Extract decision from body
            decision = 'pending'
            body = text[end+3:]
            for line in body.split('\n'):
                if line.startswith('**Decision**:'):
                    val = line.replace('**Decision**:', '').strip()
                    if val and val not in ('', '[GO / NO-GO / DEFER]'):
                        decision = val

            tasks.append({
                'id': fm.get('id', '?'),
                'name': fm.get('name', '?'),
                'status': fm.get('status', '?'),
                'decision': decision,
                'dir': status_dir,
            })
        except Exception:
            continue

if not tasks:
    print(f'{YELLOW}No inception tasks found{NC}')
    print('Create one with: fw inception start "<name>"')
else:
    active = [t for t in tasks if t['dir'] == 'active']
    completed = [t for t in tasks if t['dir'] == 'completed']

    print(f'{BOLD}Inception Tasks{NC} ({len(active)} active, {len(completed)} completed)')
    print()
    print(f'  {"ID":<8} {"Status":<16} {"Decision":<10} {"Name"}')
    print(f'  {"─"*8} {"─"*16} {"─"*10} {"─"*40}')
    for t in tasks:
        sc = GREEN if t['status'] == 'work-completed' else CYAN
        print(f'  {t["id"]:<8} {sc}{t["status"]:<16}{NC} {t["decision"]:<10} {t["name"]}')
PYINCEPTION
}

do_inception_decide() {
    local task_id="${1:-}"
    local decision="${2:-}"
    shift 2 2>/dev/null || true

    if [ -z "$task_id" ] || [ -z "$decision" ]; then
        echo -e "${RED}Usage: fw inception decide T-XXX go --rationale 'reason'${NC}"
        exit 1
    fi

    # Validate decision value
    case "$decision" in
        go|no-go|defer) ;;
        *)
            echo -e "${RED}Decision must be: go, no-go, or defer${NC}"
            exit 1
            ;;
    esac

    # Parse rationale
    local rationale=""
    while [[ $# -gt 0 ]]; do
        case $1 in
            --rationale) rationale="$2"; shift 2 ;;
            *) shift ;;
        esac
    done

    if [ -z "$rationale" ]; then
        echo -e "${RED}Rationale required: --rationale 'explanation'${NC}"
        exit 1
    fi

    # Find task file
    local task_file
    task_file=$(find_task_file "$task_id" active)
    if [ -z "$task_file" ]; then
        echo -e "${RED}Task $task_id not found in active tasks${NC}"
        exit 1
    fi

    # Verify it's an inception task
    if ! grep -q "workflow_type: inception" "$task_file"; then
        echo -e "${RED}$task_id is not an inception task${NC}"
        exit 1
    fi

    # Gate: placeholder audit chokepoint (T-1111/T-1113). Runs FIRST so that
    # a task edited between review-marker creation and decide-time still
    # catches bleed-through. If the marker exists from a previous review
    # but the task was later edited to introduce placeholders, this blocks.
    if [ -f "$FW_LIB_DIR/task-audit.sh" ]; then
        source "$FW_LIB_DIR/task-audit.sh"
        if ! audit_task_placeholders "$task_file"; then
            exit 1
        fi
    fi

    # Gate: require fw task review before accepting decision (T-973)
    local review_marker="$PROJECT_ROOT/.context/working/.reviewed-$task_id"
    if [ ! -f "$review_marker" ]; then
        echo -e "${RED}ERROR: Task review required before decision${NC}" >&2
        echo "" >&2
        echo -e "Run this first:" >&2
        echo -e "  $(_emit_user_command "task review $task_id")" >&2
        echo "" >&2
        echo -e "Then re-run the decide command." >&2
        exit 1
    fi

    # Gate: require ## Recommendation with actual content (T-974)
    local has_recommendation=false
    if grep -q '^## Recommendation' "$task_file"; then
        # Check it has content beyond just comments/placeholders
        local rec_content
        rec_content=$(sed -n '/^## Recommendation/,/^## /p' "$task_file" | grep -v '^## ' | grep -v '^<!--' | grep -v '^\-\->' | grep -v '^$' | head -1)
        if [ -n "$rec_content" ]; then
            has_recommendation=true
        fi
    fi
    if ! $has_recommendation; then
        echo -e "${RED}ERROR: ## Recommendation section required before decision${NC}" >&2
        echo "" >&2
        echo -e "The task file must contain a ## Recommendation section with:" >&2
        echo -e "  **Recommendation:** GO / NO-GO / DEFER" >&2
        echo -e "  **Rationale:** Why (cite evidence)" >&2
        echo -e "  **Evidence:** Bullet list of findings" >&2
        echo "" >&2
        echo -e "Watchtower reads this section — without it, the human sees no recommendation." >&2
        echo -e "Write the recommendation, then re-run this command." >&2
        exit 1
    fi

    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local decision_upper
    decision_upper=$(echo "$decision" | tr '[:lower:]' '[:upper:]')

    # Update Decision section via Python
    python3 - "$task_file" "$decision_upper" "$rationale" "$timestamp" << 'PYDECIDE'
import sys

task_file, decision, rationale, timestamp = sys.argv[1:5]

with open(task_file, 'r') as f:
    content = f.read()

# Find the Decision section and replace its content
lines = content.split('\n')
new_lines = []
in_decision = False
decision_written = False

for line in lines:
    if line.startswith('## Decision'):
        in_decision = True
        new_lines.append(line)
        new_lines.append('')
        new_lines.append(f'**Decision**: {decision}')
        new_lines.append(f'')
        new_lines.append(f'**Rationale**: {rationale}')
        new_lines.append(f'')
        new_lines.append(f'**Date**: {timestamp}')
        decision_written = True
        continue
    if in_decision:
        if line.startswith('## '):
            in_decision = False
            new_lines.append('')
            new_lines.append(line)
        # Skip old decision content
        continue
    new_lines.append(line)

with open(task_file, 'w') as f:
    f.write('\n'.join(new_lines))
PYDECIDE

    # Add update entry
    cat >> "$task_file" << EOF

### $timestamp — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** $decision_upper
- **Rationale:** $rationale
EOF

    # Complete task if go or no-go (not defer)
    # --skip-sovereignty bypasses only R-033 (sovereignty gate) because inception decide
    # itself required Tier 0 approval — human authority was already exercised (T-637).
    # P-010 (AC gate) and P-011 (verification gate) are NOT bypassed (T-1101/T-1142).
    if [ "$decision" = "go" ] || [ "$decision" = "no-go" ]; then
        echo ""
        "$AGENTS_DIR/task-create/update-task.sh" "$task_id" --status work-completed --skip-sovereignty --reason "Inception decision: $decision_upper" 2>&1
    fi

    # Clean up review marker (T-973)
    rm -f "$PROJECT_ROOT/.context/working/.reviewed-$task_id" 2>/dev/null || true

    echo ""
    echo -e "${GREEN}Inception decision recorded${NC}"
    echo "Task: $task_id"
    echo "Decision: $decision_upper"

    # T-634: Auto-emit review (URL + QR + artifacts) after decision
    if [ -f "$FW_LIB_DIR/review.sh" ]; then
        source "$FW_LIB_DIR/review.sh"
        emit_review "$task_id" "$task_file"
    fi

    if [ "$decision" = "go" ]; then
        echo -e "${YELLOW}Next: Create build tasks for implementation${NC}"
    elif [ "$decision" = "no-go" ]; then
        echo -e "${YELLOW}Next: Capture learnings from exploration (fw context add-learning)${NC}"
    else
        echo -e "${YELLOW}Next: Continue exploration and decide when ready${NC}"
    fi
}
