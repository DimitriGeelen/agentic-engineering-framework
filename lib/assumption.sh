#!/bin/bash
# fw assumption - Assumption tracking
# Manages project assumptions: register, validate, invalidate, list

ASSUMPTIONS_FILE="$PROJECT_ROOT/.context/project/assumptions.yaml"

do_assumption() {
    local subcmd="${1:-}"
    shift || true

    case "$subcmd" in
        add)
            do_assumption_add "$@"
            ;;
        validate)
            do_assumption_update "validated" "$@"
            ;;
        invalidate)
            do_assumption_update "invalidated" "$@"
            ;;
        list)
            do_assumption_list "$@"
            ;;
        ""|-h|--help)
            show_assumption_help
            ;;
        *)
            echo -e "${RED}Unknown assumption subcommand: $subcmd${NC}"
            show_assumption_help
            exit 1
            ;;
    esac
}

show_assumption_help() {
    echo -e "${BOLD}fw assumption${NC} - Assumption tracking"
    echo ""
    echo -e "${BOLD}Commands:${NC}"
    echo "  add '<statement>' --task T-XXX     Register an assumption"
    echo "  validate A-XXX --evidence '...'    Mark assumption as validated"
    echo "  invalidate A-XXX --evidence '...'  Mark assumption as invalidated"
    echo "  list [--status <status>]           List assumptions"
    echo ""
    echo -e "${BOLD}Examples:${NC}"
    echo "  fw assumption add 'Users want real-time notifications' --task T-015"
    echo "  fw assumption validate A-001 --evidence 'User survey confirmed 8/10'"
    echo "  fw assumption invalidate A-002 --evidence 'Load test showed SQLite caps at 1K'"
    echo "  fw assumption list --status untested"
}

ensure_assumptions_file() {
    if [ ! -f "$ASSUMPTIONS_FILE" ]; then
        mkdir -p "$(dirname "$ASSUMPTIONS_FILE")"
        cat > "$ASSUMPTIONS_FILE" << 'EOFASSUMPTIONS'
# Assumptions Register
# Key assumptions made during inception phases
# Tracks validation status and evidence
#
# Lifecycle: untested -> validated | invalidated
# Validated assumptions become project knowledge
# Invalidated assumptions become gaps or risks

assumptions: []
EOFASSUMPTIONS
    fi
}

do_assumption_add() {
    local statement="${1:-}"
    shift || true

    if [ -z "$statement" ]; then
        echo -e "${RED}Usage: fw assumption add '<statement>' --task T-XXX${NC}"
        exit 1
    fi

    # Parse args
    local task=""
    while [[ $# -gt 0 ]]; do
        case $1 in
            --task) task="$2"; shift 2 ;;
            *) shift ;;
        esac
    done

    if [ -z "$task" ]; then
        echo -e "${RED}Task ID required: --task T-XXX${NC}"
        exit 1
    fi

    ensure_assumptions_file

    local timestamp
    timestamp=$(date -u +"%Y-%m-%d")

    # Add assumption via Python
    python3 - "$ASSUMPTIONS_FILE" "$statement" "$task" "$timestamp" << 'PYADD'
import sys, yaml

assumptions_file, statement, task, timestamp = sys.argv[1:5]

with open(assumptions_file, 'r') as f:
    data = yaml.safe_load(f) or {}

assumptions = data.get('assumptions', [])

# Generate next ID
max_id = 0
for a in assumptions:
    aid = a.get('id', '')
    if aid.startswith('A-'):
        try:
            num = int(aid[2:])
            if num > max_id:
                max_id = num
        except ValueError:
            pass

next_id = f"A-{max_id + 1:03d}"

assumptions.append({
    'id': next_id,
    'statement': statement,
    'status': 'untested',
    'validation_method': 'TBD',
    'evidence': [],
    'linked_task': task,
    'created': timestamp,
    'resolved_date': None,
})

data['assumptions'] = assumptions

with open(assumptions_file, 'w') as f:
    yaml.dump(data, f, default_flow_style=False, sort_keys=False, allow_unicode=True)

print(next_id)
PYADD

    local new_id
    new_id=$(python3 -c "
import yaml
with open('$ASSUMPTIONS_FILE') as f:
    data = yaml.safe_load(f) or {}
assumptions = data.get('assumptions', [])
if assumptions:
    print(assumptions[-1].get('id', '?'))
")

    echo -e "${GREEN}Assumption registered${NC}"
    echo "ID:        $new_id"
    echo "Statement: $statement"
    echo "Task:      $task"
    echo "Status:    untested"
    echo ""
    echo "Next: Set validation method in $ASSUMPTIONS_FILE"
}

do_assumption_update() {
    local new_status="$1"
    local assumption_id="${2:-}"
    shift 2 2>/dev/null || true

    if [ -z "$assumption_id" ]; then
        echo -e "${RED}Usage: fw assumption ${new_status%d} A-XXX --evidence 'details'${NC}"
        exit 1
    fi

    # Parse evidence
    local evidence=""
    while [[ $# -gt 0 ]]; do
        case $1 in
            --evidence) evidence="$2"; shift 2 ;;
            *) shift ;;
        esac
    done

    if [ -z "$evidence" ]; then
        echo -e "${RED}Evidence required: --evidence 'what proved/disproved this'${NC}"
        exit 1
    fi

    if [ ! -f "$ASSUMPTIONS_FILE" ]; then
        echo -e "${RED}No assumptions file found${NC}"
        exit 1
    fi

    local timestamp
    timestamp=$(date -u +"%Y-%m-%d")

    # Update via Python
    python3 - "$ASSUMPTIONS_FILE" "$assumption_id" "$new_status" "$evidence" "$timestamp" << 'PYUPDATE'
import sys, yaml

assumptions_file, assumption_id, new_status, evidence, timestamp = sys.argv[1:6]

with open(assumptions_file, 'r') as f:
    data = yaml.safe_load(f) or {}

found = False
for a in data.get('assumptions', []):
    if a.get('id') == assumption_id:
        a['status'] = new_status
        a['resolved_date'] = timestamp
        if 'evidence' not in a or a['evidence'] is None:
            a['evidence'] = []
        a['evidence'].append({'outcome': evidence, 'date': timestamp})
        found = True
        break

if not found:
    print(f"ERROR: {assumption_id} not found", file=sys.stderr)
    sys.exit(1)

with open(assumptions_file, 'w') as f:
    yaml.dump(data, f, default_flow_style=False, sort_keys=False, allow_unicode=True)

print(f"Updated: {assumption_id} -> {new_status}")
PYUPDATE

    echo -e "${GREEN}Assumption updated${NC}"
    echo "ID:       $assumption_id"
    echo "Status:   $new_status"
    echo "Evidence: $evidence"
}

do_assumption_list() {
    local status_filter=""
    while [[ $# -gt 0 ]]; do
        case $1 in
            --status) status_filter="$2"; shift 2 ;;
            *) shift ;;
        esac
    done

    if [ ! -f "$ASSUMPTIONS_FILE" ]; then
        echo -e "${YELLOW}No assumptions registered yet${NC}"
        echo "Create one with: fw assumption add '<statement>' --task T-XXX"
        exit 0
    fi

    python3 - "$ASSUMPTIONS_FILE" "$status_filter" << 'PYLIST'
import sys, yaml

assumptions_file, status_filter = sys.argv[1:3]

GREEN = '\033[0;32m'
RED = '\033[0;31m'
YELLOW = '\033[1;33m'
BOLD = '\033[1m'
NC = '\033[0m'

with open(assumptions_file) as f:
    data = yaml.safe_load(f) or {}

assumptions = data.get('assumptions', [])
if status_filter:
    assumptions = [a for a in assumptions if a.get('status') == status_filter]

if not assumptions:
    if status_filter:
        print(f'{YELLOW}No assumptions with status "{status_filter}"{NC}')
    else:
        print(f'{YELLOW}No assumptions registered{NC}')
    sys.exit(0)

# Count by status
counts = {}
for a in data.get('assumptions', []):
    s = a.get('status', 'unknown')
    counts[s] = counts.get(s, 0) + 1
summary = ', '.join(f'{v} {k}' for k, v in counts.items())

print(f'{BOLD}Assumptions{NC} ({summary})')
print()
print(f'  {"ID":<8} {"Status":<14} {"Task":<8} {"Statement"}')
print(f'  {"─"*8} {"─"*14} {"─"*8} {"─"*50}')

for a in assumptions:
    aid = a.get('id', '?')
    status = a.get('status', '?')
    task = a.get('linked_task', '?')
    statement = a.get('statement', '?')
    stmt_display = statement[:50] + ('...' if len(statement) > 50 else '')

    if status == 'validated':
        sc = GREEN
    elif status == 'invalidated':
        sc = RED
    else:
        sc = YELLOW
    print(f'  {aid:<8} {sc}{status:<14}{NC} {task:<8} {stmt_display}')
PYLIST
}
