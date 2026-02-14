#!/bin/bash
# Context Checkpoint Agent — Token-aware context budget monitor
# Reads actual token usage from Claude Code JSONL transcript to warn
# before automatic compaction causes context loss.
#
# Primary: Token-based warnings from JSONL transcript (checked every 5 calls)
# Fallback: Tool call counter (when transcript unavailable)
#
# Note: Token reading lags by ~1 API call (~10-30K behind actual).
# Thresholds are set conservatively to account for this.
#
# Usage:
#   checkpoint.sh post-tool   — Called by Claude Code PostToolUse hook
#   checkpoint.sh reset       — Reset tool call counter (on commit)
#   checkpoint.sh status      — Show current context usage
#
# Part of: Agentic Engineering Framework (P-009: Context Budget Awareness)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PROJECT_ROOT="${PROJECT_ROOT:-$FRAMEWORK_ROOT}"
CONTEXT_DIR="$PROJECT_ROOT/.context"
COUNTER_FILE="$CONTEXT_DIR/working/.tool-counter"
TRANSCRIPT_CACHE="$CONTEXT_DIR/working/.transcript-path"

# Token thresholds (200K context window, compaction observed at ~160K)
# Conservative due to ~10-30K lag in token readings
TOKEN_WARN=100000      # ~50% — informational
TOKEN_URGENT=130000    # ~65% — commit + consider checkpoint
TOKEN_CRITICAL=150000  # ~75% — compaction imminent, handover NOW

# Check tokens every N tool calls (balance: accuracy vs performance)
TOKEN_CHECK_INTERVAL=5

# Fallback tool call thresholds (only used when transcript unavailable)
CALL_WARN=40
CALL_URGENT=60
CALL_CRITICAL=80

ensure_counter() {
    mkdir -p "$(dirname "$COUNTER_FILE")"
    [ -f "$COUNTER_FILE" ] || echo "0" > "$COUNTER_FILE"
}

increment_counter() {
    ensure_counter
    local count
    count=$(tr -d '[:space:]' < "$COUNTER_FILE")
    count=$((count + 1))
    echo "$count" > "$COUNTER_FILE"
    echo "$count"
}

# Find current session JSONL transcript (path cached for performance)
find_transcript() {
    if [ -f "$TRANSCRIPT_CACHE" ]; then
        local cached
        cached=$(cat "$TRANSCRIPT_CACHE")
        if [ -f "$cached" ]; then
            echo "$cached"
            return
        fi
    fi
    local transcript
    transcript=$(find ~/.claude/projects -name "*.jsonl" -type f ! -name "agent-*" 2>/dev/null | xargs ls -t 2>/dev/null | head -1)
    if [ -n "$transcript" ]; then
        echo "$transcript" > "$TRANSCRIPT_CACHE"
        echo "$transcript"
    fi
}

# Read effective context size from the last API response in the transcript.
# Uses tail -c (O(1) seek) + python3 JSON parsing for accuracy.
# grep alone can't distinguish usage data from command text containing "input_tokens".
# Performance: ~23ms on a 30MB transcript.
get_context_tokens() {
    local transcript="$1"
    tail -c 500000 "$transcript" 2>/dev/null | python3 -c "
import sys, json
t = 0
for line in sys.stdin:
    try:
        e = json.loads(line)
        u = e.get('message', {}).get('usage')
        if u and 'input_tokens' in u:
            t = u['input_tokens'] + u.get('cache_read_input_tokens', 0) + u.get('cache_creation_input_tokens', 0)
    except: pass
print(t)
" 2>/dev/null
}

warn_by_tokens() {
    local tokens="$1"
    local pct=$((tokens * 100 / 200000))

    if [ "$tokens" -ge "$TOKEN_CRITICAL" ]; then
        echo "" >&2
        echo "===========================================" >&2
        echo "CRITICAL: Context at ${tokens} tokens (~${pct}% of 200K)." >&2
        echo "Compaction imminent — work will be summarized." >&2
        echo "ACTION: Commit now, then 'fw handover --emergency'." >&2
        echo "===========================================" >&2
        echo "" >&2
    elif [ "$tokens" -ge "$TOKEN_URGENT" ]; then
        echo "" >&2
        echo "WARNING: Context at ${tokens} tokens (~${pct}% of 200K)." >&2
        echo "Commit work. Consider: fw handover --checkpoint" >&2
        echo "" >&2
    elif [ "$tokens" -ge "$TOKEN_WARN" ]; then
        echo "" >&2
        echo "Note: Context at ${tokens} tokens (~${pct}%). Commit frequently." >&2
        echo "" >&2
    fi
}

warn_by_calls() {
    local count="$1"
    if [ "$count" -ge "$CALL_CRITICAL" ]; then
        echo "" >&2
        echo "===========================================" >&2
        echo "CRITICAL: $count tool calls since last commit (no token data)." >&2
        echo "ACTION: Commit now, then 'fw handover --emergency'." >&2
        echo "===========================================" >&2
        echo "" >&2
    elif [ "$count" -ge "$CALL_URGENT" ]; then
        echo "" >&2
        echo "WARNING: $count tool calls since last commit (no token data)." >&2
        echo "Consider: fw handover --checkpoint" >&2
        echo "" >&2
    elif [ "$count" -ge "$CALL_WARN" ]; then
        echo "" >&2
        echo "Note: $count tool calls since last commit." >&2
        echo "" >&2
    fi
}

case "${1:-}" in
    post-tool)
        count=$(increment_counter)

        # Only check tokens every N calls (23ms per check is fine, but no need every call)
        if [ $((count % TOKEN_CHECK_INTERVAL)) -eq 0 ] || [ "$count" -eq 1 ]; then
            have_tokens=false
            transcript=$(find_transcript 2>/dev/null) || true
            if [ -n "${transcript:-}" ]; then
                tokens=$(get_context_tokens "$transcript") || true
                if [ "${tokens:-0}" -gt 0 ]; then
                    warn_by_tokens "$tokens"
                    have_tokens=true
                fi
            fi

            # Fallback: tool-call warnings (only if no token data)
            if [ "$have_tokens" = false ]; then
                warn_by_calls "$count"
            fi
        fi

        exit 0
        ;;
    reset)
        ensure_counter
        echo "0" > "$COUNTER_FILE"
        echo "Counter reset."
        ;;
    status)
        ensure_counter
        echo "Tool calls since last commit: $(tr -d '[:space:]' < "$COUNTER_FILE")"
        transcript=$(find_transcript 2>/dev/null) || true
        if [ -n "${transcript:-}" ]; then
            tokens=$(get_context_tokens "$transcript") || true
            if [ "${tokens:-0}" -gt 0 ]; then
                pct=$((tokens * 100 / 200000))
                echo "Context tokens: ${tokens} (~${pct}% of 200K window)"
            else
                echo "Context tokens: unavailable (no usage data)"
            fi
        else
            echo "Context tokens: unavailable (no transcript)"
        fi
        ;;
    *)
        echo "Usage: checkpoint.sh {post-tool|reset|status}"
        exit 1
        ;;
esac
