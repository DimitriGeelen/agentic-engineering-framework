#!/usr/bin/env bash
# Tier B Test: Full Agent Lifecycle (B1)
# Spawns Claude Code via TermLink, injects a prompt, and verifies
# the agent creates a task, makes a file, commits, and completes.
#
# Cost: ~$0.50-1.00 per run (real API calls)
# Time: ~60-120 seconds
#
# Prerequisites:
#   - ANTHROPIC_API_KEY set
#   - termlink installed
#   - claude CLI installed

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../lib/setup.sh"
source "$SCRIPT_DIR/../lib/assert.sh"
source "$SCRIPT_DIR/../lib/teardown.sh"

SUITE_NAME="tier-b-lifecycle"
SESSION_NAME="fw-e2e-b1-$$"
CLAUDE_TIMEOUT=120  # seconds to wait for Claude to finish

# ── Preflight ──

if [ -z "${ANTHROPIC_API_KEY:-}" ]; then
    skip "B1" "Full agent lifecycle" "ANTHROPIC_API_KEY not set"
    if [ "${JSON_OUTPUT:-false}" = true ]; then print_json_summary; else print_summary; fi
    exit 0
fi

if ! command -v claude >/dev/null 2>&1; then
    skip "B1" "Full agent lifecycle" "claude CLI not installed"
    if [ "${JSON_OUTPUT:-false}" = true ]; then print_json_summary; else print_summary; fi
    exit 0
fi

if ! command -v termlink >/dev/null 2>&1; then
    skip "B1" "Full agent lifecycle" "termlink not installed"
    if [ "${JSON_OUTPUT:-false}" = true ]; then print_json_summary; else print_summary; fi
    exit 0
fi

# ── Setup: isolated framework install ──

setup_isolated_env

# Initialize framework in test dir
(cd "$TEST_DIR" && fw context init >/dev/null 2>&1) || true

# ── Spawn Claude Code session ──

termlink spawn \
    --name "$SESSION_NAME" \
    --backend background \
    --shell \
    --tags "e2e,tier-b,lifecycle" \
    --wait \
    --wait-timeout 15 \
    >/dev/null 2>&1 || {
        skip "B1" "Full agent lifecycle" "Failed to spawn TermLink session"
        if [ "${JSON_OUTPUT:-false}" = true ]; then print_json_summary; else print_summary; fi
        exit 0
    }

TEST_SESSION="$SESSION_NAME"

# Set working directory
termlink interact "$SESSION_NAME" "cd $TEST_DIR" --timeout 5 >/dev/null 2>&1

# ── Inject Claude Code with a bounded prompt ──

PROMPT="Create a task called 'E2E test file', create a file called hello.txt with content 'hello from e2e', commit it, and complete the task. Use fw commands. Be concise."

# Start Claude in print mode (non-interactive, single prompt)
termlink pty inject "$SESSION_NAME" \
    "claude -p '$PROMPT' --output-format text 2>&1 | tee /tmp/fw-e2e-b1-output.txt; echo 'E2E_CLAUDE_DONE'" \
    --enter >/dev/null 2>&1

# ── Wait for completion ──

WAITED=0
while [ $WAITED -lt $CLAUDE_TIMEOUT ]; do
    OUTPUT=$(termlink pty output "$SESSION_NAME" --lines 5 --strip-ansi 2>/dev/null) || OUTPUT=""
    if echo "$OUTPUT" | grep -q "E2E_CLAUDE_DONE"; then
        break
    fi
    sleep 5
    WAITED=$((WAITED + 5))
done

# ── Assert outcomes ──

# B1a: A task file was created
TASK_COUNT=$(termlink interact "$SESSION_NAME" \
    "ls $TEST_DIR/.tasks/active/ $TEST_DIR/.tasks/completed/ 2>/dev/null | grep -c '.md'" \
    --json --strip-ansi --timeout 10 2>/dev/null | \
    python3 -c "import sys,json; print(json.load(sys.stdin).get('output','0').strip())" 2>/dev/null) || TASK_COUNT="0"

if [ "${TASK_COUNT:-0}" -gt 0 ]; then
    PASS_COUNT=$((PASS_COUNT + 1))
    _record_result "B1a" "Agent created a task" "PASS"
    printf "${_G}PASS${_N} [B1a] Agent created a task (%s task files)\n" "$TASK_COUNT"
else
    FAIL_COUNT=$((FAIL_COUNT + 1))
    _record_result "B1a" "Agent created a task" "FAIL" "no task files found"
    printf "${_R}FAIL${_N} [B1a] Agent created a task (no task files found)\n"
fi

# B1b: hello.txt was created with expected content
assert_tl_exit "$SESSION_NAME" "grep -q 'hello from e2e' '$TEST_DIR/hello.txt'" 0 "B1b" "Agent created hello.txt with correct content"

# B1c: A commit was made with task reference
COMMIT_LOG=$(termlink interact "$SESSION_NAME" \
    "cd $TEST_DIR && git log --oneline -5 2>/dev/null" \
    --json --strip-ansi --timeout 10 2>/dev/null | \
    python3 -c "import sys,json; print(json.load(sys.stdin).get('output',''))" 2>/dev/null) || COMMIT_LOG=""

if echo "$COMMIT_LOG" | grep -qE "T-[0-9]+"; then
    PASS_COUNT=$((PASS_COUNT + 1))
    _record_result "B1c" "Commit contains task reference" "PASS"
    printf "${_G}PASS${_N} [B1c] Commit contains task reference\n"
else
    FAIL_COUNT=$((FAIL_COUNT + 1))
    _record_result "B1c" "Commit contains task reference" "FAIL" "no T-XXX in git log"
    printf "${_R}FAIL${_N} [B1c] Commit contains task reference\n"
fi

# ── Report ──

if [ "${JSON_OUTPUT:-false}" = true ]; then
    print_json_summary
else
    print_summary
fi
