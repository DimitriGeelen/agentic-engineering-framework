#!/usr/bin/env bats
# Unit tests for agents/context/lib/safe-commands.sh
#
# Tests is_bash_safe_command() and has_bash_write_pattern():
#   - Git read-only commands allowed
#   - File reading commands allowed
#   - FW diagnostic commands allowed
#   - Write operations blocked
#   - Write pattern detection

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export FRAMEWORK_ROOT
    source "$FRAMEWORK_ROOT/agents/context/lib/safe-commands.sh"
}

# --- is_bash_safe_command: git read-only ---

@test "safe-commands: git status is safe" {
    run is_bash_safe_command "git status"
    [ "$status" -eq 0 ]
}

@test "safe-commands: git log is safe" {
    run is_bash_safe_command "git log --oneline -5"
    [ "$status" -eq 0 ]
}

@test "safe-commands: git diff is safe" {
    run is_bash_safe_command "git diff HEAD"
    [ "$status" -eq 0 ]
}

@test "safe-commands: git push is NOT safe" {
    run is_bash_safe_command "git push origin main"
    [ "$status" -eq 1 ]
}

# git commit is intentionally NOT in the context-free allowlist: it must reach
# the focus-drift gate (T-1730) when a focus exists. Its post-completion
# (null-focus) allow is handled in check-active-task.sh (T-2054) — pinned by
# tests/unit/test_safe_commands_git_commit.bats. git add IS allowlisted (T-2054,
# task-agnostic staging).
@test "safe-commands: git commit is NOT safe (context-free; gate-handled)" {
    run is_bash_safe_command "git commit -m 'test'"
    [ "$status" -eq 1 ]
}

@test "safe-commands: git add is safe (T-2054)" {
    run is_bash_safe_command "git add -- file.txt"
    [ "$status" -eq 0 ]
}

# --- is_bash_safe_command: file reading ---

@test "safe-commands: cat is safe" {
    run is_bash_safe_command "cat file.txt"
    [ "$status" -eq 0 ]
}

@test "safe-commands: ls is safe" {
    run is_bash_safe_command "ls -la /tmp"
    [ "$status" -eq 0 ]
}

@test "safe-commands: head is safe" {
    run is_bash_safe_command "head -20 file.txt"
    [ "$status" -eq 0 ]
}

# --- is_bash_safe_command: searching ---

@test "safe-commands: grep is safe" {
    run is_bash_safe_command "grep -r 'pattern' src/"
    [ "$status" -eq 0 ]
}

@test "safe-commands: find is safe" {
    run is_bash_safe_command "find . -name '*.sh'"
    [ "$status" -eq 0 ]
}

# --- is_bash_safe_command: fw diagnostics ---

@test "safe-commands: fw doctor is safe" {
    run is_bash_safe_command "fw doctor"
    [ "$status" -eq 0 ]
}

@test "safe-commands: fw audit is safe" {
    run is_bash_safe_command "fw audit"
    [ "$status" -eq 0 ]
}

@test "safe-commands: fw work-on is safe" {
    run is_bash_safe_command "fw work-on 'new task' --type build"
    [ "$status" -eq 0 ]
}

@test "safe-commands: bin/fw version is safe" {
    run is_bash_safe_command "bin/fw version"
    [ "$status" -eq 0 ]
}

@test "safe-commands: fw context status is safe" {
    run is_bash_safe_command "fw context status"
    [ "$status" -eq 0 ]
}

@test "safe-commands: fw task list is safe" {
    run is_bash_safe_command "fw task list"
    [ "$status" -eq 0 ]
}

@test "safe-commands: fw hook subcommand is safe" {
    run is_bash_safe_command "fw hook pre-compact"
    [ "$status" -eq 0 ]
}

# --- is_bash_safe_command: system utilities ---

@test "safe-commands: curl is safe" {
    run is_bash_safe_command "curl -sf http://localhost:3000/"
    [ "$status" -eq 0 ]
}

@test "safe-commands: date is safe" {
    run is_bash_safe_command "date -u +%Y-%m-%d"
    [ "$status" -eq 0 ]
}

@test "safe-commands: echo without redirect is safe" {
    run is_bash_safe_command "echo hello world"
    [ "$status" -eq 0 ]
}

# --- is_bash_safe_command: blocked ---

@test "safe-commands: rm is NOT safe" {
    run is_bash_safe_command "rm -rf /tmp/test"
    [ "$status" -eq 1 ]
}

@test "safe-commands: mkdir is NOT safe" {
    run is_bash_safe_command "mkdir -p /tmp/newdir"
    [ "$status" -eq 1 ]
}

@test "safe-commands: python3 with file write is NOT safe" {
    run is_bash_safe_command "python3 -c \"open('file', 'w').write('data')\""
    [ "$status" -eq 1 ]
}

@test "safe-commands: python3 parse check is safe" {
    run is_bash_safe_command "python3 -c \"import yaml; yaml.safe_load(open('f'))\""
    [ "$status" -eq 0 ]
}

@test "safe-commands: npm list is safe" {
    run is_bash_safe_command "npm list"
    [ "$status" -eq 0 ]
}

@test "safe-commands: npm install is NOT safe" {
    run is_bash_safe_command "npm install express"
    [ "$status" -eq 1 ]
}

@test "safe-commands: cd is safe" {
    run is_bash_safe_command "cd /opt/project"
    [ "$status" -eq 0 ]
}

# --- has_bash_write_pattern ---

@test "write-pattern: redirect detected" {
    run has_bash_write_pattern "echo test > file.txt"
    [ "$status" -eq 0 ]
}

@test "write-pattern: append detected" {
    run has_bash_write_pattern "echo test >> file.txt"
    [ "$status" -eq 0 ]
}

@test "write-pattern: sed -i detected" {
    run has_bash_write_pattern "sed -i 's/old/new/' file.txt"
    [ "$status" -eq 0 ]
}

@test "write-pattern: rm detected" {
    run has_bash_write_pattern "rm -rf /tmp/test"
    [ "$status" -eq 0 ]
}

@test "write-pattern: tee detected" {
    run has_bash_write_pattern "echo test | tee file.txt"
    [ "$status" -eq 0 ]
}

@test "write-pattern: heredoc detected" {
    run has_bash_write_pattern "cat <<EOF > file.txt"
    [ "$status" -eq 0 ]
}

@test "write-pattern: read-only has no write pattern" {
    run has_bash_write_pattern "git status"
    [ "$status" -eq 1 ]
}

@test "write-pattern: grep has no write pattern" {
    run has_bash_write_pattern "grep -r pattern src/"
    [ "$status" -eq 1 ]
}
