#!/usr/bin/env bash
# Tier A Tests: Tier 0 Enforcement (A5, A6)
# Tests check-tier0.sh blocks destructive commands.
#
# A5: Tier 0 blocks destructive commands (exit 2)
# A5b: Tier 0 allows safe commands (exit 0)
# A6: Tier 0 approve grants single-use bypass (exit 0)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../lib/setup.sh"
source "$SCRIPT_DIR/../lib/assert.sh"
source "$SCRIPT_DIR/../lib/teardown.sh"

SUITE_NAME="tier-a-tier0"

setup_test_dir
mkdir -p "$TEST_DIR/.context/working"

HOOK_SCRIPT="$FRAMEWORK_ROOT/agents/context/check-tier0.sh"

# Helper: simulate Bash tool input
make_bash_input() {
    local cmd="$1"
    printf '{"tool_name":"Bash","tool_input":{"command":"%s"}}' "$cmd"
}

# ── A5: Tier 0 blocks destructive commands ──

assert_exit_code \
    "echo '$(make_bash_input "rm -rf /")' | PROJECT_ROOT='$TEST_DIR' bash '$HOOK_SCRIPT'" \
    2 "A5a" "Tier 0 blocks rm -rf /"

assert_exit_code \
    "echo '$(make_bash_input "git push --force origin main")' | PROJECT_ROOT='$TEST_DIR' bash '$HOOK_SCRIPT'" \
    2 "A5b" "Tier 0 blocks git push --force"

assert_exit_code \
    "echo '$(make_bash_input "git reset --hard HEAD~5")' | PROJECT_ROOT='$TEST_DIR' bash '$HOOK_SCRIPT'" \
    2 "A5c" "Tier 0 blocks git reset --hard"

# ── A5b: Tier 0 allows safe commands ──

assert_exit_code \
    "echo '$(make_bash_input "ls -la")' | PROJECT_ROOT='$TEST_DIR' bash '$HOOK_SCRIPT'" \
    0 "A5d" "Tier 0 allows ls -la"

assert_exit_code \
    "echo '$(make_bash_input "git status")' | PROJECT_ROOT='$TEST_DIR' bash '$HOOK_SCRIPT'" \
    0 "A5e" "Tier 0 allows git status"

assert_exit_code \
    "echo '$(make_bash_input "fw doctor")' | PROJECT_ROOT='$TEST_DIR' bash '$HOOK_SCRIPT'" \
    0 "A5f" "Tier 0 allows fw doctor"

# ── A6: Tier 0 approve grants single-use bypass ──

# Write approval token with correct format: SHA256_HASH UNIX_TIMESTAMP
# The hash must match the exact command string
APPROVE_CMD="git push --force origin main"
APPROVE_HASH=$(echo -n "$APPROVE_CMD" | sha256sum | awk '{print $1}')
echo "$APPROVE_HASH $(date +%s)" > "$TEST_DIR/.context/working/.tier0-approval"

assert_exit_code \
    "echo '$(make_bash_input "git push --force origin main")' | PROJECT_ROOT='$TEST_DIR' bash '$HOOK_SCRIPT'" \
    0 "A6a" "Tier 0 approve allows destructive command once"

# Token should be consumed — second attempt should block
assert_exit_code \
    "echo '$(make_bash_input "git push --force origin main")' | PROJECT_ROOT='$TEST_DIR' bash '$HOOK_SCRIPT'" \
    2 "A6b" "Tier 0 token consumed — second attempt blocked"

# ── Report ──

if [ "${JSON_OUTPUT:-false}" = true ]; then
    print_json_summary
else
    print_summary
fi
