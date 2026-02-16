#!/bin/bash
# fw inception - Inception phase workflow
# Manages exploration-phase work: problem definition, assumptions, go/no-go

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
    local output
    output=$("$AGENTS_DIR/task-create/create-task.sh" \
        --name "$name" \
        --description "Inception: $name" \
        --type inception \
        --owner "$owner" \
        --start 2>&1)

    echo "$output"

    # Extract task ID and set focus
    local task_id
    task_id=$(echo "$output" | grep "^ID:" | sed 's/ID:[[:space:]]*//')
    if [ -n "$task_id" ]; then
        "$AGENTS_DIR/context/context.sh" focus "$task_id"
        echo ""
        echo -e "${YELLOW}Next steps:${NC}"
        echo "1. Fill in Problem Statement, Exploration Plan, Go/No-Go Criteria"
        echo "2. Register assumptions: fw assumption add 'Users want X' --task $task_id"
        echo "3. Conduct exploration (spikes, prototypes, research)"
        echo "4. Record decision: fw inception decide $task_id go|no-go --rationale '...'"
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
        echo -e "${RED}Usage: fw inception decide T-XXX go|no-go|defer --rationale 'reason'${NC}"
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
    task_file=$(find "$PROJECT_ROOT/.tasks/active" -name "${task_id}-*.md" -type f 2>/dev/null | head -1)
    if [ -z "$task_file" ]; then
        echo -e "${RED}Task $task_id not found in active tasks${NC}"
        exit 1
    fi

    # Verify it's an inception task
    if ! grep -q "workflow_type: inception" "$task_file"; then
        echo -e "${RED}$task_id is not an inception task${NC}"
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
    if [ "$decision" = "go" ] || [ "$decision" = "no-go" ]; then
        echo ""
        "$AGENTS_DIR/task-create/update-task.sh" "$task_id" --status work-completed --reason "Inception decision: $decision_upper" 2>&1
    fi

    echo ""
    echo -e "${GREEN}Inception decision recorded${NC}"
    echo "Task: $task_id"
    echo "Decision: $decision_upper"
    echo ""

    if [ "$decision" = "go" ]; then
        echo -e "${YELLOW}Next: Create build tasks for implementation${NC}"
    elif [ "$decision" = "no-go" ]; then
        echo -e "${YELLOW}Next: Capture learnings from exploration (fw context add-learning)${NC}"
    else
        echo -e "${YELLOW}Next: Continue exploration and decide when ready${NC}"
    fi
}
