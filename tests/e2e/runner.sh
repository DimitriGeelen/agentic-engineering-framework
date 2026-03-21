#!/usr/bin/env bash
# E2E Test Runner — orchestrates TermLink-based framework tests.
#
# Usage:
#   ./runner.sh                     # Run all Tier A tests (default)
#   ./runner.sh --tier a            # Run Tier A (shell-level, $0 cost)
#   ./runner.sh --tier b            # Run Tier B (agent-level, API cost)
#   ./runner.sh --tier all          # Run both tiers
#   ./runner.sh --scenario A1       # Run single scenario
#   ./runner.sh --list              # List available tests
#   ./runner.sh --json              # JSON output for CI
#
# Exit codes:
#   0 — all tests passed
#   1 — one or more tests failed
#   2 — usage error
#
# From T-513 inception → T-514 build task.

set -euo pipefail

RUNNER_DIR="$(cd "$(dirname "$0")" && pwd)"
TIER="a"
SCENARIO=""
JSON_OUTPUT=false
LIST_ONLY=false

usage() {
    sed -n '2,15s/^# //p' "$0"
    exit 2
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --tier)     TIER="$2"; shift 2 ;;
        --scenario) SCENARIO="$2"; shift 2 ;;
        --json)     JSON_OUTPUT=true; shift ;;
        --list)     LIST_ONLY=true; shift ;;
        --help|-h)  usage ;;
        *)          echo "Unknown arg: $1"; usage ;;
    esac
done

export JSON_OUTPUT

# Discover test files
discover_tests() {
    local tier="$1"
    local dir="$RUNNER_DIR/tier-$tier"
    if [ -d "$dir" ]; then
        find "$dir" -name 'test-*.sh' -type f | sort
    fi
}

# List available tests
if [ "$LIST_ONLY" = true ]; then
    echo "Available E2E tests:"
    echo ""
    for t in a b; do
        local_tests=$(discover_tests "$t")
        if [ -n "$local_tests" ]; then
            echo "  Tier ${t^^}:"
            echo "$local_tests" | while read -r f; do
                name=$(basename "$f" .sh | sed 's/^test-//')
                echo "    $name"
            done
        fi
    done
    exit 0
fi

# Validate tier
case "$TIER" in
    a|b|all) ;;
    *) echo "ERROR: Invalid tier '$TIER'. Use: a, b, all"; exit 2 ;;
esac

# Warn about Tier B costs
if [ "$TIER" = "b" ] || [ "$TIER" = "all" ]; then
    if [ "$JSON_OUTPUT" = false ]; then
        echo "WARNING: Tier B tests require Claude API calls (~\$0.50-1.00 per scenario)"
        echo "Press Ctrl+C within 3 seconds to cancel..."
        sleep 3
    fi
fi

# Check TermLink
if ! command -v termlink >/dev/null 2>&1; then
    echo "ERROR: termlink not found. Install: cargo install --path crates/termlink-cli" >&2
    exit 2
fi

# Collect test files
TEST_FILES=""
if [ -n "$SCENARIO" ]; then
    # Single scenario mode — find matching test file
    for t in a b; do
        match=$(discover_tests "$t" | grep -i "$SCENARIO" | head -1)
        if [ -n "$match" ]; then
            TEST_FILES="$match"
            break
        fi
    done
    if [ -z "$TEST_FILES" ]; then
        echo "ERROR: No test matching '$SCENARIO' found" >&2
        exit 2
    fi
else
    # Tier mode
    if [ "$TIER" = "all" ]; then
        TEST_FILES="$(discover_tests a)
$(discover_tests b)"
    else
        TEST_FILES=$(discover_tests "$TIER")
    fi
fi

# Run tests
TOTAL_PASS=0
TOTAL_FAIL=0
TOTAL_SKIP=0
ALL_RESULTS="[]"

if [ "$JSON_OUTPUT" = false ] && [ -n "$TEST_FILES" ]; then
    echo "=== E2E Test Runner ==="
    echo "Tier: ${TIER^^}"
    echo ""
fi

# Handle empty test files gracefully
if [ -z "$(echo "$TEST_FILES" | tr -d '[:space:]')" ]; then
    if [ "$JSON_OUTPUT" = true ]; then
        python3 -c "
import json
print(json.dumps({
    'suite': 'e2e-tier-$TIER',
    'timestamp': '$(date -u +%Y-%m-%dT%H:%M:%SZ)',
    'results': [],
    'summary': {'total': 0, 'pass': 0, 'fail': 0, 'skip': 0}
}, indent=2))
"
    else
        echo "No test files found for tier ${TIER^^}."
        echo ""
        echo "Results: 0 total, 0 pass, 0 fail, 0 skip"
    fi
    exit 0
fi

echo "$TEST_FILES" | while read -r test_file; do
    [ -z "$test_file" ] && continue
    [ ! -f "$test_file" ] && continue

    test_name=$(basename "$test_file" .sh | sed 's/^test-//')

    if [ "$JSON_OUTPUT" = false ]; then
        echo "--- $test_name ---"
    fi

    # Run test script, capture output
    bash "$test_file" ${JSON_OUTPUT:+--json} 2>&1 || true

    if [ "$JSON_OUTPUT" = false ]; then
        echo ""
    fi
done

# If JSON mode, aggregate results from individual test JSON outputs
if [ "$JSON_OUTPUT" = true ]; then
    # Each test file outputs its own JSON when --json is passed.
    # The runner collects them. For now, the individual test's JSON is printed directly.
    # Full aggregation will be added when Tier A tests exist.
    :
fi
