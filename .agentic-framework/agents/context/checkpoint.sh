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
source "$FRAMEWORK_ROOT/lib/config.sh"
fw_hook_crash_trap "checkpoint"
COUNTER_FILE="$CONTEXT_DIR/working/.tool-counter"
PREV_TOKENS_FILE="$CONTEXT_DIR/working/.prev-token-reading"

# Context window size — conservative default, override via FW_CONTEXT_WINDOW.
# Opus 4.6 supports 1M but 300K is a safe default for quality + cost control.
CONTEXT_WINDOW=$(fw_config_int "CONTEXT_WINDOW" 300000)

# Token thresholds (autoCompact disabled — D-027)
TOKEN_WARN=$((CONTEXT_WINDOW * 75 / 100))        # ~75% (225K at 300K) — informational
TOKEN_URGENT=$((CONTEXT_WINDOW * 85 / 100))      # ~85% (255K at 300K) — commit + checkpoint
TOKEN_CRITICAL=$((CONTEXT_WINDOW * 95 / 100))    # ~95% (285K at 300K) — handover NOW

# Check tokens every N tool calls (balance: accuracy vs performance)
TOKEN_CHECK_INTERVAL=$(fw_config_int "TOKEN_CHECK_INTERVAL" 5)

# Fallback tool call thresholds (only used when transcript unavailable)
CALL_WARN=$(fw_config_int "CALL_WARN" 40)
CALL_URGENT=$(fw_config_int "CALL_URGENT" 60)
CALL_CRITICAL=$(fw_config_int "CALL_CRITICAL" 80)

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

# Find current session JSONL transcript — scoped to THIS project.
# Uses PROJECT_ROOT to derive the Claude Code project directory name,
# matching the pattern in budget-gate.sh. Without project scoping,
# find_transcript picks up transcripts from other projects (T-791).
find_transcript() {
    local project_dir_name
    project_dir_name="${PROJECT_ROOT:-$FRAMEWORK_ROOT}"
    project_dir_name="${project_dir_name//\//-}"
    local project_jsonl_dir="$HOME/.claude/projects/${project_dir_name}"
    if [ -d "$project_jsonl_dir" ]; then
        local transcript
        transcript=$(find "$project_jsonl_dir" -maxdepth 1 -name "*.jsonl" -type f ! -name "agent-*" -print0 2>/dev/null | xargs -r -0 ls -t 2>/dev/null | head -1)
        if [ -n "$transcript" ]; then
            echo "$transcript"
        fi
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
import sys, json, os
# T-1088: Read session-start timestamp if present, filter pre-compact entries.
# claude -c continues the same JSONL, so the 'last usage' scan can otherwise
# pick up pre-compact entries. ISO-8601 Z sorts lexically — no parsing needed.
session_start_ts = ''
ts_file = '$CONTEXT_DIR/working/.session-start-ts'
if os.path.exists(ts_file):
    try:
        with open(ts_file) as sf:
            session_start_ts = sf.read().strip()
    except: pass

t = 0
for line in sys.stdin:
    try:
        e = json.loads(line)
        # Skip synthetic entries (written after compaction, report 0 tokens)
        model = e.get('message', {}).get('model', '')
        if model == '<synthetic>' or model.startswith('<'):
            continue
        # T-1088: skip pre-session-start entries (e.g., pre-compact).
        if session_start_ts:
            entry_ts = e.get('timestamp', '')
            if entry_ts and entry_ts < session_start_ts:
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
        local COOLDOWN_SECONDS
        COOLDOWN_SECONDS=$(fw_config_int "HANDOVER_COOLDOWN" 600)

        local should_fire=true
        if [ -f "$handover_lock" ]; then
            should_fire=false
        elif [ -f "$handover_cooldown" ]; then
            local last_fired
            last_fired=$(tr -d '[:space:]' < "$handover_cooldown" 2>/dev/null)
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

        # --- Approval Notification (T-691, Gap 1 from T-636 research) ---
        # Check for resolved Watchtower approvals the agent hasn't seen yet.
        # When a human approves in Watchtower, the agent has no way to know
        # unless it retries the command. This closes the feedback loop.
        APPROVAL_CHECK_INTERVAL=3
        if [ $((count % APPROVAL_CHECK_INTERVAL)) -eq 0 ]; then
            APPROVALS_DIR="$PROJECT_ROOT/.context/approvals"
            NOTIFIED_FILE="$CONTEXT_DIR/working/.approval-notified"
            touch "$NOTIFIED_FILE" 2>/dev/null || true

            if [ -d "$APPROVALS_DIR" ]; then
                for resolved in "$APPROVALS_DIR"/resolved-*.yaml; do
                    [ -f "$resolved" ] || continue
                    basename_f=$(basename "$resolved")

                    # Skip if already notified
                    grep -qF "$basename_f" "$NOTIFIED_FILE" 2>/dev/null && continue

                    # Check if approved (not consumed/expired/rejected)
                    file_status=$(grep '^status:' "$resolved" 2>/dev/null | head -1 | sed 's/status: *//')
                    [ "$file_status" = "approved" ] || continue

                    # Check age — only notify for approvals < 1 hour old
                    responded_at=$(grep 'responded_at:' "$resolved" 2>/dev/null | head -1 | sed "s/.*responded_at: *'\\{0,1\\}//;s/'.*//")
                    if [ -n "$responded_at" ]; then
                        resp_epoch=$(date -d "$responded_at" +%s 2>/dev/null) || resp_epoch=0
                        now_epoch=$(date +%s)
                        age=$(( now_epoch - resp_epoch ))
                        [ "$age" -gt 3600 ] && continue
                    fi

                    # Extract command preview for the notification
                    cmd_preview=$(grep 'command_preview:' "$resolved" 2>/dev/null | head -1 | sed 's/command_preview: *//')

                    echo "" >&2
                    echo "────────────────────────────────────────────" >&2
                    echo "  APPROVAL READY — Human approved in Watchtower" >&2
                    echo "  Command: ${cmd_preview:0:120}" >&2
                    echo "  Action: Retry the blocked command now." >&2
                    echo "────────────────────────────────────────────" >&2
                    echo "" >&2

                    # Mark as notified
                    echo "$basename_f" >> "$NOTIFIED_FILE"
                done

                # --- Stale pending cleanup (Gap 3 from T-636 research) ---
                # Remove pending files older than 2 hours
                STALE_AGE=7200
                for pending in "$APPROVALS_DIR"/pending-*.yaml; do
                    [ -f "$pending" ] || continue
                    file_age=$(( $(date +%s) - $(stat -c %Y "$pending" 2>/dev/null || echo 0) ))
                    if [ "$file_age" -gt "$STALE_AGE" ]; then
                        rm -f "$pending"
                    fi
                done

                # --- Stale resolved cleanup (T-694) ---
                # Remove resolved files older than 7 days (bypass-log.yaml is the permanent record)
                STALE_RESOLVED_AGE=604800
                for resolved_old in "$APPROVALS_DIR"/resolved-*.yaml; do
                    [ -f "$resolved_old" ] || continue
                    file_age=$(( $(date +%s) - $(stat -c %Y "$resolved_old" 2>/dev/null || echo 0) ))
                    if [ "$file_age" -gt "$STALE_RESOLVED_AGE" ]; then
                        rm -f "$resolved_old"
                    fi
                done
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
        rm -f "$CONTEXT_DIR/working/.approval-notified"  # T-694: reset approval notification tracker
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
