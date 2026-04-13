#!/bin/bash
# Context Agent - init command
# Initializes working memory for a new session

do_init() {
    ensure_context_dirs

    local session_id="S-$(date -u +%Y-%m%d-%H%M)"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # Check for predecessor from latest handover
    local predecessor=""
    if [ -f "$CONTEXT_DIR/handovers/LATEST.md" ]; then
        predecessor=$(grep "^session_id:" "$CONTEXT_DIR/handovers/LATEST.md" | head -1 | cut -d' ' -f2)
    fi

    # Get active tasks (extract T-XXX from T-XXX-name.md)
    local active_tasks=""
    if [ -d "$PROJECT_ROOT/.tasks/active" ]; then
        active_tasks=$(ls "$PROJECT_ROOT/.tasks/active/" 2>/dev/null | \
            sed 's/^\(T-[0-9]*\)-.*/\1/' | \
            tr '\n' ',' | sed 's/,$//' | sed 's/,/, /g')
    fi

    # Initialize session.yaml
    cat > "$CONTEXT_DIR/working/session.yaml" << EOF
# Working Memory - Session State
# Initialized: $timestamp

session_id: $session_id
start_time: $timestamp
predecessor: ${predecessor:-null}

# Session state
status: active
uncommitted_changes: 0

# What we're working on
active_tasks: [${active_tasks}]
tasks_touched: []
tasks_completed: []

# Session notes (ephemeral)
notes: []
EOF

    # Initialize focus.yaml
    cat > "$CONTEXT_DIR/working/focus.yaml" << EOF
# Working Memory - Current Focus
# Session: $session_id

current_task: null

# Priority queue
priorities: []

# Blockers
blockers: []

# Pending decisions
pending_decisions: []

# Reminders
reminders:
  - "Run audit before pushing"
  - "Create handover before ending session"
EOF

    # Reset tool counter (P-009 context protection)
    echo "0" > "$CONTEXT_DIR/working/.tool-counter"

    # Reset budget gate counter (T-139 budget enforcement)
    echo "0" > "$CONTEXT_DIR/working/.budget-gate-counter"
    rm -f "$CONTEXT_DIR/working/.budget-status"

    # Reset session turn offset (T-850 per-session metrics)
    rm -f "$CONTEXT_DIR/working/.session-turn-offset"

    echo -e "${GREEN}=== Session Initialized ===${NC}"
    echo "Session ID: $session_id"
    echo "Start time: $timestamp"
    [ -n "$predecessor" ] && echo "Predecessor: $predecessor"
    echo ""
    echo "Active tasks: ${active_tasks:-none}"
    echo ""
    echo "Working memory initialized at:"
    echo "  $CONTEXT_DIR/working/session.yaml"
    echo "  $CONTEXT_DIR/working/focus.yaml"
    echo "  $CONTEXT_DIR/working/.tool-counter (reset to 0)"

    # --- First-session detection (T-125) ---
    local has_handover=false
    local has_tasks=false
    local has_commits=false
    [ -f "$CONTEXT_DIR/handovers/LATEST.md" ] && has_handover=true
    [ -n "$active_tasks" ] && has_tasks=true
    local commit_count
    commit_count=$(git -C "$PROJECT_ROOT" rev-list --count HEAD 2>/dev/null || echo "0")
    [ "$commit_count" -gt 1 ] && has_commits=true

    if [ "$has_handover" = false ] && [ "$has_commits" = false ]; then
        echo ""
        echo -e "${YELLOW}=== Welcome — First Session ===${NC}"
        echo ""
        # Check if onboarding tasks exist
        local onboard_count=0
        if [ -d "$TASKS_DIR/active" ]; then
            onboard_count=$(grep -rl "tags:.*onboarding" "$TASKS_DIR/active" 2>/dev/null | wc -l)
        fi
        if [ "$onboard_count" -gt 0 ]; then
            echo "Onboarding tasks are ready ($onboard_count tasks). Start with:"
            echo ""
            echo "  $(_fw_cmd) work-on T-001"
            echo ""
            echo "The tasks guide you through framework setup step by step."
        else
            echo "This looks like a new project. Here's how to get started:"
            echo ""
            echo "  1. Start working on something:"
            echo "     $(_fw_cmd) work-on 'Your task name' --type build"
            echo ""
            echo "  2. Or start an inception (exploration):"
            echo "     $(_fw_cmd) inception start 'Explore problem X'"
        fi
        echo ""
        echo "  Run '$(_fw_cmd) help' for all commands, '$(_fw_cmd) doctor' to check setup."
    fi

    # Auto-generate watch-patterns.yaml if missing (T-367)
    local fabric_dir="$PROJECT_ROOT/.fabric"
    local watch_file="$fabric_dir/watch-patterns.yaml"
    if [ ! -f "$watch_file" ] && [ -d "$fabric_dir" ]; then
        cat > "$watch_file" << 'WPEOF'
# Fabric watch patterns — source files to track for drift detection
# Generated automatically by fw context init
# Edit to match your project's source layout
patterns:
  - glob: "src/**/*.py"
  - glob: "src/**/*.rs"
  - glob: "crates/*/src/**/*.rs"
  - glob: "lib/**/*.py"
  - glob: "lib/**/*.sh"
  - glob: "web/**/*.py"
  - glob: "agents/**/*.sh"
  - glob: "agents/**/*.py"
  - glob: "bin/*"
  - glob: "**/*.ts"
  - glob: "**/*.go"
WPEOF
        echo ""
        echo -e "${GREEN}Generated .fabric/watch-patterns.yaml${NC} (default patterns)"
        echo "  Edit to match your project layout, then run: $(_fw_cmd) fabric scan"
    fi

    # Auto-run watchtower scan (Phase 4)
    # Watchtower requires the web module which lives in the framework repo
    if [ "$PROJECT_ROOT" = "$FRAMEWORK_ROOT" ] && python3 -c "import web.watchtower" 2>/dev/null; then
        echo ""
        echo "Running watchtower scan..."
        cd "$FRAMEWORK_ROOT" && python3 -m web.watchtower --quiet 2>/dev/null && \
            echo "  Scan written to .context/scans/LATEST.yaml" || \
            echo "  (scan skipped — non-critical)"
    fi

    # Display latest cron audit findings (T-184)
    local cron_audit_dir="$CONTEXT_DIR/audits/cron"
    local cron_latest
    cron_latest=$(ls -t "$cron_audit_dir"/*.yaml 2>/dev/null | grep -v "LATEST-CRON" | head -1) || true
    if [ -n "$cron_latest" ]; then
        local cron_ts cron_pass cron_warn cron_fail cron_sections
        cron_ts=$(grep "^timestamp:" "$cron_latest" 2>/dev/null | cut -d' ' -f2) || true
        cron_pass=$(grep "^  pass:" "$cron_latest" 2>/dev/null | awk '{print $2}') || true
        cron_warn=$(grep "^  warn:" "$cron_latest" 2>/dev/null | awk '{print $2}') || true
        cron_fail=$(grep "^  fail:" "$cron_latest" 2>/dev/null | awk '{print $2}') || true
        cron_sections=$(grep "^sections:" "$cron_latest" 2>/dev/null | sed 's/sections: "//' | sed 's/"$//') || true
        echo ""
        echo -e "${YELLOW}Latest cron audit:${NC} ${cron_ts:-unknown}"
        [ -n "$cron_sections" ] && echo "  Sections: $cron_sections"
        echo -e "  Pass: ${cron_pass:-0}  Warn: ${cron_warn:-0}  Fail: ${cron_fail:-0}"
        if [ "${cron_warn:-0}" -gt 0 ] || [ "${cron_fail:-0}" -gt 0 ]; then
            echo -e "  ${YELLOW}Run '$(_fw_cmd) audit' for details${NC}"
        fi
    fi

    # T-1159: Show open concerns at session start (cross-session failure awareness)
    local concerns_file="$CONTEXT_DIR/project/concerns.yaml"
    if [ -f "$concerns_file" ]; then
        local watching_count
        watching_count=$(python3 -c "
import yaml, sys
try:
    with open(sys.argv[1]) as f:
        data = yaml.safe_load(f) or {}
    concerns = data.get('concerns', [])
    watching = [c for c in concerns if c.get('status') == 'watching']
    print(len(watching))
except Exception:
    print('0')
" "$concerns_file" 2>/dev/null) || watching_count=0
        if [ "${watching_count:-0}" -gt 0 ]; then
            echo ""
            echo -e "Concerns register: ${YELLOW}${watching_count} watching${NC}"
            echo -e "  Run ${CYAN}$(_fw_cmd) gaps${NC} for details"
        fi
    fi

    return 0
}
