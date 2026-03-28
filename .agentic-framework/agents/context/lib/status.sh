#!/bin/bash
# Context Agent - status command
# Shows current context state across all memory types

do_status() {
    ensure_context_dirs

    echo -e "${CYAN}=== CONTEXT FABRIC STATUS ===${NC}"
    echo ""

    # Working Memory
    echo -e "${YELLOW}=== WORKING MEMORY ===${NC}"
    if [ -f "$CONTEXT_DIR/working/session.yaml" ]; then
        local session_id=$(grep "^session_id:" "$CONTEXT_DIR/working/session.yaml" | cut -d' ' -f2)
        local status=$(grep "^status:" "$CONTEXT_DIR/working/session.yaml" | cut -d' ' -f2)
        local current_task=$(grep "^current_task:" "$CONTEXT_DIR/working/focus.yaml" 2>/dev/null | cut -d' ' -f2)

        echo "Session: $session_id"
        echo "Status: $status"
        echo "Current focus: ${current_task:-none}"

        # Show tasks touched
        local tasks_touched=$(grep "^tasks_touched:" "$CONTEXT_DIR/working/session.yaml" | sed 's/tasks_touched: //' | tr -d '[]')
        [ -n "$tasks_touched" ] && echo "Tasks touched: $tasks_touched"
    else
        echo "No active session (run 'context init' to start)"
    fi
    echo ""

    # Project Memory
    echo -e "${YELLOW}=== PROJECT MEMORY ===${NC}"

    # Count patterns
    local failure_patterns=0
    local success_patterns=0
    local workflow_patterns=0
    if [ -f "$CONTEXT_DIR/project/patterns.yaml" ]; then
        failure_patterns=$(grep -c "^  - id: FP-" "$CONTEXT_DIR/project/patterns.yaml" 2>/dev/null || true)
        success_patterns=$(grep -c "^  - id: SP-" "$CONTEXT_DIR/project/patterns.yaml" 2>/dev/null || true)
        workflow_patterns=$(grep -c "^  - id: WP-" "$CONTEXT_DIR/project/patterns.yaml" 2>/dev/null || true)
    fi
    echo "Patterns: $failure_patterns failure, $success_patterns success, $workflow_patterns workflow"

    # Count decisions
    local decisions=0
    if [ -f "$CONTEXT_DIR/project/decisions.yaml" ]; then
        decisions=$(grep -c "^  - id: D-" "$CONTEXT_DIR/project/decisions.yaml" 2>/dev/null || true)
    fi
    echo "Decisions: $decisions"

    # Count learnings
    local learnings=0
    local candidates=0
    if [ -f "$CONTEXT_DIR/project/learnings.yaml" ]; then
        learnings=$(grep -c "^  - id: L-" "$CONTEXT_DIR/project/learnings.yaml" 2>/dev/null || true)
        learnings=$(echo "$learnings" | tr -d '[:space:]')
        candidates=$(grep -c "^  - observation:" "$CONTEXT_DIR/project/learnings.yaml" 2>/dev/null || true)
        candidates=$(echo "$candidates" | tr -d '[:space:]')
    fi
    echo "Learnings: $learnings (+ $candidates candidates)"
    echo ""

    # Episodic Memory
    echo -e "${YELLOW}=== EPISODIC MEMORY ===${NC}"
    local episodic_count=$(find "$CONTEXT_DIR/episodic" -name "T-*.yaml" 2>/dev/null | wc -l)
    echo "Task summaries: $episodic_count"

    if [ "$episodic_count" -gt 0 ]; then
        echo "Recent:"
        find "$CONTEXT_DIR/episodic" -name "T-*.yaml" -type f -printf '%T@ %f\n' 2>/dev/null | \
            sort -rn | head -3 | awk '{print "  - " $2}' | sed 's/.yaml$//'
    fi
    echo ""

    # Existing context artifacts
    echo -e "${YELLOW}=== OTHER CONTEXT ===${NC}"
    local handover_count=$(find "$CONTEXT_DIR/handovers" -name "S-*.md" 2>/dev/null | wc -l)
    local audit_count=$(find "$CONTEXT_DIR/audits" -name "*.yaml" 2>/dev/null | wc -l)
    echo "Handovers: $handover_count"
    echo "Audit records: $audit_count"
    [ -f "$CONTEXT_DIR/bypass-log.yaml" ] && echo "Bypass log: exists"

    echo ""
    echo -e "${CYAN}=== END STATUS ===${NC}"
}
