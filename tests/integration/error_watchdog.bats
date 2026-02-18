#!/usr/bin/env bats
# Integration tests for agents/context/error-watchdog.sh (PostToolUse hook)
#
# Tests the error watchdog behavior:
#   - Only fires for Bash tool calls
#   - Exit code 0 → silent (no output)
#   - Critical exit codes (126, 127, 137, 139) → always warns
#   - Non-zero exit codes with high-confidence stderr patterns → warns
#   - Non-zero exit codes with benign stderr → silent
#   - Always exits 0 (advisory hook)
#   - Output is JSON with hookSpecificOutput.additionalContext when warning

load ../test_helper

WATCHDOG="$FRAMEWORK_ROOT/agents/context/error-watchdog.sh"

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# Helper: build JSON input and run the watchdog via stdin redirect
# Usage: run_watchdog <tool_name> <exit_code> [stderr] [stdout]
# Sets bats $status and $output variables.
run_watchdog() {
    local tool_name="${1:-Bash}"
    local exit_code="${2:-0}"
    local stderr="${3:-}"
    local stdout="${4:-}"
    # Escape special chars for JSON using python3
    stderr=$(printf '%s' "$stderr" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read())[1:-1])")
    stdout=$(printf '%s' "$stdout" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read())[1:-1])")
    local json_input="{\"tool_name\": \"$tool_name\", \"tool_response\": {\"exitCode\": $exit_code, \"stderr\": \"$stderr\", \"stdout\": \"$stdout\"}}"
    local input_file="$TEST_TEMP_DIR/input.json"
    printf '%s' "$json_input" > "$input_file"
    run bash -c "'$WATCHDOG' < '$input_file'"
}

# Helper: run watchdog with raw string on stdin (for malformed input tests)
run_watchdog_raw() {
    local raw_input="$1"
    local input_file="$TEST_TEMP_DIR/input_raw.json"
    printf '%s' "$raw_input" > "$input_file"
    run bash -c "'$WATCHDOG' < '$input_file'"
}

# --- Test 1: Bash exit 0 → exit 0, no output ---

@test "Bash exit 0: silent exit 0, no output" {
    run_watchdog "Bash" 0 "" ""
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

# --- Test 2: Non-Bash tool (Write) exit 1 → exit 0, no output (ignored) ---

@test "non-Bash tool (Write) exit 1: ignored, silent exit 0" {
    run_watchdog "Write" 1 "ERROR: something broke" ""
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

# --- Test 3: Bash exit 127 (command not found) → exit 0, has JSON output ---

@test "Bash exit 127: warns with JSON additionalContext" {
    run_watchdog "Bash" 127 "bash: foobar: command not found" ""
    [ "$status" -eq 0 ]
    [ -n "$output" ]
    # Verify JSON structure
    echo "$output" | python3 -c "import sys,json; d=json.load(sys.stdin); assert 'hookSpecificOutput' in d; assert 'additionalContext' in d['hookSpecificOutput']"
    # Verify exit code mentioned
    [[ "$output" == *"exit 127"* ]]
    # Verify it mentions Command not found (critical code description)
    [[ "$output" == *"Command not found"* ]]
}

# --- Test 4: Bash exit 139 (SIGSEGV) → exit 0, has JSON output ---

@test "Bash exit 139 (SIGSEGV): warns with JSON additionalContext" {
    run_watchdog "Bash" 139 "Segmentation fault (core dumped)" ""
    [ "$status" -eq 0 ]
    [ -n "$output" ]
    echo "$output" | python3 -c "import sys,json; d=json.load(sys.stdin); assert 'additionalContext' in d['hookSpecificOutput']"
    [[ "$output" == *"exit 139"* ]]
    [[ "$output" == *"SIGSEGV"* ]]
}

# --- Test 5: Bash exit 1 with "ERROR:" in stderr → exit 0, has JSON output ---

@test "Bash exit 1 with ERROR: in stderr: warns" {
    run_watchdog "Bash" 1 "ERROR: database connection failed" ""
    [ "$status" -eq 0 ]
    [ -n "$output" ]
    echo "$output" | python3 -c "import sys,json; d=json.load(sys.stdin); assert 'additionalContext' in d['hookSpecificOutput']"
    [[ "$output" == *"exit 1"* ]]
    [[ "$output" == *"database connection failed"* ]]
}

# --- Test 6: Bash exit 1 with "Traceback (most recent" → exit 0, has JSON output ---

@test "Bash exit 1 with Python traceback: warns" {
    run_watchdog "Bash" 1 "Traceback (most recent call last):" ""
    [ "$status" -eq 0 ]
    [ -n "$output" ]
    echo "$output" | python3 -c "import sys,json; d=json.load(sys.stdin); assert 'additionalContext' in d['hookSpecificOutput']"
    [[ "$output" == *"Traceback"* ]]
}

# --- Test 7: Bash exit 1 with "Permission denied" → exit 0, has JSON output ---

@test "Bash exit 1 with Permission denied: warns" {
    run_watchdog "Bash" 1 "bash: /etc/shadow: Permission denied" ""
    [ "$status" -eq 0 ]
    [ -n "$output" ]
    echo "$output" | python3 -c "import sys,json; d=json.load(sys.stdin); assert 'additionalContext' in d['hookSpecificOutput']"
    [[ "$output" == *"Permission denied"* ]]
}

# --- Test 8: Bash exit 1 with benign stderr (no patterns) → exit 0, no output ---

@test "Bash exit 1 with benign stderr: silent, no output" {
    run_watchdog "Bash" 1 "diff: files differ" ""
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

# --- Test 9: Bash exit 137 (OOM killed) → output mentions SIGKILL ---

@test "Bash exit 137 (OOM killed): output mentions SIGKILL" {
    run_watchdog "Bash" 137 "Killed" ""
    [ "$status" -eq 0 ]
    [ -n "$output" ]
    [[ "$output" == *"SIGKILL"* ]]
}

# --- Test 10: Output JSON contains INVESTIGATE text ---

@test "warning output contains INVESTIGATE instruction" {
    run_watchdog "Bash" 126 "bash: ./script.sh: Permission denied" ""
    [ "$status" -eq 0 ]
    [ -n "$output" ]
    [[ "$output" == *"INVESTIGATE"* ]]
}

# --- Additional edge-case tests ---

@test "non-Bash tool (Edit) with errors: ignored" {
    run_watchdog "Edit" 1 "FATAL: merge conflict" ""
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "Bash exit 126 (not executable): warns" {
    run_watchdog "Bash" 126 "bash: ./script.sh: Permission denied" ""
    [ "$status" -eq 0 ]
    [ -n "$output" ]
    [[ "$output" == *"exit 126"* ]]
    [[ "$output" == *"not executable"* ]]
}

@test "Bash exit 1 with FATAL: in stderr: warns" {
    run_watchdog "Bash" 1 "FATAL: could not open config file" ""
    [ "$status" -eq 0 ]
    [ -n "$output" ]
    [[ "$output" == *"FATAL"* ]]
}

@test "Bash exit 2 with panic: in stderr: warns" {
    run_watchdog "Bash" 2 "panic: runtime error: index out of range" ""
    [ "$status" -eq 0 ]
    [ -n "$output" ]
    [[ "$output" == *"panic"* ]]
}

@test "Bash exit 1 with Cannot allocate memory: warns" {
    run_watchdog "Bash" 1 "fork: Cannot allocate memory" ""
    [ "$status" -eq 0 ]
    [ -n "$output" ]
    [[ "$output" == *"Cannot allocate memory"* ]]
}

@test "Bash exit 1 with Too many open files: warns" {
    run_watchdog "Bash" 1 "bash: /dev/null: Too many open files" ""
    [ "$status" -eq 0 ]
    [ -n "$output" ]
    [[ "$output" == *"Too many open files"* ]]
}

@test "Bash exit 1 with error pattern in stdout (not stderr): warns" {
    run_watchdog "Bash" 1 "" "ERROR: validation failed on line 42"
    [ "$status" -eq 0 ]
    [ -n "$output" ]
    [[ "$output" == *"validation failed"* ]]
}

@test "Bash exit 1 with command not found in stderr: warns" {
    run_watchdog "Bash" 1 "bash: nonexistent: command not found" ""
    [ "$status" -eq 0 ]
    [ -n "$output" ]
    [[ "$output" == *"command not found"* ]]
}

@test "output JSON has correct hookEventName" {
    run_watchdog "Bash" 127 "bash: xyz: command not found" ""
    [ "$status" -eq 0 ]
    local event_name
    event_name=$(echo "$output" | python3 -c "import sys,json; print(json.load(sys.stdin)['hookSpecificOutput']['hookEventName'])")
    [ "$event_name" = "PostToolUse" ]
}

@test "output references CLAUDE.md Error Protocol" {
    run_watchdog "Bash" 139 "Segmentation fault" ""
    [ "$status" -eq 0 ]
    [[ "$output" == *"CLAUDE.md"* ]]
    [[ "$output" == *"L-037"* ]]
}

@test "malformed JSON input: exits 0 silently" {
    run_watchdog_raw "not json at all"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "empty stdin: exits 0 silently" {
    run_watchdog_raw ""
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "Bash exit 0 with error-like stderr: silent (exit 0 always clean)" {
    run_watchdog "Bash" 0 "WARNING: something unusual
ERROR: but exit was 0" ""
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}
