#!/usr/bin/env bash
# E2E test setup — create isolated test environment with TermLink session.
# Source this file at the start of each test script.
#
# Provides:
#   TEST_DIR      — temporary directory for isolated test
#   TEST_SESSION  — TermLink session name (if spawned)
#   FRAMEWORK_ROOT — path to the real framework (for reference)
#
# Usage in test scripts:
#   source "$(dirname "$0")/../lib/setup.sh"
#   setup_isolated_env          # creates temp dir with fw init
#   setup_termlink_session      # spawns TermLink session in TEST_DIR
#   # ... run tests ...
#   source "$(dirname "$0")/../lib/teardown.sh"

E2E_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK_ROOT="$(cd "$E2E_LIB_DIR/../../.." && pwd)"
export FRAMEWORK_ROOT

TEST_DIR=""
TEST_SESSION=""
_SETUP_DONE=false

# setup_test_dir — create a temp directory for test isolation
setup_test_dir() {
    TEST_DIR=$(mktemp -d "${TMPDIR:-/tmp}/fw-e2e-XXXXXX")
    export TEST_DIR
    _SETUP_DONE=true
}

# setup_isolated_env — create temp dir and initialize a minimal framework install
setup_isolated_env() {
    setup_test_dir

    # Copy minimal framework structure for testing
    cp -r "$FRAMEWORK_ROOT/bin" "$TEST_DIR/"
    cp -r "$FRAMEWORK_ROOT/lib" "$TEST_DIR/"
    cp -r "$FRAMEWORK_ROOT/agents" "$TEST_DIR/"
    cp "$FRAMEWORK_ROOT/CLAUDE.md" "$TEST_DIR/" 2>/dev/null || true
    cp "$FRAMEWORK_ROOT/FRAMEWORK.md" "$TEST_DIR/" 2>/dev/null || true
    mkdir -p "$TEST_DIR/.tasks/active" "$TEST_DIR/.tasks/completed" "$TEST_DIR/.tasks/templates"
    mkdir -p "$TEST_DIR/.context/working" "$TEST_DIR/.context/project" "$TEST_DIR/.context/episodic"
    mkdir -p "$TEST_DIR/.context/handovers" "$TEST_DIR/.context/audits/cron"

    # Initialize git repo (needed for hooks)
    (cd "$TEST_DIR" && git init -q && git add -A && git commit -q -m "init" 2>/dev/null) || true

    export TEST_DIR
}

# setup_termlink_session [NAME] — spawn a TermLink shell session in TEST_DIR
setup_termlink_session() {
    local name="${1:-fw-e2e-$$}"
    TEST_SESSION="$name"

    if ! command -v termlink >/dev/null 2>&1; then
        echo "WARN: termlink not found, skipping session spawn" >&2
        TEST_SESSION=""
        return 1
    fi

    termlink spawn \
        --name "$TEST_SESSION" \
        --backend background \
        --shell \
        --tags "e2e,test" \
        --wait \
        --wait-timeout 15 \
        >/dev/null 2>&1 || {
            echo "ERROR: Failed to spawn TermLink session '$TEST_SESSION'" >&2
            TEST_SESSION=""
            return 1
        }

    # Set working directory in session
    if [ -n "$TEST_DIR" ]; then
        termlink interact "$TEST_SESSION" "cd $TEST_DIR" --timeout 5 >/dev/null 2>&1 || true
    fi

    export TEST_SESSION
}

# tl_run CMD — run a command in the TermLink session, return JSON
tl_run() {
    local cmd="$1"
    local timeout="${2:-30}"
    if [ -z "$TEST_SESSION" ]; then
        echo '{"error":"no session","exit_code":-1,"output":""}'
        return 1
    fi
    termlink interact "$TEST_SESSION" "$cmd" --json --strip-ansi --timeout "$timeout" 2>/dev/null
}

# tl_run_exit CMD — run a command in session, return just exit code
tl_run_exit() {
    local result
    result=$(tl_run "$1" "${2:-30}")
    echo "$result" | python3 -c "import sys,json; print(json.load(sys.stdin).get('exit_code',-1))" 2>/dev/null
}

# tl_run_output CMD — run a command in session, return just output
tl_run_output() {
    local result
    result=$(tl_run "$1" "${2:-30}")
    echo "$result" | python3 -c "import sys,json; print(json.load(sys.stdin).get('output',''))" 2>/dev/null
}
