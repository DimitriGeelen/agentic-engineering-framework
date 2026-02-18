#!/bin/bash
# Pre-Compaction Hook — Save structured context before lossy compaction
# Fires on PreCompact (both auto and manual). Cannot block compaction.
#
# Generates an emergency handover so that SessionStart:compact can
# reinject structured context into the fresh session.
#
# Part of: T-111 (Autonomous compact-resume lifecycle)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PROJECT_ROOT="${PROJECT_ROOT:-$FRAMEWORK_ROOT}"

# Generate emergency handover (fast — ~100ms, no LLM needed)
# Deduplicate: skip commit if last commit was an emergency handover within 5 minutes
LAST_COMMIT_MSG=$(cd "$PROJECT_ROOT" && git log -1 --format="%s" 2>/dev/null)
LAST_COMMIT_AGE=$(cd "$PROJECT_ROOT" && git log -1 --format="%ct" 2>/dev/null)
NOW=$(date +%s)
SKIP_COMMIT=false
if echo "$LAST_COMMIT_MSG" | grep -q "Emergency handover" 2>/dev/null; then
    if [ -n "$LAST_COMMIT_AGE" ] && [ $((NOW - LAST_COMMIT_AGE)) -lt 300 ]; then
        SKIP_COMMIT=true
    fi
fi

if [ "$SKIP_COMMIT" = "true" ]; then
    "$FRAMEWORK_ROOT/agents/handover/handover.sh" --emergency --no-commit 2>/dev/null
else
    "$FRAMEWORK_ROOT/agents/handover/handover.sh" --emergency 2>/dev/null
fi

# Log the event
echo "[pre-compact] Emergency handover generated at $(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$PROJECT_ROOT/.context/working/.compact-log" 2>/dev/null

# Reset budget gate for THIS project so fresh session doesn't inherit critical lock (T-145)
echo "0" > "$PROJECT_ROOT/.context/working/.budget-gate-counter" 2>/dev/null
rm -f "$PROJECT_ROOT/.context/working/.budget-status" 2>/dev/null

exit 0
