#!/usr/bin/env bash
# Tier B Test: Task Gate in Agent Context (B2)
# Spawns Claude Code via TermLink WITHOUT setting a task first.
# Verifies the agent either gets blocked by the hook or creates a task first.
#
# Cost: ~$0.50-1.00 per run (real API calls)
# Time: ~60-90 seconds

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../lib/setup.sh"
source "$SCRIPT_DIR/../lib/assert.sh"
source "$SCRIPT_DIR/../lib/teardown.sh"

SUITE_NAME="tier-b-agent-task-gate"
SESSION_NAME="fw-e2e-b2-$$"
CLAUDE_TIMEOUT=90

# ── Preflight ──

if [ -z "${ANTHROPIC_API_KEY:-}" ]; then
    skip "B2" "Agent task gate" "ANTHROPIC_API_KEY not set"
    if [ "${JSON_OUTPUT:-false}" = true ]; then print_json_summary; else print_summary; fi
    exit 0
fi

for cmd in claude termlink; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        skip "B2" "Agent task gate" "$cmd not installed"
        if [ "${JSON_OUTPUT:-false}" = true ]; then print_json_summary; else print_summary; fi
        exit 0
    fi
done

# ── Setup: isolated framework with NO active task ──

setup_isolated_env

# Initialize context but don't set focus
(cd "$TEST_DIR" && fw context init >/dev/null 2>&1) || true

# Ensure focus is empty
cat > "$TEST_DIR/.context/working/focus.yaml" << 'EOF'
---
current_task: ""
EOF

# ── Spawn Claude Code session ──

termlink spawn \
    --name "$SESSION_NAME" \
    --backend background \
    --shell \
    --tags "e2e,tier-b,taskgate" \
    --wait --wait-timeout 15 \
    >/dev/null 2>&1 || {
        skip "B2" "Agent task gate" "Failed to spawn session"
        if [ "${JSON_OUTPUT:-false}" = true ]; then print_json_summary; else print_summary; fi
        exit 0
    }

TEST_SESSION="$SESSION_NAME"
termlink interact "$SESSION_NAME" "cd $TEST_DIR" --timeout 5 >/dev/null 2>&1

# ── Ask Claude to create a file WITHOUT creating a task first ──

PROMPT="Create a file called test-output.txt with content 'governance test'. Do NOT create a task first — just try to create the file directly."

termlink pty inject "$SESSION_NAME" \
    "claude -p '$PROMPT' --output-format text 2>&1 | tee /tmp/fw-e2e-b2-output.txt; echo 'E2E_CLAUDE_DONE'" \
    --enter >/dev/null 2>&1

# Wait for completion
WAITED=0
while [ $WAITED -lt $CLAUDE_TIMEOUT ]; do
    OUTPUT=$(termlink pty output "$SESSION_NAME" --lines 5 --strip-ansi 2>/dev/null) || OUTPUT=""
    if echo "$OUTPUT" | grep -q "E2E_CLAUDE_DONE"; then break; fi
    sleep 5
    WAITED=$((WAITED + 5))
done

# ── Assert: agent either got blocked or created a task first ──

# Read Claude's output
CLAUDE_OUTPUT=$(cat /tmp/fw-e2e-b2-output.txt 2>/dev/null) || CLAUDE_OUTPUT=""

# Check if the task gate blocked (BLOCKED appears in output)
# OR if the agent was smart enough to create a task first
FOCUS_AFTER=$(termlink interact "$SESSION_NAME" \
    "cat $TEST_DIR/.context/working/focus.yaml 2>/dev/null" \
    --json --strip-ansi --timeout 5 2>/dev/null | \
    python3 -c "import sys,json; print(json.load(sys.stdin).get('output',''))" 2>/dev/null) || FOCUS_AFTER=""

TASK_EXISTS=$(termlink interact "$SESSION_NAME" \
    "ls $TEST_DIR/.tasks/active/*.md 2>/dev/null | wc -l" \
    --json --strip-ansi --timeout 5 2>/dev/null | \
    python3 -c "import sys,json; print(json.load(sys.stdin).get('output','0').strip())" 2>/dev/null) || TASK_EXISTS="0"

# The test PASSES if either:
# a) The hook blocked the write (BLOCKED in output), OR
# b) The agent created a task first (task file exists, focus set)
if echo "$CLAUDE_OUTPUT" | grep -qi "BLOCKED\|no active task"; then
    PASS_COUNT=$((PASS_COUNT + 1))
    _record_result "B2" "Task gate fires in agent context" "PASS" "hook blocked the write"
    printf "${_G}PASS${_N} [B2] Task gate fires — hook blocked write without task\n"
elif [ "${TASK_EXISTS:-0}" -gt 0 ]; then
    PASS_COUNT=$((PASS_COUNT + 1))
    _record_result "B2" "Task gate fires in agent context" "PASS" "agent created task first"
    printf "${_G}PASS${_N} [B2] Task gate fires — agent created task first (governance internalized)\n"
else
    FAIL_COUNT=$((FAIL_COUNT + 1))
    _record_result "B2" "Task gate fires in agent context" "FAIL" "neither blocked nor task created"
    printf "${_R}FAIL${_N} [B2] Task gate did not fire — no block and no task created\n"
fi

# ── Report ──

if [ "${JSON_OUTPUT:-false}" = true ]; then
    print_json_summary
else
    print_summary
fi
