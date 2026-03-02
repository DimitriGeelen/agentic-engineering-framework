#!/bin/bash
# Pre-Compaction Hook — Save structured context before lossy compaction
# Fires on PreCompact — manual /compact only (auto-compaction disabled per D-027).
#
# Generates a handover so that SessionStart:compact can
# reinject structured context into the fresh session.
#
# Part of: T-111 (Autonomous compact-resume lifecycle)
# Updated: T-175 (D-028 — single handover, no emergency distinction)
# Updated: T-177 (manual-only cleanup, D-027 documentation)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# Resolve PROJECT_ROOT from git toplevel — framework/ is typically a subdirectory,
# not the project root. Fall back to FRAMEWORK_ROOT for standalone installs.
PROJECT_ROOT="${PROJECT_ROOT:-$(git -C "$FRAMEWORK_ROOT" rev-parse --show-toplevel 2>/dev/null || echo "$FRAMEWORK_ROOT")}"

# Generate handover — always full quality (D-028)
# Deduplicate: skip commit if last commit was a handover within 5 minutes
LAST_COMMIT_MSG=$(cd "$PROJECT_ROOT" && git log -1 --format="%s" 2>/dev/null)
LAST_COMMIT_AGE=$(cd "$PROJECT_ROOT" && git log -1 --format="%ct" 2>/dev/null)
NOW=$(date +%s)
SKIP_COMMIT=false
if echo "$LAST_COMMIT_MSG" | grep -qE "(handover|Handover)" 2>/dev/null; then
    if [ -n "$LAST_COMMIT_AGE" ] && [ $((NOW - LAST_COMMIT_AGE)) -lt 300 ]; then
        SKIP_COMMIT=true
    fi
fi

if [ "$SKIP_COMMIT" = "true" ]; then
    "$FRAMEWORK_ROOT/agents/handover/handover.sh" --no-commit 2>/dev/null
else
    "$FRAMEWORK_ROOT/agents/handover/handover.sh" --commit 2>/dev/null
fi

# Log the event
echo "[pre-compact] [manual] Handover generated at $(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$PROJECT_ROOT/.context/working/.compact-log" 2>/dev/null

# Reset budget gate for THIS project so fresh session doesn't inherit critical lock (T-145)
echo "0" > "$PROJECT_ROOT/.context/working/.budget-gate-counter" 2>/dev/null
rm -f "$PROJECT_ROOT/.context/working/.budget-status" 2>/dev/null

exit 0
