#!/usr/bin/env bats
# Unit tests for agents/healing/lib/diagnose.sh
#
# Tests pure functions: classify_failure, score_pattern
#
# Note: classify_failure uses `declare -A` associative arrays which are
# scoped locally when sourced inside bats functions. We use bash -c
# subprocesses to ensure proper scoping of the associative array.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    mkdir -p "$PROJECT_ROOT/.tasks/active" "$PROJECT_ROOT/.context/project"
    export TASKS_DIR="$PROJECT_ROOT/.tasks"
    export PATTERNS_FILE="$PROJECT_ROOT/.context/project/patterns.yaml"
    RED='' GREEN='' YELLOW='' CYAN='' BLUE='' NC=''
    # Source for score_pattern (no associative array dependency)
    source "$FRAMEWORK_ROOT/agents/healing/lib/diagnose.sh"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# Helper: run classify_failure in a fresh bash where declare -A works at global scope
_classify() {
    local text="$1"
    bash -c '
        RED="" GREEN="" YELLOW="" CYAN="" BLUE="" NC=""
        TASKS_DIR="/tmp" PATTERNS_FILE="/tmp/none"
        source "$1/agents/healing/lib/diagnose.sh"
        classify_failure "$2"
    ' _ "$FRAMEWORK_ROOT" "$text"
}

# --- classify_failure: dependency ---

@test "classify_failure: detects 'module' keyword as dependency" {
    result=$(_classify "missing module foo-bar")
    [ "$result" = "dependency" ]
}

@test "classify_failure: detects 'package' keyword as dependency" {
    result=$(_classify "package not found in registry")
    [ "$result" = "dependency" ]
}

@test "classify_failure: detects 'npm install' as dependency" {
    result=$(_classify "npm install failed with exit code 1")
    [ "$result" = "dependency" ]
}

@test "classify_failure: detects 'version conflict' as dependency" {
    result=$(_classify "version conflict between lib A and lib B")
    [ "$result" = "dependency" ]
}

@test "classify_failure: detects 'import' keyword as dependency" {
    result=$(_classify "cannot import from shared library")
    [ "$result" = "dependency" ]
}

# --- classify_failure: external ---

@test "classify_failure: detects 'api' keyword as external" {
    result=$(_classify "the api returned 503")
    [ "$result" = "external" ]
}

@test "classify_failure: detects 'rate limit' as external" {
    result=$(_classify "rate limit exceeded on requests")
    [ "$result" = "external" ]
}

@test "classify_failure: detects 'network' as external" {
    result=$(_classify "network timeout when calling upstream")
    [ "$result" = "external" ]
}

@test "classify_failure: detects 'third-party' as external" {
    result=$(_classify "third-party service is down")
    [ "$result" = "external" ]
}

# --- classify_failure: environment ---

@test "classify_failure: detects 'permission denied' as environment" {
    result=$(_classify "permission denied accessing /etc/secret")
    [ "$result" = "environment" ]
}

@test "classify_failure: detects 'connection refused' as environment" {
    result=$(_classify "connection refused on port 5432")
    [ "$result" = "environment" ]
}

@test "classify_failure: detects 'config' as environment" {
    result=$(_classify "config file not loaded properly")
    [ "$result" = "environment" ]
}

@test "classify_failure: detects '.env' as environment" {
    result=$(_classify "the .env file is missing variables")
    [ "$result" = "environment" ]
}

# --- classify_failure: design ---

@test "classify_failure: detects 'architecture' as design" {
    result=$(_classify "the architecture needs rethinking")
    [ "$result" = "design" ]
}

@test "classify_failure: detects 'redesign' as design" {
    result=$(_classify "we need to redesign the whole flow")
    [ "$result" = "design" ]
}

@test "classify_failure: detects 'wrong approach' as design" {
    result=$(_classify "this is the wrong approach entirely")
    [ "$result" = "design" ]
}

# --- classify_failure: code ---

@test "classify_failure: detects 'syntax' as code" {
    result=$(_classify "syntax problem in line 42")
    [ "$result" = "code" ]
}

@test "classify_failure: detects 'traceback' as code" {
    result=$(_classify "traceback from Python script")
    [ "$result" = "code" ]
}

@test "classify_failure: detects 'null' reference as code" {
    result=$(_classify "null pointer in function X")
    [ "$result" = "code" ]
}

@test "classify_failure: detects 'undefined' as code" {
    result=$(_classify "variable is undefined at runtime")
    [ "$result" = "code" ]
}

# --- classify_failure: unknown ---

@test "classify_failure: returns unknown for unrecognized text" {
    result=$(_classify "everything is fine nothing wrong")
    [ "$result" = "unknown" ]
}

@test "classify_failure: returns unknown for empty input" {
    result=$(_classify "")
    [ "$result" = "unknown" ]
}

# --- classify_failure: mixed keywords / specificity ---

@test "classify_failure: dependency beats code at equal score (checked first)" {
    # 'import' matches dependency (1 hit), 'error' matches code (1 hit)
    # Both score 1. Since strict-greater is required to replace, first match wins.
    # dependency is checked before code in CLASSIFY_ORDER.
    result=$(_classify "import error detected")
    [ "$result" = "dependency" ]
}

@test "classify_failure: more keyword matches wins regardless of order" {
    # code: 'error' + 'exception' + 'bug' = 3 matches
    # dependency: 'import' = 1 match
    result=$(_classify "import caused error exception and bug")
    [ "$result" = "code" ]
}

@test "classify_failure: case insensitive matching" {
    result=$(_classify "TRACEBACK FROM NULL EXCEPTION")
    [ "$result" = "code" ]
}

@test "classify_failure: external beats code when more specific" {
    # external: 'api' + 'service' + 'endpoint' = 3 matches
    # code: 'error' = 1 match
    result=$(_classify "api service endpoint error")
    [ "$result" = "external" ]
}

# --- score_pattern: matching words ---

@test "score_pattern: counts matching words from pattern" {
    result=$(score_pattern "database connection timeout" "" "database connection timeout occurred")
    [ "$result" -ge 2 ]
}

@test "score_pattern: returns zero for no matching words" {
    result=$(score_pattern "database connection timeout" "" "something completely different here")
    [ "$result" -eq 0 ]
}

@test "score_pattern: skips short words under 3 chars in pattern" {
    # 'an' and 'is' are < 3 chars, should be skipped
    result=$(score_pattern "an is" "" "an is fine")
    [ "$result" -eq 0 ]
}

@test "score_pattern: includes words of exactly 3 chars in pattern" {
    # 'bad' is exactly 3 chars (not < 3), should be counted
    result=$(score_pattern "bad" "" "bad thing happened")
    [ "$result" -eq 1 ]
}

@test "score_pattern: adds score from mitigation when present" {
    result=$(score_pattern "timeout" "retry logic" "timeout needs retry logic")
    # 'timeout' from pattern (7 chars >= 3, matches) = 1
    # 'retry' from mitigation (5 chars >= 4, matches) = 1
    # 'logic' from mitigation (5 chars >= 4, matches) = 1
    [ "$result" -eq 3 ]
}

@test "score_pattern: skips short words under 4 chars in mitigation" {
    # 'add' is 3 chars, < 4, should be skipped from mitigation
    result=$(score_pattern "" "add" "add something here")
    [ "$result" -eq 0 ]
}

@test "score_pattern: includes mitigation words of exactly 4 chars" {
    # 'wait' is exactly 4 chars (not < 4), should be counted
    result=$(score_pattern "" "wait" "wait for response")
    [ "$result" -eq 1 ]
}

@test "score_pattern: returns zero for empty inputs" {
    result=$(score_pattern "" "" "some description here")
    [ "$result" -eq 0 ]
}

@test "score_pattern: returns zero when description is empty" {
    result=$(score_pattern "timeout error" "retry logic" "")
    [ "$result" -eq 0 ]
}

@test "score_pattern: counts each matching word once" {
    # pattern has 'timeout' and 'server', both appear in description
    result=$(score_pattern "timeout server" "" "timeout on server side")
    [ "$result" -eq 2 ]
}
