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

# Generate emergency handover (fast — ~100ms, no LLM needed)
"$FRAMEWORK_ROOT/agents/handover/handover.sh" --emergency 2>/dev/null

# Log the event
echo "[pre-compact] Emergency handover generated at $(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$FRAMEWORK_ROOT/.context/working/.compact-log" 2>/dev/null

exit 0
