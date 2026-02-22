#!/bin/bash
# Resume Agent - Post-compaction recovery and state synchronization
# Synthesizes current state from handover, working memory, git, and tasks

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FRAMEWORK_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PROJECT_ROOT="${PROJECT_ROOT:-$FRAMEWORK_ROOT}"
TASKS_DIR="$PROJECT_ROOT/.tasks"
CONTEXT_DIR="$PROJECT_ROOT/.context"
HANDOVER_DIR="$CONTEXT_DIR/handovers"
WORKING_DIR="$CONTEXT_DIR/working"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

show_help() {
    echo "Resume Agent - Post-compaction recovery"
    echo ""
    echo "Usage: resume.sh <command>"
    echo ""
    echo "Commands:"
    echo "  status    Show synthesized current state (use after compaction)"
    echo "  sync      Update working memory from actual task state"
    echo "  quick     One-line summary for prompts"
    echo ""
    echo "Examples:"
    echo "  ./agents/resume/resume.sh status    # Full state synthesis"
    echo "  ./agents/resume/resume.sh sync      # Fix stale working memory"
    echo "  ./agents/resume/resume.sh quick     # Quick summary"
}

# Get active task count and list
get_active_tasks() {
    local count=0
    local tasks=""
    shopt -s nullglob
    for f in "$TASKS_DIR/active"/*.md; do
        [ -f "$f" ] || continue
        task_id=$(grep "^id:" "$f" | head -1 | cut -d: -f2 | tr -d ' ')
        task_name=$(grep "^name:" "$f" | head -1 | cut -d: -f2- | sed 's/^ *//')
        task_status=$(grep "^status:" "$f" | head -1 | cut -d: -f2 | tr -d ' ')
        if [ -n "$task_id" ]; then
            count=$((count + 1))
            tasks="$tasks  - $task_id: $task_name ($task_status)\n"
        fi
    done
    shopt -u nullglob
    echo "$count|$tasks"
}

# Get uncommitted changes
get_git_state() {
    local uncommitted=$(git -C "$PROJECT_ROOT" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
    local last_commit=$(git -C "$PROJECT_ROOT" log -1 --pretty=format:"%h %s" 2>/dev/null)
    local branch=$(git -C "$PROJECT_ROOT" branch --show-current 2>/dev/null)
    echo "$uncommitted|$last_commit|$branch"
}

# Get current focus from working memory
get_focus() {
    if [ -f "$WORKING_DIR/focus.yaml" ]; then
        grep "^current_task:" "$WORKING_DIR/focus.yaml" | cut -d: -f2 | tr -d ' '
    else
        echo ""
    fi
}

# Get session info from working memory
get_session() {
    if [ -f "$WORKING_DIR/session.yaml" ]; then
        grep "^session_id:" "$WORKING_DIR/session.yaml" | cut -d: -f2 | tr -d ' '
    else
        echo ""
    fi
}

# STATUS command - full synthesis
cmd_status() {
    echo -e "${CYAN}${BOLD}=== RESUME: Current State ===${NC}"
    echo ""

    # Session info
    local session_id=$(get_session)
    local focus=$(get_focus)
    echo -e "${BOLD}Session:${NC} ${session_id:-unknown}"
    echo -e "${BOLD}Focus:${NC} ${focus:-none}"
    echo ""

    # Git state
    IFS='|' read -r uncommitted last_commit branch <<< "$(get_git_state)"
    echo -e "${BOLD}Git:${NC}"
    echo "  Branch: $branch"
    echo "  Last commit: $last_commit"
    if [ "$uncommitted" -gt 0 ]; then
        echo -e "  ${YELLOW}Uncommitted changes: $uncommitted files${NC}"
    else
        echo -e "  ${GREEN}Working directory clean${NC}"
    fi
    echo ""

    # Active tasks
    IFS='|' read -r task_count task_list <<< "$(get_active_tasks)"
    echo -e "${BOLD}Active Tasks:${NC} $task_count"
    if [ "$task_count" -gt 0 ]; then
        echo -e "$task_list"
    else
        echo -e "  ${GREEN}No active tasks${NC}"
    fi
    echo ""

    # Handover summary
    if [ -f "$HANDOVER_DIR/LATEST.md" ]; then
        # Check for unfilled TODO placeholders
        local todo_count=$(grep -c "\[TODO\]" "$HANDOVER_DIR/LATEST.md" 2>/dev/null | tr -d "\n" || echo "0")
        if [ "$todo_count" -gt 0 ]; then
            echo -e "${YELLOW}⚠ Handover has $todo_count unfilled [TODO] placeholder(s) — may be incomplete${NC}"
        fi

        echo -e "${BOLD}Last Handover:${NC}"
        # Extract "Where We Are" section (first paragraph after header)
        local where_we_are=$(sed -n '/^## Where We Are/,/^##/p' "$HANDOVER_DIR/LATEST.md" | grep -v "^##" | head -5)
        if [ -n "$where_we_are" ]; then
            echo "$where_we_are" | sed 's/^/  /'
        fi

        # Extract suggested first action
        local suggested=$(sed -n '/^## Suggested First Action/,/^##/p' "$HANDOVER_DIR/LATEST.md" | grep -v "^##" | head -3)
        if [ -n "$suggested" ]; then
            echo ""
            echo -e "${BOLD}Suggested Action:${NC}"
            echo "$suggested" | sed 's/^/  /'
        fi

        # Check for untracked open questions (G-002)
        local open_questions=$(sed -n '/^## Open Questions/,/^## /p' "$HANDOVER_DIR/LATEST.md" | grep -E "^[0-9]+\.|^- " | grep -v "\[Question" | grep -v "\[TODO")
        if [ -n "$open_questions" ]; then
            local oq_count=$(echo "$open_questions" | wc -l | tr -d ' ')
            echo ""
            echo -e "${YELLOW}${BOLD}Unresolved Open Questions ($oq_count):${NC}"
            echo "$open_questions" | sed 's/^/  /'
            echo -e "  ${YELLOW}→ Register as gap ('fw gaps add') or task ('fw task create')${NC}"
        fi
    else
        echo -e "${YELLOW}No handover found${NC}"
    fi
    echo ""

    # Discovery findings (T-241)
    local disc_file="$PROJECT_ROOT/.context/audits/discoveries/LATEST.yaml"
    if [ -f "$disc_file" ]; then
        local disc_output
        disc_output=$(python3 -c "
import yaml, sys
with open('$disc_file') as f:
    data = yaml.safe_load(f)
if not data or 'findings' not in data:
    sys.exit(0)
ts = data.get('timestamp', '?')
s = data.get('summary', {})
items = [f for f in data['findings'] if f.get('level') in ('WARN', 'FAIL')]
print(f'Last run: {ts}  (P:{s.get(\"pass\",0)} W:{s.get(\"warn\",0)} F:{s.get(\"fail\",0)})')
for f in items:
    lvl = f['level']
    color = '\033[1;33m' if lvl == 'WARN' else '\033[0;31m'
    nc = '\033[0m'
    print(f'  {color}[{lvl}]{nc} {f[\"check\"]}')
" 2>/dev/null)
        if [ -n "$disc_output" ]; then
            echo -e "${BOLD}Discovery Findings:${NC}"
            echo -e "$disc_output"
            echo ""
        fi
    fi

    # Scan intelligence
    local scan_file="$PROJECT_ROOT/.context/scans/LATEST.yaml"
    if [ -f "$scan_file" ]; then
        echo -e "${BOLD}Scan Intelligence:${NC}"
        python3 -c "
import yaml, sys
with open('$scan_file') as f:
    data = yaml.safe_load(f)
if not data:
    sys.exit(0)
print(f\"  Scan: {data.get('scan_id', '?')} ({data.get('scan_status', '?')})\")
print(f\"  Summary: {data.get('summary', 'N/A')}\")
wq = data.get('work_queue', [])
if wq:
    print(f\"  Work Queue ({len(wq)} items):\")
    for item in wq[:5]:
        print(f\"    {item.get('priority', '?')}. {item.get('task_id', '?')}: {item.get('name', '?')} ({item.get('status', '?')})\")
nd = data.get('needs_decision', [])
if nd:
    print(f\"  Needs Decision ({len(nd)} items):\")
    for item in nd[:3]:
        print(f\"    - {item.get('summary', '?')}\")
" 2>/dev/null
        echo ""
    fi

    # Research artifacts (docs/reports/) — T-185
    local reports_dir="$PROJECT_ROOT/docs/reports"
    if [ -d "$reports_dir" ]; then
        local recent_reports
        recent_reports=$(find "$reports_dir" -name "*.md" -mtime -7 -type f 2>/dev/null | sort -r | head -5)
        if [ -n "$recent_reports" ]; then
            echo -e "${BOLD}Recent Research (docs/reports/, last 7 days):${NC}"
            while IFS= read -r report; do
                echo "  - $(basename "$report")"
            done <<< "$recent_reports"
            echo ""
        fi
    fi

    # Recommendations
    echo -e "${BOLD}${CYAN}Recommendations:${NC}"
    if [ "$task_count" -eq 0 ]; then
        echo "  1. Create a new task or review open questions"
    elif [ -n "$focus" ]; then
        echo "  1. Continue work on $focus"
    else
        echo "  1. Set focus: ./agents/context/context.sh focus T-XXX"
    fi

    if [ "$uncommitted" -gt 0 ]; then
        echo "  2. Commit uncommitted changes with task reference"
    fi

    echo ""
}

# SYNC command - update working memory
cmd_sync() {
    echo -e "${CYAN}=== Syncing Working Memory ===${NC}"
    echo ""

    # Get actual active tasks
    local active_tasks=""
    shopt -s nullglob
    for f in "$TASKS_DIR/active"/*.md; do
        [ -f "$f" ] || continue
        task_id=$(grep "^id:" "$f" | head -1 | cut -d: -f2 | tr -d ' ')
        if [ -n "$task_id" ]; then
            if [ -n "$active_tasks" ]; then
                active_tasks="$active_tasks, $task_id"
            else
                active_tasks="$task_id"
            fi
        fi
    done
    shopt -u nullglob

    # Get completed tasks count
    local completed_count=0
    shopt -s nullglob
    for f in "$TASKS_DIR/completed"/*.md; do
        [ -f "$f" ] && completed_count=$((completed_count + 1))
    done
    shopt -u nullglob

    # Update session.yaml
    if [ -f "$WORKING_DIR/session.yaml" ]; then
        local session_id=$(grep "^session_id:" "$WORKING_DIR/session.yaml" | cut -d: -f2 | tr -d ' ')
        local start_time=$(grep "^start_time:" "$WORKING_DIR/session.yaml" | cut -d: -f2- | tr -d ' ')
        local predecessor=$(grep "^predecessor:" "$WORKING_DIR/session.yaml" | cut -d: -f2 | tr -d ' ')

        cat > "$WORKING_DIR/session.yaml" << EOF
# Working Memory - Session State
# Synced: $(date -u +"%Y-%m-%dT%H:%M:%SZ")

session_id: $session_id
start_time: $start_time
predecessor: $predecessor

# Session state
status: active
uncommitted_changes: $(git -C "$PROJECT_ROOT" status --porcelain 2>/dev/null | wc -l | tr -d ' ')

# What we're working on
active_tasks: [$active_tasks]
tasks_touched: []
tasks_completed: []

# Session notes (ephemeral)
notes: []
EOF
        echo -e "${GREEN}✓ Updated session.yaml${NC}"
        echo "  Active tasks: [$active_tasks]"
    else
        echo -e "${YELLOW}No session.yaml found - run context init first${NC}"
    fi

    # Validate focus
    if [ -f "$WORKING_DIR/focus.yaml" ]; then
        local current_focus=$(grep "^current_task:" "$WORKING_DIR/focus.yaml" | cut -d: -f2 | tr -d ' ')
        if [ -n "$current_focus" ]; then
            # Check if focus task still exists in active
            if [ ! -f "$TASKS_DIR/active"/*"$current_focus"* ] 2>/dev/null; then
                echo -e "${YELLOW}⚠ Focus task $current_focus no longer active${NC}"
                # Clear focus if task completed
                sed -i "s/^current_task:.*/current_task:/" "$WORKING_DIR/focus.yaml"
                echo "  Cleared stale focus"
            else
                echo -e "${GREEN}✓ Focus valid: $current_focus${NC}"
            fi
        fi
    fi

    echo ""
    echo -e "${GREEN}Sync complete${NC}"
}

# QUICK command - one-line summary
cmd_quick() {
    local focus=$(get_focus)
    IFS='|' read -r task_count task_list <<< "$(get_active_tasks)"
    IFS='|' read -r uncommitted last_commit branch <<< "$(get_git_state)"

    # First-session detection (T-125)
    local commit_count
    commit_count=$(git -C "$PROJECT_ROOT" rev-list --count HEAD 2>/dev/null || echo "0")
    if [ ! -f "$HANDOVER_DIR/LATEST.md" ] && [ "$commit_count" -le 1 ]; then
        echo "New project — no history. Run 'fw context init' to start."
        if [ "$task_count" -gt 0 ]; then
            echo "Active tasks: $task_count. Run 'fw work-on T-001' to begin."
        fi
        return
    fi

    local summary=""

    if [ -n "$focus" ]; then
        summary="Focus: $focus"
    elif [ "$task_count" -gt 0 ]; then
        summary="$task_count active tasks"
    else
        summary="No active tasks"
    fi

    if [ "$uncommitted" -gt 0 ]; then
        summary="$summary | $uncommitted uncommitted"
    fi

    echo "$summary"

    # Scan summary if available
    local scan_file="$PROJECT_ROOT/.context/scans/LATEST.yaml"
    if [ -f "$scan_file" ]; then
        echo ""
        echo "=== Scan Summary ==="
        python3 -c "
import yaml, sys
with open('$scan_file') as f:
    data = yaml.safe_load(f)
if data and 'summary' in data:
    print(data['summary'])
" 2>/dev/null
    fi
}

# Main
case "${1:-}" in
    status) cmd_status ;;
    sync) cmd_sync ;;
    quick) cmd_quick ;;
    -h|--help|help) show_help ;;
    "") show_help ;;
    *) echo "Unknown command: $1"; show_help; exit 1 ;;
esac
