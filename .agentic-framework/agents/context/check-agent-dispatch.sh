#!/bin/bash
# Agent Dispatch Gate — PreToolUse hook for Agent tool
# Enforces TermLink-first rule for heavy parallel work (T-533)
#
# CLAUDE.md §Sub-Agent Dispatch Protocol:
#   "If you're about to dispatch 3+ Task tool agents that will each produce
#    >1K tokens or edit files, use TermLink dispatch instead."
#
# Enforcement:
#   1. Tracks ALLOWED Agent dispatches per session via counter file
#      (format "<count> <session-key>"; a different session key starts at 0;
#      blocked attempts are not counted — T-4729)
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
# T-3910 (operator ruling 2026-10-06): default 0 — sub-agents run as TermLink
# workers, never through the vendor harness's own dispatcher.
DISPATCH_LIMIT=$(fw_config_int "DISPATCH_LIMIT" 0)

# Read stdin (JSON from Claude Code)
INPUT=$(cat)

# Only fire for Agent tool. T-4729: read the session id in the same pass, so the
# counter is keyed to the session the header promises.
read -r TOOL_NAME SESSION_KEY < <(echo "$INPUT" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    print(data.get('tool_name', '') or '-', data.get('session_id', '') or '')
except:
    print('-')
" 2>/dev/null)

# T-4853: the decoder always prints something (a name, or '-'); nothing at all means
# python3 itself could not run, and the `!= Agent` test below would allow every call.
# Scan the raw payload in bash instead and block an Agent call (fail closed).
if [ -z "${TOOL_NAME:-}" ]; then
    if grep -qE '"tool_name"[[:space:]]*:[[:space:]]*"Agent"' <<<"$INPUT"; then  # T-4921: no pipe into grep -q
        source "$FRAMEWORK_ROOT/lib/hook-degraded.sh"
        _hook_degraded_banner "check-agent-dispatch" "python3 could not decode the payload" \
            "The raw payload is an Agent call, so it is BLOCKED (fail closed)."
        echo "  The dispatch limit and approvals cannot be evaluated while degraded." >&2
        echo "  Repair python3 on PATH, or use: $(_fw_cmd) termlink dispatch" >&2
        echo "  Policy: T-4652 (hooks must not fail open)" >&2
        echo "══════════════════════════════════════════════════════════" >&2
        exit 2
    fi
    exit 0
fi

if [ "${TOOL_NAME:-}" != "Agent" ]; then
    exit 0
fi

# No session id in the payload: fall back to the framework session.
if [ -z "${SESSION_KEY:-}" ] && [ -f "$PROJECT_ROOT/.context/working/session.yaml" ]; then
    SESSION_KEY=$(sed -n 's/^session_id:[[:space:]]*//p' "$PROJECT_ROOT/.context/working/session.yaml" 2>/dev/null | head -1 | tr -d '[:space:]"')
fi
SESSION_KEY=${SESSION_KEY:-}

# Ensure counter file directory exists
mkdir -p "$(dirname "$COUNTER_FILE")"

# Read current count for this session (a legacy bare number has no session key)
COUNT=0
if [ -f "$COUNTER_FILE" ]; then
    read -r _c _s < "$COUNTER_FILE" 2>/dev/null || true
    if [ "${_s:-}" = "$SESSION_KEY" ] && [[ "${_c:-}" =~ ^[0-9]+$ ]]; then
        COUNT=$_c
    fi
fi
NEW_COUNT=$((COUNT + 1))

# T-4729: count a dispatch only when it is allowed — a blocked attempt is not a dispatch.
allow() {
    echo "$NEW_COUNT $SESSION_KEY" > "$COUNTER_FILE"
    exit 0
}

# First N dispatches are free
if [ "$NEW_COUNT" -le "$DISPATCH_LIMIT" ]; then
    allow
fi

# Check if TermLink is installed — if not, warn but allow
if ! command -v termlink >/dev/null 2>&1; then
    echo "NOTE: Agent dispatch #${NEW_COUNT} (limit: ${DISPATCH_LIMIT}). TermLink not installed — allowing." >&2
    echo "  Install TermLink for context-efficient parallel dispatch: brew install DimitriGeelen/termlink/termlink" >&2
    allow
fi

# Check for approval token
if [ -f "$APPROVAL_FILE" ]; then
    APPROVAL_TS=$(tr -d '[:space:]' < "$APPROVAL_FILE" 2>/dev/null)
    NOW_TS=$(date +%s)
    AGE=$(( NOW_TS - APPROVAL_TS ))
    if [ "$AGE" -lt 300 ]; then
        # Approval valid (5-min TTL)
        allow
    else
        # Expired
        rm -f "$APPROVAL_FILE"
    fi
fi

# Block — suggest TermLink
echo "" >&2
echo "BLOCKED: Agent dispatch #${NEW_COUNT} exceeds limit (${DISPATCH_LIMIT})." >&2
echo "" >&2
echo "Sub-agents run as TermLink workers, not through the harness's own dispatcher" >&2
echo "(operator ruling 2026-10-06, T-3910; FW_DISPATCH_LIMIT defaults to 0):" >&2
echo "  $(_fw_cmd) termlink dispatch --task T-XXX --name worker-1 --prompt 'your prompt here'" >&2
echo "Up to $(fw_config_int "TERMLINK_MAX_WORKERS" 5) concurrent workers (TERMLINK_MAX_WORKERS); for more, ask the operator." >&2
echo "" >&2
echo "TermLink dispatch costs ZERO parent context tokens." >&2
echo "Agent dispatches share the parent context window." >&2
echo "" >&2
echo "Operator exception only — approve Agent dispatch (5-min window):" >&2
echo "  $(_fw_cmd) dispatch approve" >&2
echo "" >&2
echo "To reset counter (e.g., after compaction):" >&2
echo "  $(_fw_cmd) dispatch reset" >&2
echo "" >&2
echo "Policy: T-533 (TermLink-first dispatch enforcement)" >&2
exit 2
