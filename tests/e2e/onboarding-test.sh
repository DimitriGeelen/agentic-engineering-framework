#!/usr/bin/env bash
# E2E Onboarding Test — validates the complete framework onboarding path.
#
# Phases:
#   1. Setup    — create temp project dir, git init
#   2. Init     — run fw init, validate artifacts created
#   3. Doctor   — run fw doctor, check exit code
#   4. Serve    — start Watchtower on test port, run smoke test
#   5. Cleanup  — remove temp dir, kill server
#
# Usage:
#   bash tests/e2e/onboarding-test.sh          # human-readable output
#   bash tests/e2e/onboarding-test.sh --json   # JSON summary
#   bash tests/e2e/onboarding-test.sh --port N # override test port (default: 9877)
#
# T-492: Built from T-489 inception (5 untested seams, 17 failure modes).

set -euo pipefail

# --- Configuration ---
FRAMEWORK_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TEST_PORT="${FW_TEST_PORT:-9877}"
JSON_OUTPUT=false
VERBOSE=false
TMPDIR_BASE=""
SERVE_PID=""

# Parse args
while [[ $# -gt 0 ]]; do
    case "$1" in
        --json)    JSON_OUTPUT=true; shift ;;
        --port)    TEST_PORT="$2"; shift 2 ;;
        --verbose) VERBOSE=true; shift ;;
        *)         echo "Unknown arg: $1"; exit 1 ;;
    esac
done

# --- Color codes (disabled for JSON mode) ---
if [ "$JSON_OUTPUT" = true ]; then
    GREEN="" RED="" YELLOW="" BOLD="" NC=""
else
    GREEN='\033[0;32m' RED='\033[0;31m' YELLOW='\033[1;33m'
    BOLD='\033[1m' NC='\033[0m'
fi

# --- Result tracking ---
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

# --- Cleanup trap ---
cleanup() {
    # Kill server if running
    if [ -n "$SERVE_PID" ] && kill -0 "$SERVE_PID" 2>/dev/null; then
        kill "$SERVE_PID" 2>/dev/null || true
        wait "$SERVE_PID" 2>/dev/null || true
    fi
    # Also kill anything on our test port
    if command -v fuser >/dev/null 2>&1; then
        fuser -k "${TEST_PORT}/tcp" 2>/dev/null || true
    fi
    # Remove temp dir
    if [ -n "$TMPDIR_BASE" ] && [ -d "$TMPDIR_BASE" ]; then
        rm -rf "$TMPDIR_BASE"
    fi
}
trap cleanup EXIT

# --- Output JSON summary ---
output_json() {
    local elapsed=$(($(date +%s) - START_TIME))
    local phases="["
    for i in "${!PHASE_NAMES[@]}"; do
        if [ "$i" -gt 0 ]; then phases+=","; fi
        phases+="{\"name\":\"${PHASE_NAMES[$i]}\",\"result\":\"${PHASE_RESULTS[$i]}\",\"detail\":\"${PHASE_DETAILS[$i]}\"}"
    done
    phases+="]"
    cat <<EOF
{"passed":$TOTAL_PASSED,"failed":$TOTAL_FAILED,"total":$((TOTAL_PASSED+TOTAL_FAILED)),"elapsed_seconds":$elapsed,"phases":$phases}
EOF
}

# --- Header ---
if [ "$JSON_OUTPUT" = false ]; then
    echo -e "${BOLD}fw self-test: onboarding${NC} (port $TEST_PORT)\n"
fi

# =========================================================================
# Phase 1: Setup — create temp project, git init
# =========================================================================
TMPDIR_BASE=$(mktemp -d "${TMPDIR:-/tmp}/fw-e2e-XXXXXXXX")

if cd "$TMPDIR_BASE" && git init -q 2>/dev/null; then
    # Configure git identity for the temp repo (needed for commits)
    git config user.email "test@framework.local"
    git config user.name "E2E Test"
    phase_pass "setup" "temp project at $TMPDIR_BASE"
else
    phase_fail "setup" "failed to create temp dir or git init"
    if [ "$JSON_OUTPUT" = true ]; then output_json; fi
    exit 1
fi

# =========================================================================
# Phase 2: Init — run fw init, validate artifacts
# =========================================================================
INIT_OUTPUT=$("$FRAMEWORK_ROOT/bin/fw" init 2>&1) || true

# Check critical artifacts exist
INIT_CHECKS=0
INIT_TOTAL=0

for dir in .tasks/active .tasks/completed .context/working .context/project .context/handovers; do
    INIT_TOTAL=$((INIT_TOTAL + 1))
    if [ -d "$dir" ]; then
        INIT_CHECKS=$((INIT_CHECKS + 1))
    elif [ "$VERBOSE" = true ]; then
        echo "    missing dir: $dir"
    fi
done

for file in .framework.yaml CLAUDE.md .claude/settings.json .context/project/learnings.yaml .context/project/patterns.yaml .tasks/templates/default.md; do
    INIT_TOTAL=$((INIT_TOTAL + 1))
    if [ -f "$file" ]; then
        INIT_CHECKS=$((INIT_CHECKS + 1))
    elif [ "$VERBOSE" = true ]; then
        echo "    missing file: $file"
    fi
done

# Check onboarding tasks were seeded
TASK_COUNT=$(find .tasks/active -name "T-*.md" 2>/dev/null | wc -l)
INIT_TOTAL=$((INIT_TOTAL + 1))
if [ "$TASK_COUNT" -gt 0 ]; then
    INIT_CHECKS=$((INIT_CHECKS + 1))
fi

if [ "$INIT_CHECKS" -eq "$INIT_TOTAL" ]; then
    phase_pass "init" "$INIT_CHECKS/$INIT_TOTAL artifacts, $TASK_COUNT onboarding tasks"
else
    phase_fail "init" "$INIT_CHECKS/$INIT_TOTAL artifacts ($((INIT_TOTAL - INIT_CHECKS)) missing)"
fi

# =========================================================================
# Phase 3: Doctor — run fw doctor, check exit code
# =========================================================================
# Run doctor from the temp project root (PROJECT_ROOT should resolve via .framework.yaml)
DOCTOR_OUTPUT=$(cd "$TMPDIR_BASE" && "$FRAMEWORK_ROOT/bin/fw" doctor 2>&1) || DOCTOR_EXIT=$?
DOCTOR_EXIT=${DOCTOR_EXIT:-0}

# Count doctor results
DOCTOR_OK=$(echo "$DOCTOR_OUTPUT" | grep -c "OK" || true)
DOCTOR_WARN=$(echo "$DOCTOR_OUTPUT" | grep -c "WARN" || true)
DOCTOR_FAIL=$(echo "$DOCTOR_OUTPUT" | grep -c "FAIL" || true)

# Doctor should pass (exit 0) for a freshly initialized project
# Warnings are acceptable (e.g., no bats, no git hooks installed by git agent)
if [ "${DOCTOR_EXIT}" -le 1 ]; then
    phase_pass "doctor" "${DOCTOR_OK} OK, ${DOCTOR_WARN} warn, ${DOCTOR_FAIL} fail (exit $DOCTOR_EXIT)"
else
    phase_fail "doctor" "exit code $DOCTOR_EXIT — ${DOCTOR_FAIL} failures"
    if [ "$VERBOSE" = true ]; then
        echo "$DOCTOR_OUTPUT" | grep -E "FAIL|WARN" | head -5 | sed 's/^/    /'
    fi
fi

# =========================================================================
# Phase 4: Serve — start Watchtower, run smoke test
# =========================================================================
# Check if test port is available
if ss -tlnp 2>/dev/null | grep -q ":${TEST_PORT} "; then
    phase_fail "serve" "port $TEST_PORT already in use"
else
    # Start Watchtower on test port in background
    cd "$FRAMEWORK_ROOT"
    PROJECT_ROOT="$TMPDIR_BASE" python3 -c "
import sys, os
sys.path.insert(0, '.')
os.environ['FW_PORT'] = '$TEST_PORT'
os.environ['PROJECT_ROOT'] = '$TMPDIR_BASE'
os.environ['FRAMEWORK_ROOT'] = '$FRAMEWORK_ROOT'
from web.app import app
app.run(host='127.0.0.1', port=$TEST_PORT, debug=False)
" >/dev/null 2>&1 &
    SERVE_PID=$!

    # Wait for server to be ready (up to 8 seconds)
    SERVER_READY=false
    for i in $(seq 1 16); do
        if curl -sf "http://localhost:${TEST_PORT}/health" >/dev/null 2>&1; then
            SERVER_READY=true
            break
        fi
        sleep 0.5
    done

    if [ "$SERVER_READY" = true ]; then
        phase_pass "serve-start" "Watchtower up on :$TEST_PORT (PID $SERVE_PID)"

        # Run smoke test
        SMOKE_OUTPUT=$(python3 "$FRAMEWORK_ROOT/web/smoke_test.py" --port "$TEST_PORT" --json 2>/dev/null) || true
        SMOKE_PASSED=$(echo "$SMOKE_OUTPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('passed',0))" 2>/dev/null || echo 0)
        SMOKE_FAILED=$(echo "$SMOKE_OUTPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('failed',0))" 2>/dev/null || echo 0)
        SMOKE_TOTAL=$(echo "$SMOKE_OUTPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('total',0))" 2>/dev/null || echo 0)

        if [ "${SMOKE_FAILED:-0}" = "0" ] && [ "${SMOKE_PASSED:-0}" -gt 0 ]; then
            phase_pass "smoke-test" "$SMOKE_PASSED/$SMOKE_TOTAL endpoints OK"
        else
            phase_fail "smoke-test" "$SMOKE_FAILED/$SMOKE_TOTAL endpoints failed"
            if [ "$VERBOSE" = true ]; then
                echo "$SMOKE_OUTPUT" | python3 -c "
import sys,json
d=json.load(sys.stdin)
for e in d.get('errors',[])[:5]:
    print(f\"    {e['path']}: {e.get('error','?')}\")
" 2>/dev/null || true
            fi
        fi

        # Kill server
        kill "$SERVE_PID" 2>/dev/null || true
        wait "$SERVE_PID" 2>/dev/null || true
        SERVE_PID=""
    else
        phase_fail "serve-start" "Watchtower failed to start on :$TEST_PORT within 8s"
        # Check if process died
        if ! kill -0 "$SERVE_PID" 2>/dev/null; then
            phase_fail "serve-process" "server process exited prematurely"
        fi
        kill "$SERVE_PID" 2>/dev/null || true
        wait "$SERVE_PID" 2>/dev/null || true
        SERVE_PID=""
    fi
fi

# =========================================================================
# Phase 5: Summary
# =========================================================================
ELAPSED=$(($(date +%s) - START_TIME))

if [ "$JSON_OUTPUT" = true ]; then
    output_json
else
    echo ""
    if [ "$TOTAL_FAILED" -eq 0 ]; then
        echo -e "${GREEN}All $TOTAL_PASSED phases passed${NC} (${ELAPSED}s)"
    else
        echo -e "${RED}$TOTAL_FAILED/$((TOTAL_PASSED+TOTAL_FAILED)) phases failed${NC} (${ELAPSED}s)"
    fi
fi

# Exit code: 0 = all pass, 1 = failures
[ "$TOTAL_FAILED" -eq 0 ]
