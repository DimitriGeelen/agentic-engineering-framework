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

# Find current session JSONL transcript.
# T-2377: prefer the authoritative transcript_path that Claude Code passes to
# hooks on stdin (first arg here). Reconstructing the dir from PROJECT_ROOT is
# WRONG in git worktrees / background jobs — Claude Code keys the transcript dir
# on the session's LAUNCH cwd (the main repo), not the worktree's PROJECT_ROOT,
# so the gauge searched an empty/stale sibling dir and went blind (the loop never
# armed). Sibling hooks (subagent-stop.sh, chat-bare-path-scan.sh, session-end.sh)
# already consume stdin transcript_path; this brings the gauge into line.
# Reconstruction (T-2375 encoding fix + T-791 project scoping) remains the
# fallback for manual `status` invocation where no stdin path is available.
find_transcript() {
    local explicit="${1:-}"
    if [ -n "$explicit" ] && [ -f "$explicit" ]; then
        echo "$explicit"
        return 0
    fi
    # T-2375: match Claude Code's dir encoding (every non-alnum → '-', incl. '.').
    # T-2392: search ALL candidate project dirs — the PROJECT_ROOT-keyed dir AND
    # the primary-worktree (main-repo) dir Claude Code actually launched from —
    # then pick the GLOBALLY-newest transcript across them. Reconstructing from
    # PROJECT_ROOT alone is blind in worktree sessions (the live transcript lives
    # in the main-repo-keyed dir).
    local transcript
    transcript=$(
        while IFS= read -r d; do
            find "$d" -maxdepth 1 -name "*.jsonl" -type f ! -name "agent-*" -print0 2>/dev/null
        done < <(fw_claude_project_dirs) | xargs -r -0 ls -t 2>/dev/null | head -1
    )
    if [ -n "$transcript" ]; then
        echo "$transcript"
    fi
}

# Read effective context size for THIS conversation via the shared scan
# (T-2885, lib/context_tokens.py) — also used by budget-gate.sh, so the two
# gauges cannot drift apart again. Scopes usage entries to the dominant model
# since the last compact_boundary (not the newest raw entry), which is what
# resets this reading across a compaction — a reset checkpoint.sh's own
# inline copy never received (only budget-gate.sh's did, per T-2322).
# Uses tail -c (O(1) seek) so a 30MB transcript stays a ~2MB scan window.
get_context_tokens() {
    local transcript="$1"
    local session_start_ts=""
    local ts_file="$CONTEXT_DIR/working/.session-start-ts"
    if [ -f "$ts_file" ]; then
        session_start_ts=$(tr -d '[:space:]' < "$ts_file" 2>/dev/null) || session_start_ts=""
    fi
    tail -c 10000000 "$transcript" 2>/dev/null | python3 "$FRAMEWORK_ROOT/lib/context_tokens.py" "$session_start_ts" 2>/dev/null
}

warn_by_tokens() {
    local tokens="$1"
    local pct=$((tokens * 100 / CONTEXT_WINDOW))

    if [ "$tokens" -ge "$TOKEN_CRITICAL" ]; then
        echo "" >&2
        echo "===========================================" >&2
        echo "Session wrapping up: ${tokens} tokens (~${pct}% of context window)." >&2
        echo "Task files have all essential state. Commit and handover." >&2
        echo "Details: docs/context-compaction.md (budget ladder, what handover/compact capture)" >&2
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
            # T-1277: belt-and-braces — even with handover.sh's per-push timeout,
            # bound the total auto-handover wall time so the PostToolUse hook
            # cannot stall the Claude Code session for hours on slow networks.
            # Default 60s (push×N + commit + audit + handover write).
            _ah_total_timeout="${FW_HANDOVER_TOTAL_TIMEOUT:-60}"
            # T-2506: `bash <script>`, not bare exec — the budget-critical auto-handover
            # is the OTHER silent memory-capture path (T-179). A missing exec bit on the
            # vendored handover.sh would drop it exactly like pre-compact did. Interpreter
            # invocation makes it exec-bit-immune. Same class as pre-compact.sh fix.
            # T-2507: capture output to a durable file and branch on the handover's
            # TRUE exit code, then RECORD success/FAILED to the same .compact-log fw
            # doctor Check 5d reads. The budget-critical auto-handover failure was
            # echo-to-stderr ONLY (not-even-recorded) — the most catastrophic
            # memory-loss path, since the session is about to auto-restart. Now a
            # failed budget-critical handover surfaces exactly like a failed
            # pre-compact one. Sibling to T-2506 (pre-compact) / T-2374 (honest log).
            _ah_capture="$CONTEXT_DIR/working/.checkpoint.handover.stderr"
            _ah_log="$CONTEXT_DIR/working/.compact-log"
            _ah_ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
            if timeout "$_ah_total_timeout" bash "$FRAMEWORK_ROOT/agents/handover/handover.sh" --commit >"$_ah_capture" 2>&1; then
                tail -5 "$_ah_capture" >&2 2>/dev/null || true
                echo "[checkpoint] [auto] Handover generated at $_ah_ts" >> "$_ah_log" 2>/dev/null || true
                echo "AUTO-HANDOVER: Handover committed. Fill [TODO] sections, then re-commit." >&2
                # T-186: Write restart signal for wrapper script (T-179 auto-restart)
                local restart_signal="$CONTEXT_DIR/working/.restart-requested"
                local session_id=""
                if [ -f "$CONTEXT_DIR/working/session.yaml" ]; then
                    session_id=$(grep "^session_id:" "$CONTEXT_DIR/working/session.yaml" 2>/dev/null | cut -d: -f2 | tr -d ' ') || true
                fi
                # T-2363 (T-2158 S1): if .next-directive.yaml exists, fold its
                # `directive:` value into the restart signal so the resumed
                # session can pick it up. Absent file → JSON shape unchanged
                # (backward-compat with all pre-T-2363 sessions and old
                # claude-fw wrapper versions, which ignore unknown JSON keys).
                local _directive_file="$CONTEXT_DIR/working/.next-directive.yaml"
                local _directive_json=""
                if [ -f "$_directive_file" ]; then
                    _directive_json=$(python3 -c "
import yaml, json, sys
try:
    with open('$_directive_file') as f:
        d = yaml.safe_load(f) or {}
    v = d.get('directive')
    if isinstance(v, str) and v.strip():
        print(',\"directive\":' + json.dumps(v.strip()))
except Exception:
    pass
" 2>/dev/null) || _directive_json=""
                fi
                cat > "$restart_signal" << SIGNAL_EOF
{"timestamp":"$(date -u +%Y-%m-%dT%H:%M:%SZ)","session_id":"${session_id:-unknown}","reason":"critical_budget_auto_handover","tokens":${tokens:-0}${_directive_json}}
SIGNAL_EOF
                echo "AUTO-RESTART: Signal written — wrapper will auto-restart on exit." >&2
            else
                tail -5 "$_ah_capture" >&2 2>/dev/null || true
                echo "[checkpoint] [auto] Handover FAILED at $_ah_ts — see $_ah_capture" >> "$_ah_log" 2>/dev/null || true
                echo "AUTO-HANDOVER: Failed — run '$(_fw_cmd) handover' manually." >&2
            fi
            rm -f "$handover_lock"
        fi
    elif [ "$tokens" -ge "$TOKEN_URGENT" ]; then
        echo "" >&2
        echo "WARNING: Context at ${tokens} tokens (~${pct}% of context window)." >&2
        echo "BUDGET: Do not start new implementation work. Commit and handover." >&2
        echo "ACTION: Commit work, then '$(_fw_cmd) handover --checkpoint'" >&2
        echo "Details: docs/context-compaction.md (budget ladder, what to do at each level)" >&2
        echo "" >&2
    elif [ "$tokens" -ge "$TOKEN_WARN" ]; then
        echo "" >&2
        echo "Note: Context at ${tokens} tokens (~${pct}%)." >&2
        echo "BUDGET: Propose only small, bounded tasks. Commit before starting new work. (docs/context-compaction.md)" >&2
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
            echo "The auto-injected recovery banner you may have seen is a ~2KB PREVIEW of a" >&2
            echo "much larger (30-50KB) payload — most of it never reached you. Do not treat" >&2
            echo "that banner as complete." >&2
            echo "ACTION: Run '$(_fw_cmd) resume status' then '$(_fw_cmd) resume sync' — these" >&2
            echo "read the full state from disk, not the truncated preview." >&2
            echo "Details: docs/context-compaction.md" >&2
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
        echo "ACTION: Commit now, then '$(_fw_cmd) handover'." >&2
        echo "===========================================" >&2
        echo "" >&2
    elif [ "$count" -ge "$CALL_URGENT" ]; then
        echo "" >&2
        echo "WARNING: $count tool calls since last commit (no token data)." >&2
        echo "Consider: $(_fw_cmd) handover --checkpoint" >&2
        echo "" >&2
    elif [ "$count" -ge "$CALL_WARN" ]; then
        echo "" >&2
        echo "Note: $count tool calls since last commit." >&2
        echo "" >&2
    fi
}

case "${1:-}" in
    post-tool)
        # T-2377: capture the hook stdin JSON so we can use the authoritative
        # transcript_path. Correct in worktrees / bg jobs where PROJECT_ROOT-based
        # reconstruction points at the wrong (launch-cwd) project dir. FW_TRANSCRIPT_PATH
        # is an explicit override for tests / manual runs.
        HOOK_INPUT=$(cat 2>/dev/null || true)
        HOOK_TRANSCRIPT=$(printf '%s' "$HOOK_INPUT" | python3 -c "
import sys, json
try: print(json.load(sys.stdin).get('transcript_path') or '')
except Exception: print('')
" 2>/dev/null) || HOOK_TRANSCRIPT=""
        HOOK_TRANSCRIPT="${HOOK_TRANSCRIPT:-${FW_TRANSCRIPT_PATH:-}}"

        count=$(increment_counter)

        # Only check tokens every N calls (23ms per check is fine, but no need every call)
        if [ $((count % TOKEN_CHECK_INTERVAL)) -eq 0 ] || [ "$count" -eq 1 ]; then
            have_tokens=false
            transcript=$(find_transcript "$HOOK_TRANSCRIPT" 2>/dev/null) || true
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
                        # T-1158: Portable date conversion
                        source "${FRAMEWORK_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}/lib/compat.sh" 2>/dev/null || true
                        resp_epoch=$(_date_to_epoch "$responded_at" 2>/dev/null) || resp_epoch=0
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
        # T-2377: honor an explicit transcript path (FW_TRANSCRIPT_PATH) for manual
        # runs; falls back to reconstruction when unset.
        transcript=$(find_transcript "${FW_TRANSCRIPT_PATH:-}" 2>/dev/null) || true
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
