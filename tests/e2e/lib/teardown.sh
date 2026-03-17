#!/usr/bin/env bash
# E2E test teardown — clean up TermLink session and temp directory.
# Source this file at the end of each test script.
#
# Usage:
#   source "$(dirname "$0")/../lib/teardown.sh"
#   teardown   # cleans up session + temp dir

teardown() {
    # Stop TermLink session if active
    if [ -n "${TEST_SESSION:-}" ]; then
        termlink pty inject "$TEST_SESSION" "exit" --enter >/dev/null 2>&1 || true
        sleep 1
        termlink clean >/dev/null 2>&1 || true
        TEST_SESSION=""
    fi

    # Remove temp directory
    if [ -n "${TEST_DIR:-}" ] && [ -d "${TEST_DIR}" ]; then
        rm -rf "$TEST_DIR"
        TEST_DIR=""
    fi
}

# Auto-teardown on exit (trap)
_teardown_on_exit() {
    teardown
}
trap _teardown_on_exit EXIT
