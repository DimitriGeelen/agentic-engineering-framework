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

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PROJECT_ROOT="${PROJECT_ROOT:-$FRAMEWORK_ROOT}"
CONTEXT_DIR="$PROJECT_ROOT/.context"
STATUS_FILE="$CONTEXT_DIR/working/.budget-status"
GATE_COUNTER_FILE="$CONTEXT_DIR/working/.budget-gate-counter"

# Token thresholds (200K context window, autoCompact disabled — D-027)
# 170K critical leaves 30K for handover routine (commit + handover generation)
TOKEN_WARN=120000      # ~60%
TOKEN_URGENT=150000    # ~75%
TOKEN_CRITICAL=170000  # ~85%

# How often to re-read the transcript (every Nth tool call)
RECHECK_INTERVAL=5

# Max age of .budget-status before considering it stale (seconds)
STATUS_MAX_AGE=90

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
is_allowed_cmd = bool(re.search(r'(git\s+commit|git\s+add|git\s+(status|log|diff)|fw\s+(handover|git|context\s+init|resume|task)|context\.sh\s+init|resume\.sh|checkpoint\.sh|budget-gate\.sh|handover\.sh|update-task\.sh|echo\s+0\s*>)', command)) if command else False
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
TOOL_NAME=$(echo "$RESULT" | awk '{print $4}')
CMD_CLASS=$(echo "$RESULT" | awk '{print $5}')

# Default to safe values if Python failed
STATUS_LEVEL=${STATUS_LEVEL:-unknown}
STATUS_TOKENS=${STATUS_TOKENS:-0}
STATUS_AGE=${STATUS_AGE:-999}
CMD_CLASS=${CMD_CLASS:-blocked}

# --- Fast path: use cached status if fresh ---
# Even stale status enforces critical (Bug 3 fix: stale critical still blocks)
if [ "${STATUS_AGE}" -lt "$STATUS_MAX_AGE" ] || [ "$STATUS_LEVEL" = "critical" ]; then
    case "$STATUS_LEVEL" in
        ok)
            exit 0
            ;;
        warn)
            echo "Note: Context at ~${STATUS_TOKENS} tokens (~$((STATUS_TOKENS * 100 / 200000))%). Commit before starting new work." >&2
            exit 0
            ;;
        urgent)
            echo "WARNING: Context at ~${STATUS_TOKENS} tokens (~$((STATUS_TOKENS * 100 / 200000))%). Do not start new work. Commit and handover." >&2
            exit 0
            ;;
        critical)
            if [ "$CMD_CLASS" = "allowed" ]; then
                exit 0
            fi
            echo "" >&2
            echo "══════════════════════════════════════════════════════════" >&2
            echo "  BUDGET GATE — Context Critical (~${STATUS_TOKENS} tokens)" >&2
            echo "══════════════════════════════════════════════════════════" >&2
            echo "" >&2
            echo "  Context is at ~$((STATUS_TOKENS * 100 / 200000))% of 200K window." >&2
            echo "  Compaction is imminent. New work WILL be lost." >&2
            echo "" >&2
            echo "  ALLOWED: git commit, fw handover, reading files," >&2
            echo "           Write/Edit to .context/ .tasks/ .claude/" >&2
            echo "  BLOCKED: Write/Edit to source files, Bash (except commit/handover)" >&2
            echo "" >&2
            echo "  Action: Commit your work, then run 'fw handover'" >&2
            echo "══════════════════════════════════════════════════════════" >&2
            echo "" >&2
            exit 2
            ;;
    esac
fi

# --- Slow path: re-read transcript every Nth call ---
mkdir -p "$(dirname "$GATE_COUNTER_FILE")"
GATE_COUNT=0
if [ -f "$GATE_COUNTER_FILE" ]; then
    GATE_COUNT=$(tr -d '[:space:]' < "$GATE_COUNTER_FILE" 2>/dev/null) || GATE_COUNT=0
fi
GATE_COUNT=$((GATE_COUNT + 1))
echo "$GATE_COUNT" > "$GATE_COUNTER_FILE"

# Only re-read transcript every Nth call (performance)
if [ $((GATE_COUNT % RECHECK_INTERVAL)) -ne 1 ] && [ "$GATE_COUNT" -ne 1 ]; then
    exit 0
fi

# Find transcript — scoped to THIS project's Claude Code directory
# Claude Code encodes project paths: /opt/foo → -opt-foo in ~/.claude/projects/
PROJECT_DIR_NAME=$(echo "$PROJECT_ROOT" | sed 's|/|-|g')
PROJECT_JSONL_DIR="$HOME/.claude/projects/${PROJECT_DIR_NAME}"
TRANSCRIPT=""
if [ -d "$PROJECT_JSONL_DIR" ]; then
    TRANSCRIPT=$(find "$PROJECT_JSONL_DIR" -maxdepth 1 -name "*.jsonl" -type f ! -name "agent-*" 2>/dev/null | xargs ls -t 2>/dev/null | head -1)
fi

if [ -z "${TRANSCRIPT:-}" ]; then
    exit 0
fi

# Read tokens + write status + determine action — single Python call
SLOW_RESULT=$(tail -c 2000000 "$TRANSCRIPT" 2>/dev/null | python3 -c "
import sys, json, time

t = 0
for line in sys.stdin:
    try:
        e = json.loads(line)
        model = e.get('message', {}).get('model', '')
        if model == '<synthetic>' or model.startswith('<'):
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
        echo "Note: Context at ${TOKENS} tokens (~$((TOKENS * 100 / 200000))%). Commit before starting new work." >&2
        exit 0
        ;;
    urgent)
        echo "WARNING: Context at ${TOKENS} tokens (~$((TOKENS * 100 / 200000))%). Do not start new work. Commit and handover." >&2
        exit 0
        ;;
    critical)
        if [ "$CMD_CLASS" = "allowed" ]; then
            exit 0
        fi
        echo "" >&2
        echo "══════════════════════════════════════════════════════════" >&2
        echo "  BUDGET GATE — Context Critical (${TOKENS} tokens)" >&2
        echo "══════════════════════════════════════════════════════════" >&2
        echo "" >&2
        echo "  Context is at ~$((TOKENS * 100 / 200000))% of 200K window." >&2
        echo "  Context exhaustion imminent. New work WILL be lost." >&2
        echo "" >&2
        echo "  ALLOWED: git commit, fw handover, reading files," >&2
        echo "           Write/Edit to .context/ .tasks/ .claude/" >&2
        echo "  BLOCKED: Write/Edit to source files, Bash (except commit/handover)" >&2
        echo "" >&2
        echo "  Action: Commit your work, then run 'fw handover'" >&2
        echo "══════════════════════════════════════════════════════════" >&2
        echo "" >&2
        exit 2
        ;;
esac
