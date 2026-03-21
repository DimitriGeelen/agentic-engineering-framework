#!/usr/bin/env bash
# Tier A Tests: Budget Gate Enforcement (A7, A8)
# Tests budget-gate.sh warns/blocks based on token usage.
#
# A7: Budget gate warns at threshold (exit 0, status=warn)
# A8: Budget gate blocks at critical (exit 2, status=critical)
# A7b: Budget gate allows at low usage (exit 0, status=ok)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../lib/setup.sh"
source "$SCRIPT_DIR/../lib/assert.sh"
source "$SCRIPT_DIR/../lib/teardown.sh"

SUITE_NAME="tier-a-budget-gate"

setup_test_dir
mkdir -p "$TEST_DIR/.context/working"

HOOK_SCRIPT="$FRAMEWORK_ROOT/agents/context/budget-gate.sh"

# Helper: create a mock budget-status file (uses Unix epoch + correct field names)
write_budget_status() {
    local level="$1" tokens="$2"
    local ts
    ts=$(date +%s)
    cat > "$TEST_DIR/.context/working/.budget-status" << EOF
{"level": "$level", "tokens": $tokens, "timestamp": $ts, "source": "mock"}
EOF
}

# Helper: reset gate counter so it reads the status file (not transcript)
reset_counter() {
    echo "0" > "$TEST_DIR/.context/working/.budget-gate-counter"
}

# Helper: make Write tool input
make_write_input() {
    printf '{"tool_name":"Write","tool_input":{"file_path":"%s/src/main.py"}}' "$TEST_DIR"
}

# ── A7b: Budget gate allows at low usage ──

write_budget_status "ok" 200000
reset_counter

assert_exit_code \
    "echo '$(make_write_input)' | PROJECT_ROOT='$TEST_DIR' CONTEXT_WINDOW=1000000 bash '$HOOK_SCRIPT'" \
    0 "A7b" "Budget gate allows at low usage (200K tokens)"

# ── A7: Budget gate at warn level — still allows but warns ──

write_budget_status "warn" 650000
reset_counter

assert_exit_code \
    "echo '$(make_write_input)' | PROJECT_ROOT='$TEST_DIR' CONTEXT_WINDOW=1000000 bash '$HOOK_SCRIPT'" \
    0 "A7" "Budget gate allows at warn level (650K tokens)"

# ── A8: Budget gate blocks at critical ──

write_budget_status "critical" 950000
reset_counter

assert_exit_code \
    "echo '$(make_write_input)' | PROJECT_ROOT='$TEST_DIR' CONTEXT_WINDOW=1000000 bash '$HOOK_SCRIPT'" \
    2 "A8" "Budget gate blocks at critical (950K tokens)"

# ── A8b: Budget gate allows wrap-up paths at critical ──

write_budget_status "critical" 950000
reset_counter

make_context_input() {
    printf '{"tool_name":"Write","tool_input":{"file_path":"%s/.context/working/focus.yaml"}}' "$TEST_DIR"
}

assert_exit_code \
    "echo '$(make_context_input)' | PROJECT_ROOT='$TEST_DIR' CONTEXT_WINDOW=1000000 bash '$HOOK_SCRIPT'" \
    0 "A8b" "Budget gate allows .context/ writes at critical"

# ── Report ──

if [ "${JSON_OUTPUT:-false}" = true ]; then
    print_json_summary
else
    print_summary
fi
