#!/usr/bin/env bats
# Integration tests for agents/context/check-tier0.sh
#
# Tests the Tier 0 PreToolUse hook that blocks destructive Bash commands
# unless explicitly approved via a time-limited approval token.
#
# Exit codes: 0 = allow, 2 = block

load ../test_helper

TIER0_SCRIPT="$FRAMEWORK_ROOT/agents/context/check-tier0.sh"

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    mkdir -p "$PROJECT_ROOT/.context/working"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# Helper: build JSON input, write to temp file, run script with stdin redirect.
# bats `run` does not work inside a pipeline, so we use file-based stdin.
run_tier0() {
    local cmd="$1"
    local json_file="$TEST_TEMP_DIR/_tier0_input.json"
    printf '{"tool_name": "Bash", "tool_input": {"command": "%s"}}' "$cmd" > "$json_file"
    run bash -c "PROJECT_ROOT='$PROJECT_ROOT' '$TIER0_SCRIPT' < '$json_file'"
}

# Helper: for commands with special characters (quotes, wildcards), use python
# to build properly escaped JSON.
run_tier0_raw() {
    local cmd="$1"
    local json_file="$TEST_TEMP_DIR/_tier0_input.json"
    python3 -c "
import json, sys
print(json.dumps({'tool_name': 'Bash', 'tool_input': {'command': sys.argv[1]}}))
" "$cmd" > "$json_file"
    run bash -c "PROJECT_ROOT='$PROJECT_ROOT' '$TIER0_SCRIPT' < '$json_file'"
}

# ── Safe commands (exit 0) ──

@test "safe: git status is allowed" {
    run_tier0 "git status"
    [ "$status" -eq 0 ]
}

@test "safe: ls -la is allowed" {
    run_tier0 "ls -la"
    [ "$status" -eq 0 ]
}

@test "safe: git push origin main (no --force) is allowed" {
    run_tier0 "git push origin main"
    [ "$status" -eq 0 ]
}

@test "safe: rm file.txt (no recursive flag) is allowed" {
    run_tier0 "rm file.txt"
    [ "$status" -eq 0 ]
}

@test "safe: echo with quoted destructive text is allowed" {
    run_tier0_raw 'echo "git push --force"'
    [ "$status" -eq 0 ]
}

@test "safe: git branch -d (lowercase, not force delete) is allowed" {
    run_tier0 "git branch -d feature-branch"
    [ "$status" -eq 0 ]
}

@test "safe: empty command is allowed" {
    local json_file="$TEST_TEMP_DIR/_tier0_input.json"
    printf '{"tool_name": "Bash", "tool_input": {"command": ""}}' > "$json_file"
    run bash -c "PROJECT_ROOT='$PROJECT_ROOT' '$TIER0_SCRIPT' < '$json_file'"
    [ "$status" -eq 0 ]
}

@test "safe: malformed JSON is allowed (defensive pass-through)" {
    local json_file="$TEST_TEMP_DIR/_tier0_input.json"
    printf 'not valid json at all' > "$json_file"
    run bash -c "PROJECT_ROOT='$PROJECT_ROOT' '$TIER0_SCRIPT' < '$json_file'"
    [ "$status" -eq 0 ]
}

# ── Destructive commands (exit 2) ──

@test "blocked: git push --force origin main" {
    run_tier0 "git push --force origin main"
    [ "$status" -eq 2 ]
}

@test "blocked: git push -f origin main" {
    run_tier0 "git push -f origin main"
    [ "$status" -eq 2 ]
}

@test "blocked: git reset --hard" {
    run_tier0 "git reset --hard"
    [ "$status" -eq 2 ]
}

@test "blocked: git reset --hard HEAD~3" {
    run_tier0 "git reset --hard HEAD~3"
    [ "$status" -eq 2 ]
}

@test "blocked: git clean -fd" {
    run_tier0 "git clean -fd"
    [ "$status" -eq 2 ]
}

@test "blocked: git clean -f" {
    run_tier0 "git clean -f"
    [ "$status" -eq 2 ]
}

@test "blocked: rm -rf /" {
    run_tier0 "rm -rf /"
    [ "$status" -eq 2 ]
}

@test "blocked: rm -rf ." {
    run_tier0 "rm -rf ."
    [ "$status" -eq 2 ]
}

@test "blocked: rm -rf *" {
    run_tier0_raw "rm -rf *"
    [ "$status" -eq 2 ]
}

@test "blocked: DROP TABLE users" {
    run_tier0 "DROP TABLE users"
    [ "$status" -eq 2 ]
}

@test "blocked: TRUNCATE TABLE users" {
    run_tier0 "TRUNCATE TABLE users"
    [ "$status" -eq 2 ]
}

@test "blocked: docker system prune" {
    run_tier0 "docker system prune"
    [ "$status" -eq 2 ]
}

@test "blocked: kubectl delete namespace production" {
    run_tier0 "kubectl delete namespace production"
    [ "$status" -eq 2 ]
}

@test "blocked: git branch -D feature" {
    run_tier0 "git branch -D feature"
    [ "$status" -eq 2 ]
}

@test "blocked: git checkout ." {
    run_tier0 "git checkout ."
    [ "$status" -eq 2 ]
}

@test "blocked: git restore ." {
    run_tier0 "git restore ."
    [ "$status" -eq 2 ]
}

# ── Block output contains TIER 0 BLOCK ──

@test "block output: stderr contains TIER 0 BLOCK" {
    run_tier0 "git push --force origin main"
    [ "$status" -eq 2 ]
    [[ "$output" == *"TIER 0 BLOCK"* ]]
}

@test "block output: stderr contains risk description" {
    run_tier0 "git push --force origin main"
    [ "$status" -eq 2 ]
    [[ "$output" == *"FORCE PUSH"* ]]
}

@test "block output: stderr contains the command" {
    run_tier0 "git push --force origin main"
    [ "$status" -eq 2 ]
    [[ "$output" == *"git push --force origin main"* ]]
}

# ── Approval mechanism ──

@test "approval: valid approval token allows blocked command" {
    local cmd="git push --force origin main"
    local cmd_hash
    cmd_hash=$(printf '%s' "$cmd" | sha256sum | awk '{print $1}')
    local now
    now=$(date +%s)

    echo "$cmd_hash $now APPROVED" > "$PROJECT_ROOT/.context/working/.tier0-approval"

    run_tier0 "$cmd"
    [ "$status" -eq 0 ]
}

@test "approval: expired token (>300s) still blocks" {
    local cmd="git push --force origin main"
    local cmd_hash
    cmd_hash=$(printf '%s' "$cmd" | sha256sum | awk '{print $1}')
    local old_time
    old_time=$(( $(date +%s) - 400 ))

    echo "$cmd_hash $old_time APPROVED" > "$PROJECT_ROOT/.context/working/.tier0-approval"

    run_tier0 "$cmd"
    [ "$status" -eq 2 ]
}

@test "approval: mismatched hash still blocks" {
    local cmd="git push --force origin main"
    local wrong_hash="0000000000000000000000000000000000000000000000000000000000000000"
    local now
    now=$(date +%s)

    echo "$wrong_hash $now APPROVED" > "$PROJECT_ROOT/.context/working/.tier0-approval"

    run_tier0 "$cmd"
    [ "$status" -eq 2 ]
}

@test "approval: token is consumed after use" {
    local cmd="git push --force origin main"
    local cmd_hash
    cmd_hash=$(printf '%s' "$cmd" | sha256sum | awk '{print $1}')
    local now
    now=$(date +%s)

    echo "$cmd_hash $now APPROVED" > "$PROJECT_ROOT/.context/working/.tier0-approval"

    run_tier0 "$cmd"
    [ "$status" -eq 0 ]

    # Token file should be removed after consumption
    [ ! -f "$PROJECT_ROOT/.context/working/.tier0-approval" ]
}

# ── Pending file creation on block ──

@test "block creates pending approval file" {
    run_tier0 "git reset --hard"
    [ "$status" -eq 2 ]
    [ -f "$PROJECT_ROOT/.context/working/.tier0-approval.pending" ]
}

# ── Case sensitivity ──

@test "blocked: drop table (lowercase) is detected" {
    run_tier0 "drop table sessions"
    [ "$status" -eq 2 ]
}

@test "blocked: git push --force-with-lease" {
    run_tier0 "git push --force-with-lease origin main"
    [ "$status" -eq 2 ]
}
