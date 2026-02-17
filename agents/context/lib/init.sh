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
        echo "This looks like a new project. Here's how to get started:"
        echo ""
        echo "  1. Create your first task:"
        echo "     fw task create --name 'Your task' --type build --owner human --start"
        echo ""
        echo "  2. Or start an inception (exploration):"
        echo "     fw inception start 'Explore problem X'"
        echo ""
        echo "  3. Set focus and begin:"
        echo "     fw context focus T-001"
        echo ""
        echo "  4. When done, generate handover:"
        echo "     fw handover --commit"
        echo ""
        echo "  Run 'fw help' for all commands, 'fw doctor' to check setup."
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
}
