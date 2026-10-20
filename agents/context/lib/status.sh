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

    # Count patterns, decisions, learnings (T-2906). Parse the YAML rather than
    # grep one serialisation of it: learnings.yaml moved to PyYAML's flat
    # "- application: …\n  id: L-NNN" form in April and "^  - id: L-" matched
    # nothing for months — an empty scan reads exactly like an empty corpus.
    # A missing file is 0; a file that will not parse is "?" with the reason.
    local counts
    counts=$(python3 - "$CONTEXT_DIR/project" <<'PYEOF'
import os, sys
try:
    import yaml
except Exception as e:
    yaml = None
    err = e
root = sys.argv[1]

def entries(name):
    path = os.path.join(root, name)
    if not os.path.isfile(path):
        return []
    if yaml is None:
        raise RuntimeError("PyYAML unavailable: %s" % err)
    with open(path) as fh:
        data = yaml.safe_load(fh) or {}
    if not isinstance(data, dict):
        raise RuntimeError("top level is %s, not a mapping" % type(data).__name__)
    return [e for v in data.values() if isinstance(v, list) for e in v if isinstance(e, dict)]

def count(name, pred):
    try:
        return str(sum(1 for e in entries(name) if pred(e)))
    except Exception as e:
        sys.stderr.write("context status: cannot count %s: %s\n" % (name, e))
        return "?"

def id_prefix(p):
    return lambda e: str(e.get("id", "")).startswith(p)

print(" ".join([
    count("patterns.yaml", id_prefix("FP-")),
    count("patterns.yaml", id_prefix("SP-")),
    count("patterns.yaml", id_prefix("WP-")),
    count("decisions.yaml", id_prefix("D-")),
    count("learnings.yaml", id_prefix("L-")),
    count("learnings.yaml", lambda e: "observation" in e),
]))
PYEOF
)
    [ -n "$counts" ] || counts="? ? ? ? ? ?"
    local failure_patterns success_patterns workflow_patterns decisions learnings candidates
    read -r failure_patterns success_patterns workflow_patterns decisions learnings candidates <<< "$counts"
    echo "Patterns: $failure_patterns failure, $success_patterns success, $workflow_patterns workflow"
    echo "Decisions: $decisions"
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
