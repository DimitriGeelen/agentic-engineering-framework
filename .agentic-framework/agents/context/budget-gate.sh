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
    if [ "${FW_CLAUDE_FW_SUPERVISED:-0}" != "1" ]; then
        echo "  ⚠ Unsupervised session (not under claude-fw): the budget auto-restart loop will NOT fire." >&2
        echo "    Relaunch via 'claude-fw' for hands-off recovery, or run '/compact' before you hit critical." >&2
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
is_allowed_cmd = bool(re.search(r'(git\s+commit|git\s+add|git\s+push|git\s+fetch|git\s+(status|log|diff)|fw\s+(handover|git|context\s+init|resume|task)|context\.sh\s+init|resume\.sh|checkpoint\.sh|budget-gate\.sh|handover\.sh|update-task\.sh|echo\s+0\s*>)', command)) if command else False
is_read_tool = tool_name in ('Read', 'Glob', 'Grep')

# At critical, allow Write/Edit to wrap-up paths (handover, tasks, context)
# but block writing feature code. This distinguishes 'new work' from 'wrap-up'.
file_path = data.get('tool_input', {}).get('file_path', '')
is_wrapup_write = tool_name in ('Write', 'Edit') and any(p in file_path for p in ['.context/', '.tasks/', '.claude/']) if file_path else False

print(f'{level} {tokens} {age} {tool_name} {\"allowed\" if (is_allowed_cmd or is_read_tool or is_wrapup_write) else \"blocked\"}')
" 2>/dev/null)

# Parse result
STATUS_LEVEL=$(echo "$RESULT" | awk '{print $1}')
STATUS_TOKENS=$(echo "$RESULT" | awk '{print $2}')
STATUS_AGE=$(echo "$RESULT" | awk '{print $3}')
# shellcheck disable=SC2034 # TOOL_NAME available for debug logging
TOOL_NAME=$(echo "$RESULT" | awk '{print $4}')
CMD_CLASS=$(echo "$RESULT" | awk '{print $5}')

# Default to safe values if Python failed
STATUS_LEVEL=${STATUS_LEVEL:-unknown}
STATUS_TOKENS=${STATUS_TOKENS:-0}
STATUS_AGE=${STATUS_AGE:-999}
CMD_CLASS=${CMD_CLASS:-blocked}

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
            echo "Note: Context at ~${STATUS_TOKENS} tokens (~$((STATUS_TOKENS * 100 / CONTEXT_WINDOW))%). Commit before starting new work." >&2
            _supervision_notice
            exit 0
            ;;
        urgent)
            echo "WARNING: Context at ~${STATUS_TOKENS} tokens (~$((STATUS_TOKENS * 100 / CONTEXT_WINDOW))%). Do not start new work. Commit and handover." >&2
            _supervision_notice
            exit 0
            ;;
        critical)
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
            echo "" >&2
            echo "  Action: Commit your work, then run '$(_fw_cmd) handover'" >&2
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

# Read tokens + write status + determine action — single Python call
# T-1088: Filter usage entries by .session-start-ts to exclude pre-compact
# entries from the same JSONL (claude -c continues the same file, so the
# "last usage" scan can pick up pre-compact entries). ISO-8601 Z timestamps
# sort lexically in chronological order — no parsing needed. Falls back to
# no-filter if the file is missing (backward compat with fresh installs).
SLOW_RESULT=$(tail -c 10000000 "$TRANSCRIPT" 2>/dev/null | python3 -c "
import sys, json, time, os

# T-1088: Read session-start timestamp if present.
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
        # T-2322: detect compact_boundary in the transcript itself — single source
        # of truth. Resets t so pre-compact usage is discarded even when the
        # T-1088 sidecar (.session-start-ts) is missing/stale/empty. Mirrors the
        # behavior /compact has on the live token budget (post-compact starts
        # near zero until first real usage entry lands). Complements (does not
        # replace) the T-1088 sidecar filter below — both run in this loop.
        if e.get('type') == 'system' and e.get('subtype') == 'compact_boundary':
            t = 0
            continue
        model = e.get('message', {}).get('model', '')
        if model == '<synthetic>' or model.startswith('<'):
            continue
        # T-1088: Skip entries from before session start (pre-compact entries
        # in the same JSONL). String comparison works for ISO-8601 Z format.
        if session_start_ts:
            entry_ts = e.get('timestamp', '')
            if entry_ts and entry_ts < session_start_ts:
                continue
        u = e.get('message', {}).get('usage')
        if u and 'input_tokens' in u:
            t = u['input_tokens'] + u.get('cache_read_input_tokens', 0) + u.get('cache_creation_input_tokens', 0)
    except: pass

# Determine level
level = 'ok'
if t >= $TOKEN_CRITICAL:
    level = 'critical'
elif t >= $TOKEN_URGENT:
    level = 'urgent'
elif t >= $TOKEN_WARN:
    level = 'warn'

# Write status file
status = {'level': level, 'tokens': t, 'timestamp': int(time.time()), 'source': 'budget-gate'}
try:
    with open('$STATUS_FILE', 'w') as f:
        json.dump(status, f)
except: pass

print(f'{level} {t}')
" 2>/dev/null)

LEVEL=$(echo "$SLOW_RESULT" | awk '{print $1}')
TOKENS=$(echo "$SLOW_RESULT" | awk '{print $2}')
LEVEL=${LEVEL:-ok}
TOKENS=${TOKENS:-0}

case "$LEVEL" in
    ok)
        exit 0
        ;;
    warn)
        echo "Note: Context at ${TOKENS} tokens (~$((TOKENS * 100 / CONTEXT_WINDOW))%). Commit before starting new work." >&2
        _supervision_notice
        exit 0
        ;;
    urgent)
        echo "WARNING: Context at ${TOKENS} tokens (~$((TOKENS * 100 / CONTEXT_WINDOW))%). Do not start new work. Commit and handover." >&2
        _supervision_notice
        exit 0
        ;;
    critical)
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
        echo "" >&2
        echo "  Action: Commit your work, then run '$(_fw_cmd) handover'" >&2
        _supervision_notice
        echo "══════════════════════════════════════════════════════════" >&2
        echo "" >&2
        _write_restart_signal "$TOKENS"   # T-2403: arm autonomous restart
        exit 2
        ;;
esac
