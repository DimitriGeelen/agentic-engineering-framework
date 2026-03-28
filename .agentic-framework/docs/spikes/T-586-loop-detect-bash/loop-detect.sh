#!/usr/bin/env bash
# PostToolUse loop detector — bash+Python prototype for T-586/T-578
#
# Detects repetitive tool call patterns:
#   1. generic_repeat: same tool+params called N times
#   2. ping_pong: alternating between two tool calls
#   3. no_progress: same tool+params+result repeated
#
# State: JSON file at .context/working/.loop-detect.json
# Input: tool_name and params from Claude Code PostToolUse hook (stdin JSON)
# Output: JSON with loop info to stderr (additionalContext)
#
# This is the bash+Python hybrid version — same logic as the TS prototype,
# implemented in the current framework architecture style.
set -euo pipefail

# --- Configuration ---
HISTORY_SIZE=30
WARNING_THRESHOLD=5
CRITICAL_THRESHOLD=10

# --- Paths ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${PROJECT_ROOT:-${FRAMEWORK_ROOT:-$(pwd)}}"
STATE_FILE="$PROJECT_ROOT/.context/working/.loop-detect.json"

# --- Read stdin (hook input) ---
INPUT=$(cat)
if [ -z "$INPUT" ]; then
    exit 0
fi

# --- All logic in Python (because bash can't do JSON/hashing) ---
RESULT=$(python3 -c "
import json, hashlib, sys, os, time

# Configuration
HISTORY_SIZE = $HISTORY_SIZE
WARNING_THRESHOLD = $WARNING_THRESHOLD
CRITICAL_THRESHOLD = $CRITICAL_THRESHOLD
STATE_FILE = '$STATE_FILE'

def stable_stringify(value):
    if value is None:
        return 'null'
    if isinstance(value, bool):
        return 'true' if value else 'false'
    if isinstance(value, (int, float)):
        return json.dumps(value)
    if isinstance(value, str):
        return json.dumps(value)
    if isinstance(value, list):
        return '[' + ','.join(stable_stringify(v) for v in value) + ']'
    if isinstance(value, dict):
        keys = sorted(value.keys())
        return '{' + ','.join(json.dumps(k) + ':' + stable_stringify(value[k]) for k in keys) + '}'
    return json.dumps(str(value))

def digest(value):
    serialized = stable_stringify(value)
    return hashlib.sha256(serialized.encode()).hexdigest()[:16]

def hash_tool_call(tool_name, params):
    return f'{tool_name}:{digest(params)}'

def load_state():
    try:
        with open(STATE_FILE) as f:
            return json.load(f)
    except:
        return {'history': []}

def save_state(state):
    os.makedirs(os.path.dirname(STATE_FILE), exist_ok=True)
    with open(STATE_FILE, 'w') as f:
        json.dump(state, f)

def detect_generic_repeat(history, current_hash, tool_name):
    count = sum(1 for h in history if h['argsHash'] == current_hash)
    if count >= CRITICAL_THRESHOLD:
        return {
            'stuck': True, 'level': 'critical', 'detector': 'generic_repeat',
            'count': count,
            'message': f'BLOCKED: {tool_name} called {count} times with identical arguments. Stuck loop.'
        }
    if count >= WARNING_THRESHOLD:
        return {
            'stuck': True, 'level': 'warning', 'detector': 'generic_repeat',
            'count': count,
            'message': f'WARNING: {tool_name} called {count} times with identical arguments.'
        }
    return {'stuck': False}

def detect_ping_pong(history, current_hash):
    if len(history) < 4:
        return {'stuck': False}
    last = history[-1]
    if last['argsHash'] == current_hash:
        return {'stuck': False}
    pattern_a = current_hash
    pattern_b = last['argsHash']
    streak = 0
    for i in range(len(history) - 1, -1, -1):
        expected = pattern_b if (len(history) - 1 - i) % 2 == 0 else pattern_a
        if history[i]['argsHash'] != expected:
            break
        streak += 1
    streak += 1  # current call
    if streak >= CRITICAL_THRESHOLD:
        return {
            'stuck': True, 'level': 'critical', 'detector': 'ping_pong',
            'count': streak,
            'message': f'BLOCKED: Alternating between two tool patterns {streak} times — stuck ping-pong loop.'
        }
    if streak >= WARNING_THRESHOLD:
        return {
            'stuck': True, 'level': 'warning', 'detector': 'ping_pong',
            'count': streak,
            'message': f'WARNING: Alternating between two tool patterns {streak} times.'
        }
    return {'stuck': False}

def detect_no_progress(history, current_hash, tool_name):
    matching = [h for h in history if h['argsHash'] == current_hash and h.get('resultHash')]
    if len(matching) < 3:
        return {'stuck': False}
    last_result = matching[-1]['resultHash']
    same_streak = 0
    for i in range(len(matching) - 1, -1, -1):
        if matching[i]['resultHash'] != last_result:
            break
        same_streak += 1
    if same_streak >= CRITICAL_THRESHOLD:
        return {
            'stuck': True, 'level': 'critical', 'detector': 'no_progress',
            'count': same_streak,
            'message': f'BLOCKED: {tool_name} returning identical results {same_streak} times — no progress.'
        }
    if same_streak >= WARNING_THRESHOLD:
        return {
            'stuck': True, 'level': 'warning', 'detector': 'no_progress',
            'count': same_streak,
            'message': f'WARNING: {tool_name} returning identical results {same_streak} times.'
        }
    return {'stuck': False}

# --- Main ---
try:
    hook_input = json.loads('''$INPUT''')
except:
    # Try reading from replaced variable — may have quotes issues
    try:
        hook_input = json.loads(sys.stdin.read()) if not '''$INPUT''' else {}
    except:
        sys.exit(0)

tool_name = hook_input.get('tool_name', 'unknown')
params = hook_input.get('tool_input', {})
tool_result = hook_input.get('tool_result')
current_hash = hash_tool_call(tool_name, params)

state = load_state()
history = state.get('history', [])

# Run detectors
for detect_fn in [detect_no_progress, detect_ping_pong, detect_generic_repeat]:
    if detect_fn == detect_ping_pong:
        result = detect_fn(history, current_hash)
    else:
        result = detect_fn(history, current_hash, tool_name)
    if result.get('stuck'):
        output = json.dumps({
            'additionalContext': result['message'],
            'loop_detected': True,
            'detector': result['detector'],
            'level': result['level'],
            'count': result['count'],
        })
        print(f'LOOP:{result[\"level\"]}:{output}', file=sys.stderr)
        # Record call before exiting
        result_hash = digest(tool_result) if tool_result else None
        history.append({
            'toolName': tool_name,
            'argsHash': current_hash,
            'resultHash': result_hash,
            'timestamp': int(time.time() * 1000),
        })
        if len(history) > HISTORY_SIZE:
            history = history[-HISTORY_SIZE:]
        state['history'] = history
        save_state(state)
        if result['level'] == 'critical':
            sys.exit(2)
        sys.exit(0)

# No loop — record and continue
result_hash = digest(tool_result) if tool_result else None
history.append({
    'toolName': tool_name,
    'argsHash': current_hash,
    'resultHash': result_hash,
    'timestamp': int(time.time() * 1000),
})
if len(history) > HISTORY_SIZE:
    history = history[-HISTORY_SIZE:]
state['history'] = history
save_state(state)
sys.exit(0)
" 2>&1)

EXIT_CODE=$?

# Forward Python's stderr output
if [ -n "$RESULT" ]; then
    echo "$RESULT" >&2
fi

exit $EXIT_CODE
