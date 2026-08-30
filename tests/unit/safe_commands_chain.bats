#!/usr/bin/env bats
# T-2834 / OBS-183 — a compound command is safe only if EVERY segment is safe.
#
# Before this, is_bash_safe_command() derived the base with `awk '{print $1}'`
# and its own comment asserted "for compound commands, the first word is still
# the primary command". check-active-task.sh:95 treats a safe verdict as
# terminal and exits 0, so `echo hi && <anything>` skipped the no-active-task
# check, the task-is-active check, the G-020 readiness gate and the T-1730
# focus-drift gate. Everything after the chain operator was unexamined.
#
# Both directions are pinned here on purpose. The chained-unsafe direction is
# the bug. The chained-SAFE direction is the regression risk: `cd X && fw Y`
# and `ls && git status` are shapes agents run constantly, and a fix that
# blocks them would deny service in exactly the state (no active task) where
# the agent is trying to recover.

load ../test_helper

setup() {
    # TEST_TEMP_DIR is required even though this suite touches no files: the
    # shared teardown runs `[ -d "${TEST_TEMP_DIR:-}" ] && rm -rf …`, and an
    # unset var makes that test fail with a non-zero teardown rather than an
    # assertion — every test in the file reports red for the wrong reason.
    TEST_TEMP_DIR="$(mktemp -d)"
    export FRAMEWORK_ROOT
    source "$FRAMEWORK_ROOT/agents/context/lib/safe-commands.sh"
}

# --- the defect: unsafe segment after a safe first word ---

@test "chain: echo && git commit is NOT safe (was safe — judged by 'echo')" {
    run is_bash_safe_command "echo hi && git commit -m 'T-1: x'"
    [ "$status" -ne 0 ]
}

@test "chain: ls && fw task update is NOT safe" {
    run is_bash_safe_command "ls && bin/fw task update T-1 --status work-completed"
    [ "$status" -ne 0 ]
}

@test "chain: echo && bash script.sh is NOT safe (bash is safe only with -n)" {
    run is_bash_safe_command "echo hi && bash deploy.sh"
    [ "$status" -ne 0 ]
}

@test "chain: ls && python3 script.py is NOT safe (python3 is safe only with -c)" {
    run is_bash_safe_command "ls && python3 mutate.py"
    [ "$status" -ne 0 ]
}

@test "chain: semicolon separator is honoured, not just &&" {
    run is_bash_safe_command "ls; git commit -m 'T-1: x'"
    [ "$status" -ne 0 ]
}

@test "chain: || separator is honoured" {
    run is_bash_safe_command "ls || git commit -m 'T-1: x'"
    [ "$status" -ne 0 ]
}

@test "chain: unsafe segment in the MIDDLE is caught" {
    run is_bash_safe_command "ls && git commit -m 'T-1: x' && git status"
    [ "$status" -ne 0 ]
}

# --- the regression risk: all-safe chains must stay safe ---

@test "chain: cd X && fw doctor stays safe (the ubiquitous shape)" {
    run is_bash_safe_command "cd /opt/999-Agentic-Engineering-Framework && bin/fw doctor"
    [ "$status" -eq 0 ]
}

@test "chain: ls && git status stays safe" {
    run is_bash_safe_command "ls && git status"
    [ "$status" -eq 0 ]
}

@test "chain: three safe segments stay safe" {
    run is_bash_safe_command "cd /tmp && ls -la && git status"
    [ "$status" -eq 0 ]
}

@test "chain: pipe between safe commands stays safe" {
    run is_bash_safe_command "cat file.txt | grep pattern"
    [ "$status" -eq 0 ]
}

# --- quote awareness: a chain operator inside a quoted argument is DATA ---
#
# Without quote tracking the splitter cuts `grep -q "a && b"` into `grep -q "a`
# and `b"`, the second of which matches nothing on the allowlist — turning a
# read-only command into a blocked one.

@test "quotes: && inside a double-quoted argument does not split" {
    run is_bash_safe_command "grep -q \"foo && bar\" file.txt"
    [ "$status" -eq 0 ]
}

@test "quotes: semicolon inside a single-quoted argument does not split" {
    run is_bash_safe_command "grep -q 'foo; bar' file.txt"
    [ "$status" -eq 0 ]
}

@test "quotes: pipe inside a quoted argument does not split" {
    run is_bash_safe_command "grep -E 'foo|bar' file.txt"
    [ "$status" -eq 0 ]
}

# --- single commands are unchanged ---

@test "single: bare safe command still safe" {
    run is_bash_safe_command "git status"
    [ "$status" -eq 0 ]
}

@test "single: bare unsafe command still unsafe" {
    run is_bash_safe_command "git commit -m 'T-1: x'"
    [ "$status" -ne 0 ]
}

@test "single: T-1908 env-var prefix stripping still works" {
    run is_bash_safe_command "FW_SWITCH_FOCUS=1 bin/fw work-on T-1"
    [ "$status" -eq 0 ]
}

@test "chain: env-var prefix is stripped per segment, not just the first" {
    run is_bash_safe_command "ls && FW_SWITCH_FOCUS=1 bin/fw work-on T-1"
    [ "$status" -eq 0 ]
}

# --- splitter unit checks ---
#
# T-3223: _fw_chain_split emits NUL-TERMINATED segments, so these translate to
# newlines before counting. A quoted argument may contain a newline; a newline
# delimiter therefore cannot mark a segment boundary, and the readers all use
# `read -d ''`.

@test "splitter: counts segments of a simple chain" {
    run bash -c 'source "$FRAMEWORK_ROOT/agents/context/lib/safe-commands.sh"; _fw_chain_split "$1" | tr "\0" "\n"' _ "ls && git status"
    [ "$status" -eq 0 ]
    [ "$(echo "$output" | grep -c .)" -eq 2 ]
}

@test "splitter: does not split on a quoted operator" {
    run bash -c 'source "$FRAMEWORK_ROOT/agents/context/lib/safe-commands.sh"; _fw_chain_split "$1" | tr "\0" "\n"' _ "grep -q 'a && b' f"
    [ "$status" -eq 0 ]
    [ "$(echo "$output" | grep -c .)" -eq 1 ]
}

@test "splitter: a single command yields exactly one segment" {
    run bash -c 'source "$FRAMEWORK_ROOT/agents/context/lib/safe-commands.sh"; _fw_chain_split "$1" | tr "\0" "\n"' _ "git status"
    [ "$status" -eq 0 ]
    [ "$(echo "$output" | grep -c .)" -eq 1 ]
}
