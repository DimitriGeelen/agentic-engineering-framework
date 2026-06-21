#!/bin/bash
# Observe Agent - Lightweight observation capture
# The fastest path from "I noticed something" to "it's recorded"
#
# Usage:
#   ./agents/observe/observe.sh "observation text"           # Capture
#   ./agents/observe/observe.sh "text" --tag bug --task T-XX # Capture with context
#   ./agents/observe/observe.sh list                         # Show pending
#   ./agents/observe/observe.sh count                        # Pending count
#   ./agents/observe/observe.sh promote OBS-001              # Promote to task
#   ./agents/observe/observe.sh dismiss OBS-001 --reason "..." # Dismiss
#   ./agents/observe/observe.sh triage                       # Interactive review

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$FRAMEWORK_ROOT/lib/paths.sh"
INBOX_FILE="$PROJECT_ROOT/.context/inbox.yaml"

# Colors provided by lib/colors.sh (via paths.sh chain)

ensure_inbox() {
    mkdir -p "$(dirname "$INBOX_FILE")"
    if [ ! -f "$INBOX_FILE" ]; then
        cat > "$INBOX_FILE" << 'EOF'
# Observation Inbox - Unprocessed observations
# Capture: fw note "text"
# Review:  fw note list
# Triage:  fw note triage
observations: []
EOF
    fi
}

next_id() {
    local max=0
    if [ -f "$INBOX_FILE" ]; then
        local found
        found=$(grep -oE 'OBS-[0-9]+' "$INBOX_FILE" 2>/dev/null | grep -oE '[0-9]+' | sort -n | tail -1 || true)
        [ -n "$found" ] && max=$((10#$found))
    fi
    printf "OBS-%03d" $((max + 1))
}

# Auto-detect current focus task
get_focus_task() {
    local focus_file="$PROJECT_ROOT/.context/working/focus.yaml"
    if [ -f "$focus_file" ]; then
        grep "^current_task:" "$focus_file" 2>/dev/null | sed 's/current_task:[[:space:]]*//' | tr -d '"' || true
    fi
}

# --- Commands ---

do_capture() {
    ensure_inbox
    local text="$1"
    shift || true

    local task="" tags="" urgent=false
    while [ $# -gt 0 ]; do
        case "$1" in
            --task|-t)   task="$2"; shift 2 ;;
            --tag)       tags="$2"; shift 2 ;;
            --urgent|-u) urgent=true; shift ;;
            *) shift ;;
        esac
    done

    # Auto-detect task context if not provided
    if [ -z "$task" ]; then
        task=$(get_focus_task)
    fi

    local id
    id=$(next_id)
    local ts
    ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # Replace empty array marker
    _sed_i 's/^observations: \[\]/observations:/' "$INBOX_FILE"

    local urgent_field=""
    if [ "$urgent" = true ]; then
        urgent_field="  urgent: true"
    fi

    # T-2456 (OBS-084): escape $text for a YAML double-quoted scalar before
    # writing. A raw backslash in the note body (e.g. a regex like '\d+') or an
    # embedded double-quote would otherwise corrupt inbox.yaml: YAML double-quotes
    # process backslash escapes, so an unescaped '\d' is an "unknown escape"
    # ScannerError that crashes EVERY `fw note list/triage` (yaml.safe_load) — the
    # whole inbox goes unreadable. Order matters: backslashes first, then quotes.
    # Origin: OBS-081's '- **IW-(\d+):' (filed via `fw note`) broke the inbox for
    # ~a day. Both readers stay happy — yaml.safe_load unescapes correctly, and the
    # sed reader (do_resolve) still strips the surrounding quotes.
    local text_yaml
    text_yaml=${text//\\/\\\\}        # \  -> \\
    text_yaml=${text_yaml//\"/\\\"}   # "  -> \"

    cat >> "$INBOX_FILE" << EOF
- id: $id
  text: "$text_yaml"
  captured: $ts
  context_task: ${task:-null}
  tags: [${tags}]
  status: pending
  promoted_to: null
EOF

    if [ -n "$urgent_field" ]; then
        echo "$urgent_field" >> "$INBOX_FILE"
    fi

    if [ "$urgent" = true ]; then
        echo -e "${GREEN}$id${NC} ${RED}[URGENT]${NC} captured: \"$text\""
    else
        echo -e "${GREEN}$id${NC} captured: \"$text\""
    fi
    [ -n "$task" ] && echo -e "  context: $task"
}

do_list() {
    ensure_inbox
    local pending
    pending=$(grep -c 'status: pending' "$INBOX_FILE" 2>/dev/null) || pending=0

    if [ "$pending" -eq 0 ]; then
        echo -e "${GREEN}Inbox empty${NC} — no pending observations"
        return
    fi

    echo -e "${BOLD}Observation Inbox${NC} ($pending pending)"
    echo ""

    # Parse and display pending observations (T-2317: yaml.safe_load — was re.split which
    # drifted from the heredoc format and matched tag boundaries as OBS boundaries).
    python3 << PYEOF
import yaml

with open("$INBOX_FILE", "r") as f:
    data = yaml.safe_load(f) or {}

for obs in data.get('observations', []) or []:
    if obs.get('status') != 'pending':
        continue
    obs_id = obs.get('id', '')
    text = obs.get('text', '')
    task = obs.get('context_task')
    tags = obs.get('tags') or []
    urgent = obs.get('urgent') is True

    prefix = "  \033[0;31m[URGENT]\033[0m " if urgent else "  "
    tag_str = f" [{', '.join(tags)}]" if tags else ""
    task_str = f" ({task})" if task and task != "null" else ""
    print(f"{prefix}\033[0;36m{obs_id}\033[0m{tag_str}  {text}{task_str}")
PYEOF
}

do_count() {
    ensure_inbox
    local pending
    pending=$(grep -c 'status: pending' "$INBOX_FILE" 2>/dev/null) || pending=0
    local urgent
    urgent=$(grep -c 'urgent: true' "$INBOX_FILE" 2>/dev/null) || urgent=0

    if [ "$urgent" -gt 0 ]; then
        echo "$pending pending ($urgent urgent)"
    else
        echo "$pending pending"
    fi
}

do_promote() {
    local obs_id=""
    local task_type="build"
    while [ $# -gt 0 ]; do
        case "$1" in
            --type|-t) task_type="$2"; shift 2 ;;
            -h|--help)
                echo "Usage: fw note promote OBS-NNN [--type <build|inception|...>]"
                return 0 ;;
            -*)
                echo -e "${RED}Unknown flag: $1${NC}" >&2
                echo "Usage: fw note promote OBS-NNN [--type <build|inception|...>]" >&2
                return 1 ;;
            *)
                if [ -z "$obs_id" ]; then obs_id="$1"; else
                    echo -e "${RED}Unexpected argument: $1${NC}" >&2; return 1
                fi
                shift ;;
        esac
    done
    if [ -z "$obs_id" ]; then
        echo -e "${RED}Usage: fw note promote OBS-NNN [--type <build|inception|...>]${NC}" >&2
        return 1
    fi

    ensure_inbox

    local text
    # Pipeline tolerant of empty matches (set -euo pipefail otherwise kills
    # the script silently when the observation doesn't exist — T-1458).
    text=$(grep -A1 "id: $obs_id" "$INBOX_FILE" 2>/dev/null | grep 'text:' | sed 's/.*text: "//;s/"$//' || true)

    if [ -z "$text" ]; then
        echo -e "${RED}Observation $obs_id not found${NC}" >&2
        return 1
    fi

    echo -e "${YELLOW}Promoting $obs_id to task (type: $task_type)...${NC}"
    echo ""

    # Create task
    PROJECT_ROOT="$PROJECT_ROOT" "$FRAMEWORK_ROOT/agents/task-create/create-task.sh" \
        --name "$text" \
        --description "Promoted from observation $obs_id" \
        --type "$task_type" \
        --owner human

    # Mark as promoted
    _sed_i "/id: $obs_id/,/promoted_to:/{s/status: pending/status: promoted/;s/promoted_to: null/promoted_to: task/}" "$INBOX_FILE"

    echo ""
    echo -e "${GREEN}$obs_id promoted to task${NC}"
}

do_dismiss() {
    local obs_id="${1:-}"
    if [ -z "$obs_id" ]; then
        echo -e "${RED}Usage: fw note dismiss OBS-NNN [--reason \"...\"]${NC}" >&2
        return 1
    fi
    shift

    local reason="not actionable"
    while [ $# -gt 0 ]; do
        case "$1" in
            --reason) reason="$2"; shift 2 ;;
            *) shift ;;
        esac
    done

    ensure_inbox
    _sed_i "/id: $obs_id/,/promoted_to:/{s/status: pending/status: dismissed/}" "$INBOX_FILE"
    echo -e "${GREEN}$obs_id dismissed:${NC} $reason"
}

do_triage() {
    ensure_inbox
    local pending
    pending=$(grep -c 'status: pending' "$INBOX_FILE" 2>/dev/null) || pending=0

    if [ "$pending" -eq 0 ]; then
        echo -e "${GREEN}Nothing to triage${NC} — inbox is clean"
        return
    fi

    echo -e "${BOLD}Observation Triage${NC} — $pending pending"
    echo ""
    echo "For each observation, choose:"
    echo "  [p]romote to task  [d]ismiss  [s]kip"
    echo ""

    # List all pending for non-interactive review
    do_list
    echo ""
    echo -e "${YELLOW}Run individually:${NC}"
    echo "  fw note promote OBS-NNN"
    echo "  fw note dismiss OBS-NNN --reason \"...\""
}

show_help() {
    echo -e "${BOLD}fw note${NC} — Lightweight observation capture"
    echo ""
    echo "Usage:"
    echo "  fw note \"observation text\"              Capture an observation"
    echo "  fw note \"text\" --tag bug --task T-XXX   Capture with context"
    echo "  fw note \"text\" --urgent                 Flag as urgent"
    echo "  fw note list                             Show pending observations"
    echo "  fw note count                            Pending count (for prompts)"
    echo "  fw note triage                           Review pending observations"
    echo "  fw note promote OBS-NNN [--type T]       Promote to task (default type: build)"
    echo "  fw note dismiss OBS-NNN --reason \"...\"   Dismiss with reason"
    echo ""
    echo "The inbox lives at: .context/inbox.yaml"
}

# --- Main ---

case "${1:-}" in
    list)       do_list ;;
    count)      do_count ;;
    triage)     do_triage ;;
    promote)    shift; do_promote "$@" ;;
    dismiss)    shift; do_dismiss "$@" ;;
    -h|--help|help)  show_help ;;
    "")         show_help; exit 1 ;;
    -*)
        echo -e "${RED}Unknown flag: $1${NC}" >&2
        echo "Run 'fw note --help' for usage" >&2
        exit 1
        ;;
    *)          do_capture "$@" ;;
esac
