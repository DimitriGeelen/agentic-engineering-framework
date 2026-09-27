#!/bin/bash
# Stub test for agents/context/subagent-stop.sh (T-1213)
#
# Exercises both paths:
#   1. Under-threshold return (500B) → telemetry line written, no fw bus entry, migrated=false
#   2. Over-threshold return (20KB)  → telemetry line written, fw bus R-NNN entry, migrated=true
#
# Runs in an isolated temp dir (does NOT pollute real .context/working) and uses a
# synthesized transcript JSONL file.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HANDLER="$SCRIPT_DIR/../subagent-stop.sh"
PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$SCRIPT_DIR/../../../.." && pwd)}"

test -x "$HANDLER" || { echo "FAIL: handler not executable: $HANDLER"; exit 1; }

# Isolated sandbox — override PROJECT_ROOT so the handler writes into a tmp tree
SANDBOX=$(mktemp -d)
trap 'rm -rf "$SANDBOX"' EXIT

mkdir -p "$SANDBOX/.context/working"
# Minimal focus so the "over-threshold → post to fw bus" path picks up a task.
# The bus post itself will be mocked below — we just need the handler to get past
# the "no focus, log, skip" branch and attempt the call.
cat > "$SANDBOX/.context/working/focus.yaml" <<EOF
current_task: T-STUB
EOF

# Mock fw binary that records bus post args
mkdir -p "$SANDBOX/.agentic-framework/bin"
cat > "$SANDBOX/.agentic-framework/bin/fw" <<'MOCK'
#!/bin/bash
if [ "${1:-}" = "bus" ] && [ "${2:-}" = "post" ]; then
    echo "R-001"
    echo "$@" >> "$MOCK_LOG"
    exit 0
fi
exit 0
MOCK
chmod +x "$SANDBOX/.agentic-framework/bin/fw"
export MOCK_LOG="$SANDBOX/mock-bus-log"

# --- Test 1: under-threshold (500B) ---
TRANSCRIPT1="$SANDBOX/transcript-small.jsonl"
SMALL_MSG=$(python3 -c "print('x' * 500)")
python3 -c "
import json, sys
entry = {'type': 'assistant', 'message': {'content': [{'type': 'text', 'text': '$SMALL_MSG'}]}}
open('$TRANSCRIPT1', 'w').write(json.dumps(entry) + '\n')
"

PAYLOAD1=$(python3 -c "
import json
print(json.dumps({
    'transcript_path': '$TRANSCRIPT1',
    'agent_type': 'Explore',
    'agent_id': 'test-small',
    'session_id': 'stub-session',
}))")

PROJECT_ROOT="$SANDBOX" echo "$PAYLOAD1" | PROJECT_ROOT="$SANDBOX" "$HANDLER"

TELEMETRY="$SANDBOX/.context/working/subagent-returns.jsonl"
test -f "$TELEMETRY" || { echo "FAIL: telemetry file not written"; exit 1; }
LINE1=$(tail -1 "$TELEMETRY")
echo "$LINE1" | python3 -c "
import sys, json
d = json.loads(sys.stdin.read())
assert d['bytes'] == 500, f'expected 500 bytes, got {d[\"bytes\"]}'
assert d['migrated'] is False, f'expected migrated=False, got {d[\"migrated\"]}'
assert d['agent_type'] == 'Explore'
print('  Test 1 PASS:', d)
"

# --- Test 2: over-threshold (20KB) ---
TRANSCRIPT2="$SANDBOX/transcript-large.jsonl"
python3 -c "
import json
big = 'x' * 20000
entry = {'type': 'assistant', 'message': {'content': [{'type': 'text', 'text': big}]}}
open('$TRANSCRIPT2', 'w').write(json.dumps(entry) + '\n')
"

PAYLOAD2=$(python3 -c "
import json
print(json.dumps({
    'transcript_path': '$TRANSCRIPT2',
    'agent_type': 'general-purpose',
    'agent_id': 'test-large',
    'session_id': 'stub-session',
}))")

echo "$PAYLOAD2" | PROJECT_ROOT="$SANDBOX" "$HANDLER" 2> "$SANDBOX/stderr2.log"

LINE2=$(tail -1 "$TELEMETRY")
echo "$LINE2" | python3 -c "
import sys, json
d = json.loads(sys.stdin.read())
assert d['bytes'] == 20000, f'expected 20000 bytes, got {d[\"bytes\"]}'
assert d['migrated'] is True, f'expected migrated=True, got {d[\"migrated\"]}'
assert d['bus_ref'] == 'R-001', f'expected bus_ref=R-001, got {d[\"bus_ref\"]}'
print('  Test 2 PASS:', d)
"
grep -q "archived to fw bus" "$SANDBOX/stderr2.log" || {
    echo "FAIL: stderr nudge not emitted for over-threshold return"
    cat "$SANDBOX/stderr2.log"
    exit 1
}
test -f "$MOCK_LOG" || { echo "FAIL: mock fw not invoked"; exit 1; }
grep -q "T-STUB" "$MOCK_LOG" || { echo "FAIL: bus post missing task id"; cat "$MOCK_LOG"; exit 1; }

echo "All stub tests PASS"
