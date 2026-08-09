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

# T-2462: git push/fetch ARE safe — task-agnostic publication of commits that
# already passed the commit-msg T-XXX gate; they create no work artifact and
# mutate no working tree. Force-push protection is unaffected (separate Tier-0
# hook). git pull stays UNSAFE (it merges into the working tree = a write).
@test "safe-commands: git push is safe (T-2462)" {
    run is_bash_safe_command "git push origin main"
    [ "$status" -eq 0 ]
}

@test "safe-commands: git fetch is safe (T-2462)" {
    run is_bash_safe_command "git fetch --all"
    [ "$status" -eq 0 ]
}

@test "safe-commands: git pull is NOT safe (T-2462 — merges into tree)" {
    run is_bash_safe_command "git pull origin main"
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

# --- T-2887: the echo/printf branch must not re-derive the redirect test ------
#
# It used to carry its own copy of the regex. has_bash_write_pattern's copy grew
# the `2`/`&` exemptions that separate a file write from an fd redirect; the copy
# did not, so the two disagreed on exactly `2>&1` and `2>/dev/null`. Reported by
# 832 (rail 489) against their tree; L-518 says sweep ours, and ours had it.

@test "safe-commands: echo with 2>&1 is safe (T-2887)" {
    run is_bash_safe_command "echo hi 2>&1"
    [ "$status" -eq 0 ]
}

@test "safe-commands: echo with 2>/dev/null is safe (T-2887)" {
    run is_bash_safe_command "echo hi 2>/dev/null"
    [ "$status" -eq 0 ]
}

@test "safe-commands: printf with 2>&1 is safe (T-2887)" {
    run is_bash_safe_command "printf x 2>&1"
    [ "$status" -eq 0 ]
}

# Paired negatives. Without these, "stop blocking echo" is satisfiable by
# deleting the check outright — and the failure direction of THAT mistake is the
# dangerous one (:82 — misjudging unsafe as safe skips every gate there is).

@test "safe-commands: echo with a real redirect still gates (T-2887)" {
    run is_bash_safe_command "echo hi > f.txt"
    [ "$status" -eq 1 ]
}

@test "safe-commands: echo with an append redirect still gates (T-2887)" {
    run is_bash_safe_command "echo hi >> f.txt"
    [ "$status" -eq 1 ]
}

# The anti-divergence tooth. The three above pin the SYMPTOM; this pins the
# CAUSE. Re-introducing a second private copy of the redirect test passes every
# case above as long as the new copy happens to be correct today — and that is
# exactly how this defect arrived, since the copy WAS correct when it was made
# and only became wrong when its sibling was fixed without it (L-399).
@test "safe-commands: echo branch and write-pattern agree on every redirect shape (T-2887)" {
    local c
    for c in "echo hi" "echo hi 2>&1" "echo hi 2>/dev/null" "echo hi > f" \
             "echo hi >> f" "echo hi 1>&2" "printf x 2>&1" "printf x > f"; do
        if has_bash_write_pattern "$c"; then want=1; else want=0; fi
        if is_bash_safe_command "$c"; then got=0; else got=1; fi
        [ "$got" -eq "$want" ] || {
            echo "disagreement on: $c (write-pattern says $want, safe-list says $got)"
            false
        }
    done
}
