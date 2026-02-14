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

    # Auto-run watchtower scan (Phase 4)
    if python3 -c "import web.watchtower" 2>/dev/null; then
        echo ""
        echo "Running watchtower scan..."
        cd "$FRAMEWORK_ROOT" && python3 -m web.watchtower --quiet 2>/dev/null && \
            echo "  Scan written to .context/scans/LATEST.yaml" || \
            echo "  (scan skipped — non-critical)"
    fi
}
