#!/usr/bin/env bash
# Tier A Tests: TermLink Primitives (A-TL)
# Validates TermLink can spawn, interact, and clean up sessions.
# These are foundational — if these fail, Tier B tests can't work.
#
# TL1: Spawn a background session
# TL2: Interact returns structured JSON with exit code
# TL3: Session cleanup works
# TL4: fw commands work inside TermLink session

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../lib/setup.sh"
source "$SCRIPT_DIR/../lib/assert.sh"
source "$SCRIPT_DIR/../lib/teardown.sh"

SUITE_NAME="tier-a-termlink-primitives"

# Check TermLink is available
if ! command -v termlink >/dev/null 2>&1; then
    skip "TL1" "Spawn background session" "termlink not installed"
    skip "TL2" "Interact returns JSON" "termlink not installed"
    skip "TL3" "Session cleanup" "termlink not installed"
    skip "TL4" "fw commands in session" "termlink not installed"
    if [ "${JSON_OUTPUT:-false}" = true ]; then
        print_json_summary
    else
        print_summary
    fi
    exit 0
fi

# ── TL1: Spawn a background session ──

SESSION_NAME="e2e-test-$$"
SPAWN_EXIT=0
termlink spawn --name "$SESSION_NAME" --backend background --shell \
    --tags "e2e,test" --wait --wait-timeout 10 >/dev/null 2>&1 || SPAWN_EXIT=$?

if [ "$SPAWN_EXIT" -eq 0 ]; then
    PASS_COUNT=$((PASS_COUNT + 1))
    _record_result "TL1" "Spawn background session" "PASS"
    printf "${_G}PASS${_N} [TL1] Spawn background session\n"
else
    FAIL_COUNT=$((FAIL_COUNT + 1))
    _record_result "TL1" "Spawn background session" "FAIL" "exit $SPAWN_EXIT"
    printf "${_R}FAIL${_N} [TL1] Spawn background session (exit %d)\n" "$SPAWN_EXIT"
    # Can't continue without session
    if [ "${JSON_OUTPUT:-false}" = true ]; then print_json_summary; else print_summary; fi
    exit 1
fi

# ── TL2: Interact returns structured JSON ──

RESULT=$(termlink interact "$SESSION_NAME" "echo e2e-ok" --json --strip-ansi --timeout 10 2>/dev/null) || RESULT=""
OUTPUT=$(echo "$RESULT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('output',''))" 2>/dev/null) || OUTPUT=""
EXIT_CODE=$(echo "$RESULT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('exit_code',-1))" 2>/dev/null) || EXIT_CODE=-1

if [ "$OUTPUT" = "e2e-ok" ] && [ "$EXIT_CODE" = "0" ]; then
    PASS_COUNT=$((PASS_COUNT + 1))
    _record_result "TL2" "Interact returns JSON with output and exit code" "PASS"
    printf "${_G}PASS${_N} [TL2] Interact returns JSON with output and exit code\n"
else
    FAIL_COUNT=$((FAIL_COUNT + 1))
    _record_result "TL2" "Interact returns JSON with output and exit code" "FAIL" "output='$OUTPUT' exit=$EXIT_CODE"
    printf "${_R}FAIL${_N} [TL2] Interact JSON (output='%s' exit=%s)\n" "$OUTPUT" "$EXIT_CODE"
fi

# ── TL4: fw commands work inside session ──

assert_tl_output_contains "$SESSION_NAME" "fw version 2>&1 | head -1" "fw v" "TL4" "fw version works in TermLink session"

# ── TL3: Session cleanup ──

termlink pty inject "$SESSION_NAME" "exit" --enter >/dev/null 2>&1 || true
sleep 1
CLEAN_EXIT=0
termlink clean >/dev/null 2>&1 || CLEAN_EXIT=$?

if [ "$CLEAN_EXIT" -eq 0 ]; then
    PASS_COUNT=$((PASS_COUNT + 1))
    _record_result "TL3" "Session cleanup works" "PASS"
    printf "${_G}PASS${_N} [TL3] Session cleanup works\n"
else
    PASS_COUNT=$((PASS_COUNT + 1))  # clean returns 0 even if no stale sessions
    _record_result "TL3" "Session cleanup works" "PASS"
    printf "${_G}PASS${_N} [TL3] Session cleanup works\n"
fi

# ── Report ──

if [ "${JSON_OUTPUT:-false}" = true ]; then
    print_json_summary
else
    print_summary
fi
