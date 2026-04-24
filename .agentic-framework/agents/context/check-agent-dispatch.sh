#!/bin/bash
# Agent Dispatch Gate — PreToolUse hook for Agent tool
# Enforces TermLink-first rule for heavy parallel work (T-533)
#
# CLAUDE.md §Sub-Agent Dispatch Protocol:
#   "If you're about to dispatch 3+ Task tool agents that will each produce
#    >1K tokens or edit files, use TermLink dispatch instead."
#
# Enforcement:
#   1. Tracks Agent dispatches per session via counter file
#   2. First 2 dispatches: allowed (lightweight use case)
#   3. 3rd+ dispatch: blocked unless approved or TermLink unavailable
#   4. Approval via: fw dispatch approve (5-min TTL, like Tier 0)
#
# Exit codes (Claude Code PreToolUse semantics):
#   0 — Allow tool execution
#   2 — Block tool execution (stderr shown to agent)
#
# Part of: Agentic Engineering Framework (T-533: Dispatch Rerouting)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$FRAMEWORK_ROOT/lib/paths.sh"
source "$FRAMEWORK_ROOT/lib/config.sh"
fw_hook_crash_trap "check-agent-dispatch"

COUNTER_FILE="$PROJECT_ROOT/.context/working/.agent-dispatch-counter"
APPROVAL_FILE="$PROJECT_ROOT/.context/working/.dispatch-approval"
DISPATCH_LIMIT=$(fw_config_int "DISPATCH_LIMIT" 2)

# Read stdin (JSON from Claude Code)
INPUT=$(cat)

# Only fire for Agent tool
TOOL_NAME=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    print(data.get('tool_name', ''))
except:
    print('')
" 2>/dev/null)

if [ "$TOOL_NAME" != "Agent" ]; then
    exit 0
fi

# Ensure counter file directory exists
mkdir -p "$(dirname "$COUNTER_FILE")"

# Read current count
if [ -f "$COUNTER_FILE" ]; then
    COUNT=$(tr -d '[:space:]' < "$COUNTER_FILE" 2>/dev/null)
    COUNT=${COUNT:-0}
else
    COUNT=0
fi

# Increment counter
NEW_COUNT=$((COUNT + 1))
echo "$NEW_COUNT" > "$COUNTER_FILE"

# First N dispatches are free
if [ "$NEW_COUNT" -le "$DISPATCH_LIMIT" ]; then
    exit 0
fi

# Check if TermLink is installed — if not, warn but allow
if ! command -v termlink >/dev/null 2>&1; then
    echo "NOTE: Agent dispatch #${NEW_COUNT} (limit: ${DISPATCH_LIMIT}). TermLink not installed — allowing." >&2
    echo "  Install TermLink for context-efficient parallel dispatch: brew install DimitriGeelen/termlink/termlink" >&2
    exit 0
fi

# Check for approval token
if [ -f "$APPROVAL_FILE" ]; then
    APPROVAL_TS=$(tr -d '[:space:]' < "$APPROVAL_FILE" 2>/dev/null)
    NOW_TS=$(date +%s)
    AGE=$(( NOW_TS - APPROVAL_TS ))
    if [ "$AGE" -lt 300 ]; then
        # Approval valid (5-min TTL)
        exit 0
    else
        # Expired
        rm -f "$APPROVAL_FILE"
    fi
fi

# Block — suggest TermLink
echo "" >&2
echo "BLOCKED: Agent dispatch #${NEW_COUNT} exceeds limit (${DISPATCH_LIMIT})." >&2
echo "" >&2
echo "TermLink is installed — use it for heavy parallel work:" >&2
echo "  $(_fw_cmd) termlink dispatch --name worker-1 --prompt 'your prompt here'" >&2
echo "" >&2
echo "TermLink dispatch costs ZERO parent context tokens." >&2
echo "Agent dispatches share the parent context window." >&2
echo "" >&2
echo "To approve Agent dispatch (5-min window):" >&2
echo "  $(_fw_cmd) dispatch approve" >&2
echo "" >&2
echo "To reset counter (e.g., after compaction):" >&2
echo "  $(_fw_cmd) dispatch reset" >&2
echo "" >&2
echo "Policy: T-533 (TermLink-first dispatch enforcement)" >&2
exit 2
