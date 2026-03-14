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
source "$FRAMEWORK_ROOT/lib/paths.sh"
COUNTER_FILE="$CONTEXT_DIR/working/.tool-counter"
PREV_TOKENS_FILE="$CONTEXT_DIR/working/.prev-token-reading"

# Context window size — 1M GA for Opus 4.6 / Sonnet 4.6 (2026-03-13, T-478)
CONTEXT_WINDOW=${CONTEXT_WINDOW:-1000000}

# Token thresholds (autoCompact disabled — D-027)
# Proportional to window size. Critical leaves ~100K for handover routine.
TOKEN_WARN=$((CONTEXT_WINDOW * 60 / 100))        # ~60% (600K at 1M) — informational
TOKEN_URGENT=$((CONTEXT_WINDOW * 80 / 100))      # ~80% (800K at 1M) — commit + checkpoint
TOKEN_CRITICAL=$((CONTEXT_WINDOW * 90 / 100))    # ~90% (900K at 1M) — handover NOW

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

# Find current session JSONL transcript.
# Always finds the most-recently-modified transcript (~23ms) to avoid stale
# cache hits from previous sessions. The old caching approach checked file
# existence but not recency, so it silently returned old transcripts.
find_transcript() {
    local transcript
    transcript=$(find ~/.claude/projects -name "*.jsonl" -type f ! -name "agent-*" 2>/dev/null | xargs ls -t 2>/dev/null | head -1)
    if [ -n "$transcript" ]; then
        echo "$transcript"
    fi
}

# Read effective context size from the last REAL API response in the transcript.
# Uses tail -c (O(1) seek) + python3 JSON parsing for accuracy.
# grep alone can't distinguish usage data from command text containing "input_tokens".
# Performance: ~30ms on a 30MB transcript (2MB tail window).
#
# Filters out <synthetic> model entries which Claude Code writes after compaction
# with 0 tokens — taking the last such entry would hide that context was just destroyed.
get_context_tokens() {
    local transcript="$1"
    tail -c 10000000 "$transcript" 2>/dev/null | python3 -c "
import sys, json
t = 0
for line in sys.stdin:
    try:
        e = json.loads(line)
        # Skip synthetic entries (written after compaction, report 0 tokens)
        model = e.get('message', {}).get('model', '')
        if model == '<synthetic>' or model.startswith('<'):
            continue
        u = e.get('message', {}).get('usage')
        if u and 'input_tokens' in u:
            t = u['input_tokens'] + u.get('cache_read_input_tokens', 0) + u.get('cache_creation_input_tokens', 0)
    except: pass
print(t)
" 2>/dev/null
}

warn_by_tokens() {
    local tokens="$1"
    local pct=$((tokens * 100 / CONTEXT_WINDOW))

    if [ "$tokens" -ge "$TOKEN_CRITICAL" ]; then
        echo "" >&2
        echo "===========================================" >&2
        echo "Session wrapping up: ${tokens} tokens (~${pct}% of context window)." >&2
        echo "Task files have all essential state. Commit and handover." >&2
        echo "===========================================" >&2
        echo "" >&2

        # --- Auto-trigger handover at critical (T-136) ---
        # Agent cannot be trusted to act on warnings at critical level.
        # Two guards:
        #   1. Re-entry lock: prevents recursive triggering within one checkpoint run
        #   2. Cooldown file: prevents re-firing for 10 minutes after last handover
        #      (Bug fix: without cooldown, every subsequent tool call re-triggers
        #       because tokens stay above critical — caused 23 handover commits in sprechloop)
        local handover_lock="$CONTEXT_DIR/working/.handover-in-progress"
        local handover_cooldown="$CONTEXT_DIR/working/.handover-cooldown"
        local COOLDOWN_SECONDS=600  # 10 minutes

        local should_fire=true
        if [ -f "$handover_lock" ]; then
            should_fire=false
        elif [ -f "$handover_cooldown" ]; then
            local last_fired
            last_fired=$(cat "$handover_cooldown" 2>/dev/null | tr -d '[:space:]')
            local now
            now=$(date +%s)
            if [ -n "$last_fired" ] && [ $((now - last_fired)) -lt "$COOLDOWN_SECONDS" ]; then
                should_fire=false
            fi
        fi

        if [ "$should_fire" = true ]; then
            echo "AUTO-HANDOVER: Triggering handover..." >&2
            echo "1" > "$handover_lock"
            date +%s > "$handover_cooldown"
            if "$FRAMEWORK_ROOT/agents/handover/handover.sh" --commit 2>&1 | tail -5 >&2; then
                echo "AUTO-HANDOVER: Handover committed. Fill [TODO] sections, then re-commit." >&2
                # T-186: Write restart signal for wrapper script (T-179 auto-restart)
                local restart_signal="$CONTEXT_DIR/working/.restart-requested"
                local session_id=""
                if [ -f "$CONTEXT_DIR/working/session.yaml" ]; then
                    session_id=$(grep "^session_id:" "$CONTEXT_DIR/working/session.yaml" 2>/dev/null | cut -d: -f2 | tr -d ' ') || true
                fi
                cat > "$restart_signal" << SIGNAL_EOF
{"timestamp":"$(date -u +%Y-%m-%dT%H:%M:%SZ)","session_id":"${session_id:-unknown}","reason":"critical_budget_auto_handover","tokens":${tokens:-0}}
SIGNAL_EOF
                echo "AUTO-RESTART: Signal written — wrapper will auto-restart on exit." >&2
            else
                echo "AUTO-HANDOVER: Failed — run 'fw handover' manually." >&2
            fi
            rm -f "$handover_lock"
        fi
    elif [ "$tokens" -ge "$TOKEN_URGENT" ]; then
        echo "" >&2
        echo "WARNING: Context at ${tokens} tokens (~${pct}% of context window)." >&2
        echo "BUDGET: Do not start new implementation work. Commit and handover." >&2
        echo "ACTION: Commit work, then 'fw handover --checkpoint'" >&2
        echo "" >&2
    elif [ "$tokens" -ge "$TOKEN_WARN" ]; then
        echo "" >&2
        echo "Note: Context at ${tokens} tokens (~${pct}%)." >&2
        echo "BUDGET: Propose only small, bounded tasks. Commit before starting new work." >&2
        echo "" >&2
    fi
}

# Detect compaction: if previous reading was >100K and current is 0 or <10K,
# context was just compacted (summarized). This is a critical event because
# the agent's working memory has been destroyed.
# Note: Still useful with auto-compaction disabled (D-027) — detects manual /compact
# events and alerts the agent to run resume. Not dead code.
detect_compaction() {
    local tokens="$1"
    if [ -f "$PREV_TOKENS_FILE" ]; then
        local prev
        prev=$(tr -d '[:space:]' < "$PREV_TOKENS_FILE" 2>/dev/null) || prev=0
        if [ "${prev:-0}" -gt 100000 ] && [ "$tokens" -lt 10000 ]; then
            echo "" >&2
            echo "===========================================" >&2
            echo "COMPACTION DETECTED: Tokens dropped ${prev} -> ${tokens}." >&2
            echo "Context was summarized — working memory is lost." >&2
            echo "ACTION: Run 'fw resume status' then 'fw resume sync'." >&2
            echo "===========================================" >&2
            echo "" >&2
        fi
    fi
    echo "$tokens" > "$PREV_TOKENS_FILE"
}

warn_by_calls() {
    local count="$1"
    if [ "$count" -ge "$CALL_CRITICAL" ]; then
        echo "" >&2
        echo "===========================================" >&2
        echo "CRITICAL: $count tool calls since last commit (no token data)." >&2
        echo "ACTION: Commit now, then 'fw handover'." >&2
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
                    detect_compaction "$tokens"
                    warn_by_tokens "$tokens"
                    have_tokens=true
                elif [ -f "$PREV_TOKENS_FILE" ]; then
                    # Token reading is 0 but we had a previous reading — possible compaction
                    detect_compaction 0
                fi
            fi

            # Fallback: tool-call warnings (only if no token data)
            if [ "$have_tokens" = false ]; then
                warn_by_calls "$count"
            fi
        fi

        # --- Research Capture Checkpoint (C-003, T-194) ---
        # Every 20 tool calls, check if focused inception task has uncommitted research
        INCEPTION_RESEARCH_INTERVAL=20
        if [ $((count % INCEPTION_RESEARCH_INTERVAL)) -eq 0 ]; then
            FOCUS_FILE="$CONTEXT_DIR/working/focus.yaml"
            if [ -f "$FOCUS_FILE" ]; then
                focus_task=$(grep '^task_id:' "$FOCUS_FILE" 2>/dev/null | sed 's/task_id: *//' | tr -d ' "') || true
                if [ -n "$focus_task" ]; then
                    focus_task_file=$(find "$PROJECT_ROOT/.tasks" -name "${focus_task}-*" -type f 2>/dev/null | head -1)
                    if [ -n "$focus_task_file" ] && grep -q "^workflow_type: inception" "$focus_task_file" 2>/dev/null; then
                        # Check if research artifact has uncommitted changes or exists in working tree
                        has_research_change=$(git -C "$PROJECT_ROOT" diff --name-only 2>/dev/null | grep "^docs/reports/${focus_task}" || true)
                        has_staged_research=$(git -C "$PROJECT_ROOT" diff --cached --name-only 2>/dev/null | grep "^docs/reports/${focus_task}" || true)
                        if [ -z "$has_research_change" ] && [ -z "$has_staged_research" ]; then
                            # Also check if artifact exists at all
                            has_artifact=$(find "$PROJECT_ROOT/docs/reports/" -name "${focus_task}-*" -type f 2>/dev/null | head -1)
                            if [ -z "$has_artifact" ]; then
                                echo "" >&2
                                echo "NOTE: Inception checkpoint (C-003) — $count tool calls on $focus_task, no research artifact in docs/reports/" >&2
                                echo "  Create: docs/reports/${focus_task}-*.md (the thinking trail IS the artifact)" >&2
                                echo "" >&2
                            else
                                # Artifact exists but hasn't been modified — might be stale
                                artifact_age=$(( $(date +%s) - $(stat -c %Y "$has_artifact" 2>/dev/null || echo 0) ))
                                if [ "$artifact_age" -gt 1800 ]; then  # 30 min
                                    echo "" >&2
                                    echo "NOTE: Inception checkpoint (C-003) — research artifact for $focus_task not updated in $((artifact_age / 60))min" >&2
                                    echo "  Consider updating: $has_artifact" >&2
                                    echo "" >&2
                                fi
                            fi
                            # Log the prompt
                            echo "$(date -Iseconds) $focus_task prompted counter=$count" >> "$CONTEXT_DIR/working/.inception-checkpoint-log" 2>/dev/null || true
                        fi
                    fi
                fi
            fi
        fi

        exit 0
        ;;
    reset)
        # Clear all session-specific state.
        # Note: `fw context init` should call `checkpoint.sh reset` at session start
        # to ensure clean state. Bug 1 fix (no transcript cache) handles stale
        # transcripts regardless, but clearing prev-tokens prevents false compaction alerts.
        ensure_counter
        echo "0" > "$COUNTER_FILE"
        rm -f "$PREV_TOKENS_FILE"
        rm -f "$CONTEXT_DIR/working/.restart-requested"  # T-186: clean up restart signal
        echo "Counter reset."
        ;;
    status)
        ensure_counter
        echo "Tool calls since last commit: $(tr -d '[:space:]' < "$COUNTER_FILE")"
        transcript=$(find_transcript 2>/dev/null) || true
        if [ -n "${transcript:-}" ]; then
            tokens=$(get_context_tokens "$transcript") || true
            if [ "${tokens:-0}" -gt 0 ]; then
                pct=$((tokens * 100 / CONTEXT_WINDOW))
                echo "Context tokens: ${tokens} (~${pct}% of context window)"
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
