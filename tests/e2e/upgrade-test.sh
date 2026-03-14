#!/bin/bash
# E2E test: fw update + fw upgrade
# Tests the framework update and consumer project upgrade flow.
# Can be run standalone or as part of fw self-test.
set -euo pipefail

# --- Resolve framework root ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
export FRAMEWORK_ROOT

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

# --- Parse args ---
JSON_OUTPUT=false
VERBOSE=false
while [[ $# -gt 0 ]]; do
    case $1 in
        --json) JSON_OUTPUT=true; shift ;;
        --verbose) VERBOSE=true; shift ;;
        -h|--help)
            echo "Usage: upgrade-test.sh [--json] [--verbose]"
            echo "Tests fw update and fw upgrade commands."
            exit 0
            ;;
        *) shift ;;
    esac
done

# --- Test tracking ---
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0
FAILED_NAMES=""
TMPDIR=""

phase_pass() {
    TESTS_PASSED=$((TESTS_PASSED + 1))
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    if [ "$JSON_OUTPUT" = false ]; then
        echo -e "  ${GREEN}PASS${NC}  $1 — $2"
    fi
}

phase_fail() {
    TESTS_FAILED=$((TESTS_FAILED + 1))
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    FAILED_NAMES="${FAILED_NAMES}${1},"
    if [ "$JSON_OUTPUT" = false ]; then
        echo -e "  ${RED}FAIL${NC}  $1 — $2"
    fi
}

cleanup() {
    if [ -n "$TMPDIR" ] && [ -d "$TMPDIR" ]; then
        rm -rf "$TMPDIR"
    fi
}
trap cleanup EXIT

output_json() {
    if [ "$JSON_OUTPUT" = true ]; then
        cat <<ENDJSON
{"phase":"upgrade","passed":$TESTS_PASSED,"failed":$TESTS_FAILED,"total":$TESTS_TOTAL,"failed_tests":"$FAILED_NAMES"}
ENDJSON
    fi
}

# --- Header ---
if [ "$JSON_OUTPUT" = false ]; then
    echo -e "${BOLD}fw self-test: upgrade${NC}"
    echo ""
fi

# ══════════════════════════════════════════════════════════════
# Test 1: fw update --help works
# ══════════════════════════════════════════════════════════════
if "$FRAMEWORK_ROOT/bin/fw" update --help 2>/dev/null | grep -q "Check for updates"; then
    phase_pass "update-help" "fw update --help shows usage"
else
    phase_fail "update-help" "fw update --help output unexpected"
fi

# ══════════════════════════════════════════════════════════════
# Test 2: fw update --check works (fetches and compares, or reports network error)
# ══════════════════════════════════════════════════════════════
update_check_output=$("$FRAMEWORK_ROOT/bin/fw" update --check 2>&1 || true)
if echo "$update_check_output" | grep -qE "Already up to date|Update available|Failed to fetch"; then
    phase_pass "update-check" "fw update --check reports status"
else
    phase_fail "update-check" "fw update --check output unexpected"
    if [ "$VERBOSE" = true ]; then
        echo "    Output: $(echo "$update_check_output" | head -5)"
    fi
fi

# ══════════════════════════════════════════════════════════════
# Test 3: fw upgrade --help works
# ══════════════════════════════════════════════════════════════
if "$FRAMEWORK_ROOT/bin/fw" upgrade --help 2>/dev/null | grep -q "Sync framework improvements"; then
    phase_pass "upgrade-help" "fw upgrade --help shows usage"
else
    phase_fail "upgrade-help" "fw upgrade --help output unexpected"
fi

# ══════════════════════════════════════════════════════════════
# Test 4: Create temp project and run fw upgrade --dry-run
# ══════════════════════════════════════════════════════════════
TMPDIR=$(mktemp -d /tmp/fw-e2e-upgrade-XXXXXXXX)
(cd "$TMPDIR" && git init --quiet)

# Initialize project (set PROJECT_ROOT to avoid auto-init re-exec)
PROJECT_ROOT="$TMPDIR" "$FRAMEWORK_ROOT/bin/fw" init "$TMPDIR" --provider claude --no-first-run > /dev/null 2>&1

if [ -f "$TMPDIR/.framework.yaml" ]; then
    # Run upgrade --dry-run
    upgrade_output=$("$FRAMEWORK_ROOT/bin/fw" upgrade "$TMPDIR" --dry-run 2>&1 || true)
    if echo "$upgrade_output" | grep -qE "Dry Run Complete|Already Up To Date"; then
        phase_pass "upgrade-dryrun" "fw upgrade --dry-run on fresh project"
    else
        phase_fail "upgrade-dryrun" "fw upgrade --dry-run output unexpected"
        if [ "$VERBOSE" = true ]; then
            echo "    Output: $(echo "$upgrade_output" | tail -5)"
        fi
    fi
else
    phase_fail "upgrade-dryrun" "fw init failed (no .framework.yaml)"
fi

# ══════════════════════════════════════════════════════════════
# Test 5: fw upgrade applies version tracking
# ══════════════════════════════════════════════════════════════
if [ -f "$TMPDIR/.framework.yaml" ]; then
    # Remove version line if present (to test it gets added)
    if grep -q "^version:" "$TMPDIR/.framework.yaml" 2>/dev/null; then
        grep -v "^version:" "$TMPDIR/.framework.yaml" > "$TMPDIR/.framework.yaml.tmp" && \
            mv "$TMPDIR/.framework.yaml.tmp" "$TMPDIR/.framework.yaml"
    fi

    # Run actual upgrade
    upgrade_output=$("$FRAMEWORK_ROOT/bin/fw" upgrade "$TMPDIR" 2>&1 || true)

    # Check version was written
    if grep -q "^version:" "$TMPDIR/.framework.yaml" 2>/dev/null; then
        local_version=$(grep "^version:" "$TMPDIR/.framework.yaml" | sed 's/^version:[[:space:]]*//')
        # FW_VERSION is defined in bin/fw line 14, may differ from VERSION file
        fw_version=$(grep '^FW_VERSION=' "$FRAMEWORK_ROOT/bin/fw" | head -1 | sed 's/FW_VERSION="//;s/"//')
        if [ -z "$fw_version" ]; then
            fw_version=$(cat "$FRAMEWORK_ROOT/VERSION" 2>/dev/null || echo "unknown")
        fi
        if [ "$local_version" = "$fw_version" ]; then
            phase_pass "version-track" "version $fw_version recorded in .framework.yaml"
        else
            phase_fail "version-track" "version mismatch: got $local_version, expected $fw_version"
        fi
    else
        phase_fail "version-track" "version not written to .framework.yaml"
    fi
else
    phase_fail "version-track" "no .framework.yaml to test"
fi

# ══════════════════════════════════════════════════════════════
# Test 6: fw upgrade creates missing context subdirs
# ══════════════════════════════════════════════════════════════
if [ -d "$TMPDIR/.context" ]; then
    # Remove a context subdir to test recreation
    rm -rf "$TMPDIR/.context/bus" 2>/dev/null || true
    rm -rf "$TMPDIR/.context/inbox" 2>/dev/null || true

    "$FRAMEWORK_ROOT/bin/fw" upgrade "$TMPDIR" > /dev/null 2>&1 || true

    if [ -d "$TMPDIR/.context/bus" ] && [ -d "$TMPDIR/.context/inbox" ]; then
        phase_pass "ctx-dirs" "missing .context/ subdirs recreated"
    else
        phase_fail "ctx-dirs" ".context/ subdirs not recreated"
    fi
else
    phase_fail "ctx-dirs" "no .context/ directory"
fi

# ══════════════════════════════════════════════════════════════
# Test 7: fw upgrade shows version comparison
# ══════════════════════════════════════════════════════════════
upgrade_output=$("$FRAMEWORK_ROOT/bin/fw" upgrade "$TMPDIR" --dry-run 2>&1 || true)
if echo "$upgrade_output" | grep -qE "Pinned:.*v[0-9]|Pinned:.*current"; then
    phase_pass "version-display" "version comparison shown in upgrade output"
else
    phase_fail "version-display" "version comparison not shown"
    if [ "$VERBOSE" = true ]; then
        echo "    Output: $(echo "$upgrade_output" | head -8)"
    fi
fi

# ══════════════════════════════════════════════════════════════
# Test 8: fw update --rollback with no rollback point
# ══════════════════════════════════════════════════════════════
rollback_output=$("$FRAMEWORK_ROOT/bin/fw" update --rollback 2>&1 || true)
if echo "$rollback_output" | grep -qE "No rollback point|Rolled back"; then
    phase_pass "rollback-guard" "rollback handled gracefully"
else
    phase_fail "rollback-guard" "rollback output unexpected"
fi

# --- Summary ---
if [ "$JSON_OUTPUT" = false ]; then
    echo ""
    if [ "$TESTS_FAILED" -eq 0 ]; then
        echo -e "${GREEN}All $TESTS_TOTAL upgrade tests passed${NC}"
    else
        echo -e "${RED}$TESTS_FAILED/$TESTS_TOTAL upgrade tests failed${NC}"
    fi
fi

output_json

if [ "$TESTS_FAILED" -gt 0 ]; then
    exit 1
fi
exit 0
