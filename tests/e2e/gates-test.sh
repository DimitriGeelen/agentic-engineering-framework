#!/usr/bin/env bash
# Gate Validation Test — verifies enforcement hooks block/allow correctly.
#
# Tests:
#   1. Task gate blocks Write without active task (exit 2)
#   2. Task gate allows Write with active task (exit 0)
#   3. Task gate allows exempt paths (.context/, .tasks/) without task (exit 0)
#   4. Tier 0 blocks destructive commands (exit 2)
#   5. Tier 0 allows safe commands (exit 0)
#
# T-491: Built from T-490 inception (experiment 6: gate programmatic test).

set -euo pipefail

FRAMEWORK_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
JSON_OUTPUT=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --json) JSON_OUTPUT=true; shift ;;
        *)      echo "Unknown arg: $1"; exit 1 ;;
    esac
done

if [ "$JSON_OUTPUT" = true ]; then
    GREEN="" RED="" BOLD="" NC=""
else
    GREEN='\033[0;32m' RED='\033[0;31m' BOLD='\033[1m' NC='\033[0m'
fi

declare -a PHASE_NAMES=()
declare -a PHASE_RESULTS=()
declare -a PHASE_DETAILS=()
TOTAL_PASSED=0
TOTAL_FAILED=0
START_TIME=$(date +%s)

phase_pass() {
    local name="$1" detail="${2:-}"
    PHASE_NAMES+=("$name")
    PHASE_RESULTS+=("pass")
    PHASE_DETAILS+=("$detail")
    TOTAL_PASSED=$((TOTAL_PASSED + 1))
    if [ "$JSON_OUTPUT" = false ]; then
        echo -e "  ${GREEN}PASS${NC}  $name${detail:+ — $detail}"
    fi
}

phase_fail() {
    local name="$1" detail="${2:-}"
    PHASE_NAMES+=("$name")
    PHASE_RESULTS+=("fail")
    PHASE_DETAILS+=("$detail")
    TOTAL_FAILED=$((TOTAL_FAILED + 1))
    if [ "$JSON_OUTPUT" = false ]; then
        echo -e "  ${RED}FAIL${NC}  $name${detail:+ — $detail}"
    fi
}

output_json() {
    local elapsed=$(($(date +%s) - START_TIME))
    local phases="["
    for i in "${!PHASE_NAMES[@]}"; do
        if [ "$i" -gt 0 ]; then phases+=","; fi
        phases+="{\"name\":\"${PHASE_NAMES[$i]}\",\"result\":\"${PHASE_RESULTS[$i]}\",\"detail\":\"${PHASE_DETAILS[$i]}\"}"
    done
    phases+="]"
    echo "{\"passed\":$TOTAL_PASSED,\"failed\":$TOTAL_FAILED,\"total\":$((TOTAL_PASSED+TOTAL_FAILED)),\"elapsed_seconds\":$elapsed,\"phases\":$phases}"
}

if [ "$JSON_OUTPUT" = false ]; then
    echo -e "${BOLD}fw self-test: gates${NC}\n"
fi

# Create a temp project for gate testing
TMPDIR=$(mktemp -d "${TMPDIR:-/tmp}/fw-gate-XXXXXXXX")
trap 'rm -rf "$TMPDIR"' EXIT

(cd "$TMPDIR" && git init -q && git config user.email "t@t" && git config user.name "t")
"$FRAMEWORK_ROOT/bin/fw" init "$TMPDIR" >/dev/null 2>&1 || true

GATE_SCRIPT="$FRAMEWORK_ROOT/agents/context/check-active-task.sh"
TIER0_SCRIPT="$FRAMEWORK_ROOT/agents/context/check-tier0.sh"

# =========================================================================
# Test 1: Task gate blocks Write without active task
# =========================================================================
# Clear focus so there's no active task
echo "current_task:" > "$TMPDIR/.context/working/focus.yaml"

EXIT_CODE=0
echo '{"tool_name":"Write","tool_input":{"file_path":"'$TMPDIR'/src/main.py"}}' | \
    PROJECT_ROOT="$TMPDIR" FRAMEWORK_ROOT="$FRAMEWORK_ROOT" \
    bash "$GATE_SCRIPT" >/dev/null 2>&1 || EXIT_CODE=$?

if [ "$EXIT_CODE" -eq 2 ]; then
    phase_pass "task-gate-block" "blocks Write without active task (exit 2)"
else
    phase_fail "task-gate-block" "expected exit 2, got $EXIT_CODE"
fi

# =========================================================================
# Test 2: Task gate allows Write with active task
# =========================================================================
# Create a task file and set focus
mkdir -p "$TMPDIR/.tasks/active"
cat > "$TMPDIR/.tasks/active/T-999-test-task.md" << 'TASKEOF'
---
id: T-999
name: "Test task"
status: started-work
workflow_type: build
owner: agent
horizon: now
created: 2026-01-01
last_update: 2026-01-01
---

# T-999: Test task

## Acceptance Criteria

- [ ] Test criterion

## Verification
TASKEOF

cat > "$TMPDIR/.context/working/focus.yaml" << 'FOCUSEOF'
current_task: T-999
task_file: .tasks/active/T-999-test-task.md
set_at: 2026-01-01T00:00:00Z
FOCUSEOF

EXIT_CODE=0
echo '{"tool_name":"Write","tool_input":{"file_path":"'$TMPDIR'/src/main.py"}}' | \
    PROJECT_ROOT="$TMPDIR" FRAMEWORK_ROOT="$FRAMEWORK_ROOT" \
    bash "$GATE_SCRIPT" >/dev/null 2>&1 || EXIT_CODE=$?

if [ "$EXIT_CODE" -eq 0 ]; then
    phase_pass "task-gate-allow" "allows Write with active task (exit 0)"
else
    phase_fail "task-gate-allow" "expected exit 0, got $EXIT_CODE"
fi

# =========================================================================
# Test 3: Task gate allows exempt paths without task
# =========================================================================
echo "current_task:" > "$TMPDIR/.context/working/focus.yaml"

EXIT_CODE=0
echo '{"tool_name":"Write","tool_input":{"file_path":"'$TMPDIR'/.context/working/test.yaml"}}' | \
    PROJECT_ROOT="$TMPDIR" FRAMEWORK_ROOT="$FRAMEWORK_ROOT" \
    bash "$GATE_SCRIPT" >/dev/null 2>&1 || EXIT_CODE=$?

if [ "$EXIT_CODE" -eq 0 ]; then
    phase_pass "task-gate-exempt" "allows .context/ path without task (exit 0)"
else
    phase_fail "task-gate-exempt" "expected exit 0, got $EXIT_CODE"
fi

# =========================================================================
# Test 4: Tier 0 blocks destructive commands
# =========================================================================
# Clear any approval token
rm -f "$TMPDIR/.context/working/.tier0-approval" "$TMPDIR/.context/working/.tier0-approval.pending"

EXIT_CODE=0
echo '{"tool_name":"Bash","tool_input":{"command":"rm -rf /"}}' | \
    PROJECT_ROOT="$TMPDIR" FRAMEWORK_ROOT="$FRAMEWORK_ROOT" \
    bash "$TIER0_SCRIPT" >/dev/null 2>&1 || EXIT_CODE=$?

if [ "$EXIT_CODE" -eq 2 ]; then
    phase_pass "tier0-block" "blocks 'rm -rf /' (exit 2)"
else
    phase_fail "tier0-block" "expected exit 2, got $EXIT_CODE"
fi

# =========================================================================
# Test 5: Tier 0 allows safe commands
# =========================================================================
EXIT_CODE=0
echo '{"tool_name":"Bash","tool_input":{"command":"git status"}}' | \
    PROJECT_ROOT="$TMPDIR" FRAMEWORK_ROOT="$FRAMEWORK_ROOT" \
    bash "$TIER0_SCRIPT" >/dev/null 2>&1 || EXIT_CODE=$?

if [ "$EXIT_CODE" -eq 0 ]; then
    phase_pass "tier0-allow" "allows 'git status' (exit 0)"
else
    phase_fail "tier0-allow" "expected exit 0, got $EXIT_CODE"
fi

# =========================================================================
# Summary
# =========================================================================
if [ "$JSON_OUTPUT" = true ]; then
    output_json
else
    echo ""
    if [ "$TOTAL_FAILED" -eq 0 ]; then
        echo -e "${GREEN}All $TOTAL_PASSED gate tests passed${NC}"
    else
        echo -e "${RED}$TOTAL_FAILED/$((TOTAL_PASSED+TOTAL_FAILED)) gate tests failed${NC}"
    fi
fi

[ "$TOTAL_FAILED" -eq 0 ]
