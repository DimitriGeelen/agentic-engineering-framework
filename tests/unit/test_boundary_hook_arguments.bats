#!/usr/bin/env bats
# T-1702 / G-065 — Pattern 4 (read-side outside-path arguments).
#
# Origin: 2026-05-03 housekeeping. The cd-pattern blocked
# `cd /root/.agentic-framework`; the agent then ran `du`/`find`/`grep`
# against the same absolute path and the hook stayed silent. Read-side
# cross-boundary access had been undetected for as long as the hook
# existed (T-559).
#
# These tests pin Pattern 4 behaviour: outside-path arguments to ANY
# command are blocked unless the path falls under the read-side
# allowlist (system paths, /tmp, project root).

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    HOOK="$FRAMEWORK_ROOT/agents/context/check-project-boundary.sh"
    [ -x "$HOOK" ]
    export PROJECT_ROOT="$FRAMEWORK_ROOT"
}

run_hook() {
    local command="$1"
    local payload
    payload=$(python3 -c "
import json, sys
print(json.dumps({'tool_name': 'Bash', 'tool_input': {'command': sys.argv[1]}}))
" "$command")
    echo "$payload" | bash "$HOOK"
}

# ── Pattern 4 TPs (originally undetected) ──

@test "Pattern 4: du on outside path blocked" {
    run run_hook "du -sh /root/.agentic-framework"
    [ "$status" -eq 2 ]
    echo "$output" | grep -q "Outside-path argument"
}

@test "Pattern 4: find on outside path blocked" {
    run run_hook "find /root/.agentic-framework -name '*.sh'"
    [ "$status" -eq 2 ]
}

@test "Pattern 4: grep -r on outside path blocked" {
    run run_hook "grep -r foo /root/.agentic-framework"
    [ "$status" -eq 2 ]
}

@test "Pattern 4: cat from outside project blocked" {
    run run_hook "cat /opt/other-project/README.md"
    [ "$status" -eq 2 ]
}

@test "Pattern 4: ls on outside path blocked" {
    run run_hook "ls /opt/other-project"
    [ "$status" -eq 2 ]
}

@test "Pattern 4: cp from outside path blocked" {
    run run_hook "cp /root/.agentic-framework/x.txt /tmp/x.txt"
    [ "$status" -eq 2 ]
}

# ── Read-side allowlist ──

@test "allowlist: /tmp passes" {
    run run_hook "ls /tmp"
    [ "$status" -eq 0 ]
}

@test "allowlist: /etc/hosts passes" {
    run run_hook "cat /etc/hosts"
    [ "$status" -eq 0 ]
}

@test "allowlist: /usr/bin passes" {
    run run_hook "ls /usr/bin"
    [ "$status" -eq 0 ]
}

@test "allowlist: /var/log passes" {
    run run_hook "tail /var/log/syslog"
    [ "$status" -eq 0 ]
}

@test "allowlist: /var/cache passes" {
    run run_hook "ls /var/cache/apt/archives"
    [ "$status" -eq 0 ]
}

@test "allowlist: /proc/cpuinfo passes" {
    run run_hook "cat /proc/cpuinfo"
    [ "$status" -eq 0 ]
}

@test "allowlist: /sys passes" {
    run run_hook "ls /sys/class"
    [ "$status" -eq 0 ]
}

@test "allowlist: /root/.local passes (user shim install dir)" {
    run run_hook "ls /root/.local/bin"
    [ "$status" -eq 0 ]
}

@test "allowlist: /root/.claude passes (Claude Code state)" {
    run run_hook "ls /root/.claude"
    [ "$status" -eq 0 ]
}

@test "allowlist: PROJECT_ROOT passes" {
    run run_hook "cat $FRAMEWORK_ROOT/README.md"
    [ "$status" -eq 0 ]
}

# ── Multi-arg + edge cases ──

@test "multi-arg: cp two paths inside PROJECT_ROOT" {
    run run_hook "cp $FRAMEWORK_ROOT/a.txt $FRAMEWORK_ROOT/b.txt"
    [ "$status" -eq 0 ]
}

@test "multi-arg: rsync project + system both allowlisted" {
    run run_hook "rsync -a /tmp/staging/ $FRAMEWORK_ROOT/dest/"
    [ "$status" -eq 0 ]
}

# ── False-positive controls ──

@test "FP: quoted path in echo passes" {
    run run_hook 'echo "see /root/.agentic-framework"'
    [ "$status" -eq 0 ]
}

@test "FP: heredoc body with outside path passes" {
    run run_hook "$(printf 'cat > /tmp/x.txt <<EOF\n/opt/other-project content\nEOF')"
    [ "$status" -eq 0 ]
}

@test "FP: regex /pattern/ in sed passes" {
    run run_hook 'sed "s/foo/bar/g" file'
    [ "$status" -eq 0 ]
}

@test "FP: bare echo with /no-such-prefix passes" {
    run run_hook "echo /no-such-prefix"
    [ "$status" -eq 0 ]
}

# ── No-regression on existing patterns ──

@test "no-regression: cd /tmp passes" {
    run run_hook "cd /tmp && ls"
    [ "$status" -eq 0 ]
}

@test "no-regression: cd to outside still blocked" {
    run run_hook "cd /opt/other-project"
    [ "$status" -eq 2 ]
}

@test "no-regression: termlink dispatch passes" {
    run run_hook 'termlink interact session "cd /opt/other && ls"'
    [ "$status" -eq 0 ]
}

@test "no-regression: bin/fw doctor passes" {
    run run_hook "bin/fw doctor"
    [ "$status" -eq 0 ]
}

@test "no-regression: relative paths pass" {
    run run_hook "cat src/foo.py"
    [ "$status" -eq 0 ]
}

@test "no-regression: command with no absolute path passes" {
    run run_hook "echo hello world"
    [ "$status" -eq 0 ]
}
