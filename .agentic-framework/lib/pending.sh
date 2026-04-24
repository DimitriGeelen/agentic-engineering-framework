#!/bin/bash
# fw pending - Pending-updates registry (T-1268 B1)
# Append-only ledger of cross-project / cross-machine actions an agent could
# not complete in-session. Resolved entries are flagged, not deleted.

PENDING_FILE="$PROJECT_ROOT/.context/working/pending-updates.yaml"

do_pending() {
    local subcmd="${1:-}"
    shift || true

    case "$subcmd" in
        register)
            do_pending_register "$@"
            ;;
        list)
            do_pending_list "$@"
            ;;
        resolve)
            do_pending_resolve "$@"
            ;;
        remind)
            do_pending_remind "$@"
            ;;
        ""|-h|--help|help)
            show_pending_help
            ;;
        *)
            echo -e "${RED}Unknown pending subcommand: $subcmd${NC}" >&2
            show_pending_help
            exit 1
            ;;
    esac
}

show_pending_help() {
    cat <<'EOF'
fw pending — Pending-updates registry (T-1268)

Subcommands:
  register   Record an action the agent could not complete in-session
  list       Show pending (default) or all entries
  resolve    Mark an entry as resolved
  remind     Ping for entries older than FW_PENDING_REMIND_STALE_HOURS (default 24)

Examples:
  fw pending register --command "cd /path && .agentic-framework/bin/fw upgrade" \
                      --reason "update propagation to consumer" \
                      --task T-1397 \
                      --host 192.168.10.107
  fw pending list
  fw pending list --status all
  fw pending resolve U-001 --note "human ran the command on .107"
EOF
}

ensure_pending_file() {
    if [ ! -f "$PENDING_FILE" ]; then
        mkdir -p "$(dirname "$PENDING_FILE")"
        cat > "$PENDING_FILE" <<'EOFPEND'
# Pending-updates registry (T-1268 B1)
# Append-only ledger of actions an agent could not complete in-session.
# Lifecycle: pending -> resolved. Resolved entries are kept (telemetry).
#
# Populated by: fw pending register
# Read by:      fw pending list, fw doctor (B2), Watchtower /pending (B3)

pending_updates: []
EOFPEND
    fi
}

do_pending_register() {
    local command="" reason="" task="" host=""
    while [[ $# -gt 0 ]]; do
        case $1 in
            --command) command="$2"; shift 2 ;;
            --reason)  reason="$2";  shift 2 ;;
            --task)    task="$2";    shift 2 ;;
            --host)    host="$2";    shift 2 ;;
            -h|--help)
                cat <<'EOF'
fw pending register — record a blocked action

Required:
  --command CMD   Copy-pasteable shell command that would complete the action
  --reason WHY    One-line reason it could not run in-session
  --task T-XXX    Task id the action belongs to

Optional:
  --host HOST     Target host (e.g. hostname, IP, "local", "cross-project")
EOF
                return 0
                ;;
            *) shift ;;
        esac
    done

    if [ -z "$command" ] || [ -z "$reason" ] || [ -z "$task" ]; then
        echo -e "${RED}Usage: fw pending register --command CMD --reason WHY --task T-XXX [--host HOST]${NC}" >&2
        return 1
    fi

    ensure_pending_file

    local agent="${FW_AGENT_TAG:-agent}"
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    python3 - "$PENDING_FILE" "$command" "$reason" "$task" "${host:-}" "$agent" "$timestamp" <<'PYPEND'
import sys
import yaml

pending_file, command, reason, task, host, agent, ts = sys.argv[1:8]

with open(pending_file) as f:
    data = yaml.safe_load(f) or {}

entries = data.get('pending_updates') or []
max_id = 0
for e in entries:
    eid = e.get('id') or ''
    if eid.startswith('U-'):
        try:
            n = int(eid[2:])
            if n > max_id:
                max_id = n
        except ValueError:
            pass

next_id = f"U-{max_id + 1:03d}"
entries.append({
    'id': next_id,
    'command': command,
    'reason': reason,
    'task': task,
    'host': host or 'local',
    'agent': agent,
    'created': ts,
    'status': 'pending',
    'resolved_date': None,
    'resolution_note': None,
})
data['pending_updates'] = entries

with open(pending_file, 'w') as f:
    yaml.dump(data, f, default_flow_style=False, sort_keys=False, allow_unicode=True)

print(next_id)
PYPEND
}

do_pending_list() {
    local filter="pending"
    while [[ $# -gt 0 ]]; do
        case $1 in
            --status) filter="$2"; shift 2 ;;
            -h|--help)
                echo "Usage: fw pending list [--status pending|resolved|all]"
                return 0
                ;;
            *) shift ;;
        esac
    done

    if [ ! -f "$PENDING_FILE" ]; then
        echo "(no pending-updates registry — use 'fw pending register' to create the first entry)"
        return 0
    fi

    FW_PENDING_FILE="$PENDING_FILE" FW_PENDING_FILTER="$filter" python3 - <<'PYLIST'
import os
import yaml

pending_file = os.environ['FW_PENDING_FILE']
status_filter = os.environ['FW_PENDING_FILTER']

with open(pending_file) as f:
    data = yaml.safe_load(f) or {}

entries = data.get('pending_updates') or []
if status_filter != 'all':
    entries = [e for e in entries if (e.get('status') or 'pending') == status_filter]

if not entries:
    print(f"(no entries with status={status_filter})")
    raise SystemExit(0)

for e in entries:
    print(f"{e.get('id','?')} [{e.get('status','pending')}] task={e.get('task','-')} host={e.get('host','-')}")
    print(f"  reason:  {e.get('reason','')}")
    print(f"  command: {e.get('command','')}")
    print(f"  created: {e.get('created','-')}")
    if e.get('status') == 'resolved':
        print(f"  resolved: {e.get('resolved_date','-')}")
        if e.get('resolution_note'):
            print(f"  note:    {e.get('resolution_note','')}")
    print()
PYLIST
}

do_pending_resolve() {
    local entry_id="${1:-}"
    shift || true
    local note=""
    while [[ $# -gt 0 ]]; do
        case $1 in
            --note) note="$2"; shift 2 ;;
            -h|--help)
                echo "Usage: fw pending resolve U-NNN [--note 'outcome']"
                return 0
                ;;
            *) shift ;;
        esac
    done

    if [ -z "$entry_id" ]; then
        echo -e "${RED}Usage: fw pending resolve U-NNN [--note 'outcome']${NC}" >&2
        return 1
    fi

    if [ ! -f "$PENDING_FILE" ]; then
        echo -e "${RED}No pending-updates registry exists${NC}" >&2
        return 1
    fi

    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    python3 - "$PENDING_FILE" "$entry_id" "$note" "$timestamp" <<'PYRESOLVE'
import sys
import yaml

pending_file, entry_id, note, ts = sys.argv[1:5]

with open(pending_file) as f:
    data = yaml.safe_load(f) or {}

entries = data.get('pending_updates') or []
found = False
for e in entries:
    if e.get('id') == entry_id:
        e['status'] = 'resolved'
        e['resolved_date'] = ts
        if note:
            e['resolution_note'] = note
        found = True
        break

if not found:
    print(f"ERROR: entry {entry_id} not found", file=sys.stderr)
    raise SystemExit(1)

data['pending_updates'] = entries
with open(pending_file, 'w') as f:
    yaml.dump(data, f, default_flow_style=False, sort_keys=False, allow_unicode=True)

print(f"Resolved: {entry_id}")
PYRESOLVE
}

do_pending_remind() {
    local stale_hours="${FW_PENDING_REMIND_STALE_HOURS:-24}"

    if [ ! -f "$PENDING_FILE" ]; then
        echo "No pending-updates registry — nothing to remind about"
        return 0
    fi

    # Returns: <count>|<first_id>|<first_task>|<summary_block>
    local summary
    summary=$(FW_PENDING_FILE="$PENDING_FILE" FW_STALE_HOURS="$stale_hours" python3 - <<'PYREMIND'
import os
import sys
from datetime import datetime, timezone, timedelta
import yaml

pending_file = os.environ['FW_PENDING_FILE']
stale_hours = int(os.environ['FW_STALE_HOURS'])

with open(pending_file) as f:
    data = yaml.safe_load(f) or {}

entries = data.get('pending_updates') or []
cutoff = datetime.now(timezone.utc) - timedelta(hours=stale_hours)

stale = []
for e in entries:
    if (e.get('status') or 'pending') != 'pending':
        continue
    created = e.get('created')
    if not created:
        continue
    try:
        dt = datetime.fromisoformat(str(created).replace('Z', '+00:00'))
    except ValueError:
        continue
    if dt < cutoff:
        stale.append(e)

if not stale:
    print("0||")
    sys.exit(0)

lines = []
for e in stale:
    lines.append(f"  {e.get('id','?')} [{e.get('task','-')}] age>={stale_hours}h  {e.get('reason','')}")

first = stale[0]
print(f"{len(stale)}|{first.get('id','?')}|{first.get('task','-')}")
for line in lines:
    print(line)
PYREMIND
)

    local count first_id first_task rest
    count=$(echo "$summary" | head -1 | cut -d'|' -f1)
    first_id=$(echo "$summary" | head -1 | cut -d'|' -f2)
    first_task=$(echo "$summary" | head -1 | cut -d'|' -f3)
    rest=$(echo "$summary" | tail -n +2)

    if [ "${count:-0}" -eq 0 ]; then
        echo "No stale pending entries (stale threshold: ${stale_hours}h)"
        return 0
    fi

    echo "Stale pending entries (>= ${stale_hours}h, status=pending):"
    echo "$rest"
    echo ""
    echo "Total: $count. Resolve with: fw pending resolve <U-NNN>"

    # Fire notification if enabled
    if [ "${NTFY_ENABLED:-}" = "true" ]; then
        if [ -f "$FRAMEWORK_ROOT/lib/notify.sh" ]; then
            # shellcheck disable=SC1091
            source "$FRAMEWORK_ROOT/lib/notify.sh"
            fw_notify \
                "Pending-updates: $count stale entr(y|ies)" \
                "$count entries older than ${stale_hours}h. First: $first_id (task $first_task). Run: fw pending list" \
                "pending-remind" \
                "framework" || true
        fi
    fi
}
