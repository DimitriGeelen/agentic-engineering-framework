#!/usr/bin/env bats
# Integration tests for agents/context/budget-gate.sh
#
# PreToolUse hook that enforces context budget limits.
# Exit codes:
#   0 — Allow tool execution
#   2 — Block tool execution (critical budget)
#
# The hook uses a two-tier approach:
#   Fast path: read .budget-status cache file (<90s old)
#   Slow path: parse JSONL transcript (every 5th call or stale cache)

load ../test_helper

HOOK="$FRAMEWORK_ROOT/agents/context/budget-gate.sh"

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    export TASKS_DIR="$PROJECT_ROOT/.tasks"
    export CONTEXT_DIR="$PROJECT_ROOT/.context"
    mkdir -p "$PROJECT_ROOT/.context/working" "$PROJECT_ROOT/.tasks/active"
    # Ensure HOME/.claude/projects/ exists for transcript lookup
    export HOME="$TEST_TEMP_DIR/home"
    mkdir -p "$HOME"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# Helper: write a .budget-status file with given level and tokens
write_status() {
    local level="$1"
    local tokens="${2:-100000}"
    local age="${3:-0}"
    local timestamp=$(($(date +%s) - age))
    cat > "$PROJECT_ROOT/.context/working/.budget-status" <<EOF
{"level": "$level", "tokens": $tokens, "timestamp": $timestamp, "source": "test"}
EOF
}

# Helper: run the hook with a given tool_name and optional command/file_path
run_gate() {
    local tool_name="${1:-Write}"
    local extra_input="${2:-}"
    local json
    if [ -n "$extra_input" ]; then
        json="{\"tool_name\": \"$tool_name\", \"tool_input\": {$extra_input}}"
    else
        json="{\"tool_name\": \"$tool_name\", \"tool_input\": {}}"
    fi
    run bash -c "echo '$json' | PROJECT_ROOT='$PROJECT_ROOT' CONTEXT_DIR='$PROJECT_ROOT/.context' HOME='$HOME' '$HOOK'"
}

# --- Fast path: cached status ---

@test "fast path ok: fresh ok status allows with exit 0" {
    write_status "ok" 50000
    run_gate "Write"
    [ "$status" -eq 0 ]
}

@test "fast path warn: fresh warn status allows with note" {
    write_status "warn" 125000
    run_gate "Write"
    [ "$status" -eq 0 ]
    [[ "$output" == *"125000"* ]]
}

@test "fast path urgent: fresh urgent status allows with warning" {
    write_status "urgent" 155000
    run_gate "Write"
    [ "$status" -eq 0 ]
    [[ "$output" == *"WARNING"* ]]
    [[ "$output" == *"handover"* ]]
}

@test "fast path critical: blocks Write to source files with exit 2" {
    write_status "critical" 175000
    run_gate "Write" "\"file_path\": \"/some/project/src/main.py\""
    [ "$status" -eq 2 ]
    [[ "$output" == *"SESSION WRAPPING UP"* ]]
}

@test "fast path critical: allows Read tool" {
    write_status "critical" 175000
    run_gate "Read"
    [ "$status" -eq 0 ]
}

@test "fast path critical: allows Glob tool" {
    write_status "critical" 175000
    run_gate "Glob"
    [ "$status" -eq 0 ]
}

@test "fast path critical: allows Grep tool" {
    write_status "critical" 175000
    run_gate "Grep"
    [ "$status" -eq 0 ]
}

@test "fast path critical: allows git commit via Bash" {
    write_status "critical" 175000
    run_gate "Bash" "\"command\": \"git commit -m 'T-001: fix'\""
    [ "$status" -eq 0 ]
}

@test "fast path critical: allows fw handover via Bash" {
    write_status "critical" 175000
    run_gate "Bash" "\"command\": \"fw handover --commit\""
    [ "$status" -eq 0 ]
}

@test "fast path critical: allows Write to .context/ (wrap-up path)" {
    write_status "critical" 175000
    run_gate "Write" "\"file_path\": \"/project/.context/handovers/session.md\""
    [ "$status" -eq 0 ]
}

@test "fast path critical: allows Write to .tasks/ (wrap-up path)" {
    write_status "critical" 175000
    run_gate "Write" "\"file_path\": \"/project/.tasks/active/T-001.md\""
    [ "$status" -eq 0 ]
}

@test "fast path critical: blocks Bash with non-exempt command" {
    write_status "critical" 175000
    run_gate "Bash" "\"command\": \"python3 build.py\""
    [ "$status" -eq 2 ]
}

# --- Stale cache falls through to slow path ---

@test "stale status: old cache (>90s) falls through" {
    # Write a status file aged 200 seconds — should be considered stale
    write_status "ok" 50000 200
    # No transcript to find — slow path will find nothing and allow
    run_gate "Write"
    [ "$status" -eq 0 ]
}

# --- No status file ---

@test "no status file: no transcript found allows with exit 0" {
    # No .budget-status, no transcript — fails open
    run_gate "Write"
    [ "$status" -eq 0 ]
}

# --- Output format ---

@test "critical block output: mentions ALLOWED actions" {
    write_status "critical" 175000
    run_gate "Write" "\"file_path\": \"/src/main.py\""
    [[ "$output" == *"ALLOWED"* ]]
    [[ "$output" == *"git commit"* ]]
    [[ "$output" == *"fw handover"* ]]
}

@test "critical block output: mentions BLOCKED actions" {
    write_status "critical" 175000
    run_gate "Write" "\"file_path\": \"/src/main.py\""
    [[ "$output" == *"BLOCKED"* ]]
    [[ "$output" == *"source files"* ]]
}
