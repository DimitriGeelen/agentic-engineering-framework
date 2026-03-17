#!/usr/bin/env bash
# E2E assertion helpers for TermLink-based framework testing.
# Source this file in test scripts: source "$(dirname "$0")/../lib/assert.sh"
#
# Each assert function increments PASS/FAIL counters and prints result.
# Uses TermLink interact for remote assertions when SESSION is set.

PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0
RESULTS_JSON="[]"

# Colors (disabled in JSON mode)
if [ "${JSON_OUTPUT:-false}" = true ]; then
    _G="" _R="" _Y="" _B="" _N=""
else
    _G='\033[0;32m' _R='\033[0;31m' _Y='\033[0;33m' _B='\033[1m' _N='\033[0m'
fi

_record_result() {
    local scenario="$1" name="$2" status="$3" detail="${4:-}"
    if [ "${JSON_OUTPUT:-false}" = true ]; then
        local entry
        entry=$(printf '{"scenario":"%s","name":"%s","status":"%s","detail":"%s"}' \
            "$scenario" "$name" "$status" "$detail")
        RESULTS_JSON=$(echo "$RESULTS_JSON" | python3 -c "
import sys, json
arr = json.load(sys.stdin)
arr.append(json.loads('$entry'))
print(json.dumps(arr))
" 2>/dev/null || echo "$RESULTS_JSON")
    fi
}

# assert_exit_code CMD EXPECTED_CODE SCENARIO_ID DESCRIPTION
# Run a command and check its exit code.
assert_exit_code() {
    local cmd="$1" expected="$2" scenario="$3" desc="$4"
    local actual=0
    eval "$cmd" >/dev/null 2>&1 || actual=$?
    if [ "$actual" -eq "$expected" ]; then
        PASS_COUNT=$((PASS_COUNT + 1))
        _record_result "$scenario" "$desc" "PASS"
        printf "${_G}PASS${_N} [%s] %s\n" "$scenario" "$desc"
    else
        FAIL_COUNT=$((FAIL_COUNT + 1))
        _record_result "$scenario" "$desc" "FAIL" "expected exit $expected, got $actual"
        printf "${_R}FAIL${_N} [%s] %s (expected exit %d, got %d)\n" "$scenario" "$desc" "$expected" "$actual"
    fi
}

# assert_file_exists PATH SCENARIO_ID DESCRIPTION
assert_file_exists() {
    local path="$1" scenario="$2" desc="$3"
    if [ -f "$path" ]; then
        PASS_COUNT=$((PASS_COUNT + 1))
        _record_result "$scenario" "$desc" "PASS"
        printf "${_G}PASS${_N} [%s] %s\n" "$scenario" "$desc"
    else
        FAIL_COUNT=$((FAIL_COUNT + 1))
        _record_result "$scenario" "$desc" "FAIL" "file not found: $path"
        printf "${_R}FAIL${_N} [%s] %s (not found: %s)\n" "$scenario" "$desc" "$path"
    fi
}

# assert_file_not_exists PATH SCENARIO_ID DESCRIPTION
assert_file_not_exists() {
    local path="$1" scenario="$2" desc="$3"
    if [ ! -f "$path" ]; then
        PASS_COUNT=$((PASS_COUNT + 1))
        _record_result "$scenario" "$desc" "PASS"
        printf "${_G}PASS${_N} [%s] %s\n" "$scenario" "$desc"
    else
        FAIL_COUNT=$((FAIL_COUNT + 1))
        _record_result "$scenario" "$desc" "FAIL" "file exists: $path"
        printf "${_R}FAIL${_N} [%s] %s (exists: %s)\n" "$scenario" "$desc" "$path"
    fi
}

# assert_grep PATTERN FILE SCENARIO_ID DESCRIPTION
assert_grep() {
    local pattern="$1" file="$2" scenario="$3" desc="$4"
    if grep -q "$pattern" "$file" 2>/dev/null; then
        PASS_COUNT=$((PASS_COUNT + 1))
        _record_result "$scenario" "$desc" "PASS"
        printf "${_G}PASS${_N} [%s] %s\n" "$scenario" "$desc"
    else
        FAIL_COUNT=$((FAIL_COUNT + 1))
        _record_result "$scenario" "$desc" "FAIL" "pattern not found: $pattern"
        printf "${_R}FAIL${_N} [%s] %s (pattern not found: %s)\n" "$scenario" "$desc" "$pattern"
    fi
}

# assert_not_grep PATTERN FILE SCENARIO_ID DESCRIPTION
assert_not_grep() {
    local pattern="$1" file="$2" scenario="$3" desc="$4"
    if ! grep -q "$pattern" "$file" 2>/dev/null; then
        PASS_COUNT=$((PASS_COUNT + 1))
        _record_result "$scenario" "$desc" "PASS"
        printf "${_G}PASS${_N} [%s] %s\n" "$scenario" "$desc"
    else
        FAIL_COUNT=$((FAIL_COUNT + 1))
        _record_result "$scenario" "$desc" "FAIL" "pattern found: $pattern"
        printf "${_R}FAIL${_N} [%s] %s (pattern found: %s)\n" "$scenario" "$desc" "$pattern"
    fi
}

# assert_yaml_field FILE FIELD EXPECTED SCENARIO_ID DESCRIPTION
# Check a YAML field value using python3.
assert_yaml_field() {
    local file="$1" field="$2" expected="$3" scenario="$4" desc="$5"
    local actual
    actual=$(python3 -c "
import yaml, sys
with open('$file') as f:
    d = yaml.safe_load(f)
keys = '$field'.split('.')
v = d
for k in keys:
    v = v[k]
print(v)
" 2>/dev/null) || actual="ERROR"

    if [ "$actual" = "$expected" ]; then
        PASS_COUNT=$((PASS_COUNT + 1))
        _record_result "$scenario" "$desc" "PASS"
        printf "${_G}PASS${_N} [%s] %s\n" "$scenario" "$desc"
    else
        FAIL_COUNT=$((FAIL_COUNT + 1))
        _record_result "$scenario" "$desc" "FAIL" "expected '$expected', got '$actual'"
        printf "${_R}FAIL${_N} [%s] %s (expected '%s', got '%s')\n" "$scenario" "$desc" "$expected" "$actual"
    fi
}

# assert_tl_exit SESSION CMD EXPECTED_CODE SCENARIO_ID DESCRIPTION
# Run a command in a TermLink session and check exit code.
assert_tl_exit() {
    local session="$1" cmd="$2" expected="$3" scenario="$4" desc="$5"
    local result actual
    result=$(termlink interact "$session" "$cmd" --json --strip-ansi --timeout 30 2>/dev/null) || result='{"exit_code":-1}'
    actual=$(echo "$result" | python3 -c "import sys,json; print(json.load(sys.stdin).get('exit_code',-1))" 2>/dev/null) || actual=-1

    if [ "$actual" -eq "$expected" ]; then
        PASS_COUNT=$((PASS_COUNT + 1))
        _record_result "$scenario" "$desc" "PASS"
        printf "${_G}PASS${_N} [%s] %s\n" "$scenario" "$desc"
    else
        FAIL_COUNT=$((FAIL_COUNT + 1))
        _record_result "$scenario" "$desc" "FAIL" "expected exit $expected, got $actual"
        printf "${_R}FAIL${_N} [%s] %s (expected exit %d, got %d)\n" "$scenario" "$desc" "$expected" "$actual"
    fi
}

# assert_tl_output_contains SESSION CMD PATTERN SCENARIO_ID DESCRIPTION
# Run a command in a TermLink session and check output contains pattern.
assert_tl_output_contains() {
    local session="$1" cmd="$2" pattern="$3" scenario="$4" desc="$5"
    local result output
    result=$(termlink interact "$session" "$cmd" --json --strip-ansi --timeout 30 2>/dev/null) || result='{"output":""}'
    output=$(echo "$result" | python3 -c "import sys,json; print(json.load(sys.stdin).get('output',''))" 2>/dev/null) || output=""

    if echo "$output" | grep -q "$pattern"; then
        PASS_COUNT=$((PASS_COUNT + 1))
        _record_result "$scenario" "$desc" "PASS"
        printf "${_G}PASS${_N} [%s] %s\n" "$scenario" "$desc"
    else
        FAIL_COUNT=$((FAIL_COUNT + 1))
        _record_result "$scenario" "$desc" "FAIL" "output missing: $pattern"
        printf "${_R}FAIL${_N} [%s] %s (output missing: %s)\n" "$scenario" "$desc" "$pattern"
    fi
}

# skip SCENARIO_ID DESCRIPTION REASON
skip() {
    local scenario="$1" desc="$2" reason="$3"
    SKIP_COUNT=$((SKIP_COUNT + 1))
    _record_result "$scenario" "$desc" "SKIP" "$reason"
    printf "${_Y}SKIP${_N} [%s] %s (%s)\n" "$scenario" "$desc" "$reason"
}

# print_summary — print totals, return exit code
print_summary() {
    local total=$((PASS_COUNT + FAIL_COUNT + SKIP_COUNT))
    echo ""
    printf "${_B}Results:${_N} %d total, ${_G}%d pass${_N}, ${_R}%d fail${_N}, ${_Y}%d skip${_N}\n" \
        "$total" "$PASS_COUNT" "$FAIL_COUNT" "$SKIP_COUNT"
    [ "$FAIL_COUNT" -eq 0 ]
}

# print_json_summary — JSON output for CI
print_json_summary() {
    local total=$((PASS_COUNT + FAIL_COUNT + SKIP_COUNT))
    python3 -c "
import json, sys
results = json.loads('''$RESULTS_JSON''')
summary = {
    'suite': '${SUITE_NAME:-e2e}',
    'timestamp': '$(date -u +%Y-%m-%dT%H:%M:%SZ)',
    'results': results,
    'summary': {
        'total': $total,
        'pass': $PASS_COUNT,
        'fail': $FAIL_COUNT,
        'skip': $SKIP_COUNT
    }
}
print(json.dumps(summary, indent=2))
"
}
