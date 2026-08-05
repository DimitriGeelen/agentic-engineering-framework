#!/usr/bin/env bats
# Integration tests for agents/context/check-project-boundary.sh
#
# This script is a PreToolUse hook that blocks Write/Edit/Bash operations
# targeting paths outside PROJECT_ROOT. Prevents cross-project edits.
#
# Exit codes:
#   0 — Allow tool execution
#   2 — Block tool execution

load ../test_helper

HOOK="$FRAMEWORK_ROOT/agents/context/check-project-boundary.sh"

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    guard_project_root
    unset _FW_PATHS_LOADED
    mkdir -p "$PROJECT_ROOT/.context/working" "$PROJECT_ROOT/.tasks/active"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# Helper: invoke hook with Write tool
run_write_hook() {
    local file_path="$1"
    local json="{\"tool_name\": \"Write\", \"tool_input\": {\"file_path\": \"$file_path\"}}"
    run bash -c "echo '$json' | PROJECT_ROOT='$PROJECT_ROOT' '$HOOK'"
}

# Helper: invoke hook with Edit tool
run_edit_hook() {
    local file_path="$1"
    local json="{\"tool_name\": \"Edit\", \"tool_input\": {\"file_path\": \"$file_path\"}}"
    run bash -c "echo '$json' | PROJECT_ROOT='$PROJECT_ROOT' '$HOOK'"
}

# Helper: invoke hook with Bash tool
run_bash_hook() {
    local command="$1"
    local json="{\"tool_name\": \"Bash\", \"tool_input\": {\"command\": \"$command\"}}"
    run bash -c "echo '$json' | PROJECT_ROOT='$PROJECT_ROOT' '$HOOK'"
}

# Helper: invoke hook with a non-file tool
run_other_hook() {
    local tool_name="$1"
    local json="{\"tool_name\": \"$tool_name\", \"tool_input\": {}}"
    run bash -c "echo '$json' | PROJECT_ROOT='$PROJECT_ROOT' '$HOOK'"
}

# ── Write/Edit: allowed paths ──

@test "Write inside PROJECT_ROOT: allowed" {
    run_write_hook "$PROJECT_ROOT/src/main.py"
    [ "$status" -eq 0 ]
}

@test "Edit inside PROJECT_ROOT: allowed" {
    run_edit_hook "$PROJECT_ROOT/lib/utils.sh"
    [ "$status" -eq 0 ]
}

@test "Write to /tmp: allowed" {
    run_write_hook "/tmp/fw-agent-explore.md"
    [ "$status" -eq 0 ]
}

@test "Write to /root/.claude: allowed" {
    run_write_hook "/root/.claude/memory/note.md"
    [ "$status" -eq 0 ]
}

# ── Write/Edit: blocked paths ──

@test "Write to another project: blocked" {
    run_write_hook "/opt/other-project/file.py"
    [ "$status" -eq 2 ]
    [[ "$output" == *"PROJECT BOUNDARY BLOCK"* ]]
}

@test "Edit to /home/user/file: blocked" {
    run_edit_hook "/home/user/important.txt"
    [ "$status" -eq 2 ]
    [[ "$output" == *"PROJECT BOUNDARY BLOCK"* ]]
}

@test "Write to /etc/cron.d: blocked" {
    run_write_hook "/etc/cron.d/my-cron"
    [ "$status" -eq 2 ]
}

# ── Write/Edit: edge cases ──

@test "Write with empty file_path: allowed (defensive)" {
    local json='{"tool_name": "Write", "tool_input": {"file_path": ""}}'
    run bash -c "echo '$json' | PROJECT_ROOT='$PROJECT_ROOT' '$HOOK'"
    [ "$status" -eq 0 ]
}

@test "Write with no file_path key: allowed (defensive)" {
    local json='{"tool_name": "Write", "tool_input": {}}'
    run bash -c "echo '$json' | PROJECT_ROOT='$PROJECT_ROOT' '$HOOK'"
    [ "$status" -eq 0 ]
}

# ── Bash: allowed commands ──

@test "Bash with relative path: allowed" {
    run_bash_hook "ls -la src/"
    [ "$status" -eq 0 ]
}

@test "Bash cd to PROJECT_ROOT: allowed" {
    run_bash_hook "cd $PROJECT_ROOT && ls"
    [ "$status" -eq 0 ]
}

@test "Bash cd to /tmp: allowed" {
    run_bash_hook "cd /tmp && cat file.txt"
    [ "$status" -eq 0 ]
}

@test "Bash with no absolute paths: allowed (fast path)" {
    run_bash_hook "git status && git log --oneline -5"
    [ "$status" -eq 0 ]
}

@test "Bash redirect to PROJECT_ROOT file: allowed" {
    run_bash_hook "echo hello > $PROJECT_ROOT/output.txt"
    [ "$status" -eq 0 ]
}

# ── Bash: blocked commands ──

@test "Bash cd to another project: blocked" {
    run_bash_hook "cd /opt/other-project && make install"
    [ "$status" -eq 2 ]
    [[ "$output" == *"PROJECT BOUNDARY BLOCK"* ]]
}

@test "Bash redirect to /etc: blocked" {
    run_bash_hook "echo crontab > /etc/cron.d/my-cron"
    [ "$status" -eq 2 ]
}

@test "Bash cd to /home/user: blocked" {
    run_bash_hook "cd /home/user && rm -rf .bashrc"
    [ "$status" -eq 2 ]
}

@test "Bash fw invocation on another project: blocked" {
    run_bash_hook "/opt/other-project/.agentic-framework/bin/fw doctor"
    [ "$status" -eq 2 ]
}

# ── Non-file tools: always allowed ──

@test "Read tool: always allowed" {
    run_other_hook "Read"
    [ "$status" -eq 0 ]
}

@test "Grep tool: always allowed" {
    run_other_hook "Grep"
    [ "$status" -eq 0 ]
}

@test "Glob tool: always allowed" {
    run_other_hook "Glob"
    [ "$status" -eq 0 ]
}

# ── Malformed input ──

@test "empty stdin: allowed (defensive)" {
    run bash -c "echo '' | PROJECT_ROOT='$PROJECT_ROOT' '$HOOK'"
    [ "$status" -eq 0 ]
}

@test "malformed JSON: allowed (defensive)" {
    run bash -c "echo 'not json' | PROJECT_ROOT='$PROJECT_ROOT' '$HOOK'"
    [ "$status" -eq 0 ]
}

# ── TermLink exception (T-1075) ──

@test "Bash termlink at start: allowed" {
    run_bash_hook "termlink pty inject worker 'cd /opt/other && ls' --enter"
    [ "$status" -eq 0 ]
}

@test "Bash termlink in for loop: allowed" {
    run_bash_hook "for n in foo bar; do termlink pty inject worker \"cd /opt/\$n && ls\" --enter; done"
    [ "$status" -eq 0 ]
}

@test "Bash termlink after semicolon: allowed" {
    run_bash_hook "echo start; termlink interact worker 'cd /opt/other && git status' --json"
    [ "$status" -eq 0 ]
}

@test "Bash termlink after &&: allowed" {
    run_bash_hook "echo start && termlink pty inject worker 'cd /opt/other' --enter"
    [ "$status" -eq 0 ]
}

@test "Bash fw termlink dispatch: allowed" {
    run_bash_hook "fw termlink dispatch --name worker --prompt 'cd /opt/other && build'"
    [ "$status" -eq 0 ]
}
