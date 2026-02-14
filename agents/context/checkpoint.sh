#!/bin/bash
# Context Checkpoint Agent — Automatic circuit breaker for context exhaustion
# Tracks tool call count per session and triggers warnings via Claude Code hooks
#
# Usage:
#   checkpoint.sh post-tool   — Called by Claude Code PostToolUse hook
#   checkpoint.sh reset       — Reset counter (after handover/commit)
#   checkpoint.sh status      — Show current counter
#
# Part of: Agentic Engineering Framework (P-009: Context Budget Awareness)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PROJECT_ROOT="${PROJECT_ROOT:-$FRAMEWORK_ROOT}"
CONTEXT_DIR="$PROJECT_ROOT/.context"
COUNTER_FILE="$CONTEXT_DIR/working/.tool-counter"

# Thresholds
WARN_THRESHOLD=40
URGENT_THRESHOLD=60
CRITICAL_THRESHOLD=80

ensure_counter() {
    mkdir -p "$(dirname "$COUNTER_FILE")"
    if [ ! -f "$COUNTER_FILE" ]; then
        echo "0" > "$COUNTER_FILE"
    fi
}

increment_counter() {
    ensure_counter
    local count
    count=$(cat "$COUNTER_FILE" | tr -d '[:space:]')
    count=$((count + 1))
    echo "$count" > "$COUNTER_FILE"
    echo "$count"
}

case "${1:-}" in
    post-tool)
        count=$(increment_counter)

        if [ "$count" -ge "$CRITICAL_THRESHOLD" ]; then
            echo "" >&2
            echo "===========================================" >&2
            echo "CRITICAL: $count tool calls since last commit." >&2
            echo "Context exhaustion risk is HIGH." >&2
            echo "ACTION: Run 'fw handover --emergency' NOW." >&2
            echo "===========================================" >&2
            echo "" >&2
        elif [ "$count" -ge "$URGENT_THRESHOLD" ]; then
            echo "" >&2
            echo "WARNING: $count tool calls since last commit." >&2
            echo "Consider: fw handover --checkpoint" >&2
            echo "" >&2
        elif [ "$count" -ge "$WARN_THRESHOLD" ]; then
            echo "" >&2
            echo "Note: $count tool calls since last commit. Commit work frequently." >&2
            echo "" >&2
        fi
        # Always exit 0 — never block tool calls, only warn
        exit 0
        ;;
    reset)
        ensure_counter
        echo "0" > "$COUNTER_FILE"
        echo "Counter reset."
        ;;
    status)
        ensure_counter
        echo "Tool calls since last commit: $(cat "$COUNTER_FILE" | tr -d '[:space:]')"
        ;;
    *)
        echo "Usage: checkpoint.sh {post-tool|reset|status}"
        exit 1
        ;;
esac
