#!/usr/bin/env bats
# T-3076 — the project-boundary hook's TermLink exemption is segment-scoped and
# command-position only.
#
# Before: agents/context/check-project-boundary.sh short-circuited with `exit 0`
# for the WHOLE command line whenever the regex
#   (^|\s|;|&&|\|)(termlink|bin/fw termlink|fw termlink)\s
# matched anywhere. Two over-matches followed (recorded as L-021 by T-1075 and
# left standing):
#   1. argument position counted as command position — `grep termlink /opt/x`
#   2. one exempt segment exempted every sibling — `termlink ping && cat /opt/x`
#
# After: only the segment that invokes TermLink is exempt; every other segment
# still goes through boundary analysis. The T-679 reason for the exemption
# (TermLink runs the command in a different process, so a `cd` inside its quoted
# argument is a false positive) is preserved and pinned below.
#
# Assertions are scoped to the state under test: exit code AND the specific
# blocked path in the `Reason:` line. `[[ $output == *BLOCKED* ]]` against a
# multi-line hook run would pass on almost anything.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    guard_project_root
    unset _FW_PATHS_LOADED
    mkdir -p "$PROJECT_ROOT/.context/working" "$PROJECT_ROOT/.tasks/active"
    HOOK="$FRAMEWORK_ROOT/agents/context/check-project-boundary.sh"
    [ -x "$HOOK" ]
}

teardown() {
    [ -n "${TEST_TEMP_DIR:-}" ] && [ -d "$TEST_TEMP_DIR" ] && rm -rf "$TEST_TEMP_DIR"
}

# Build the PreToolUse payload with json.dumps so arbitrary quoting, newlines
# and shell metacharacters reach the hook byte-for-byte.
run_hook() {
    local command="$1" payload
    payload=$(python3 -c "
import json, sys
print(json.dumps({'tool_name': 'Bash', 'tool_input': {'command': sys.argv[1]}}))
" "$command")
    echo "$payload" | PROJECT_ROOT="$PROJECT_ROOT" bash "$HOOK"
}

# Assert the hook blocked, and blocked on the path we meant.
assert_blocked_on() {
    local needle="$1"
    [ "$status" -eq 2 ]
    echo "$output" | grep -q "Reason:.*$needle"
}

# ── A4: positive control. The suite must show the gate is ON, not just silent. ──

@test "A4 positive control (BLOCK side): the bare violating segment blocks" {
    run run_hook "cat /opt/other-project/.env"
    assert_blocked_on "/opt/other-project/.env"
}

@test "A4 positive control (EXEMPT side): a real TermLink call is exempted" {
    # Same outside path, reached through TermLink — must be allowed, otherwise
    # every 'not exempt' assertion below would pass with the exemption removed
    # entirely, proving nothing.
    run run_hook "termlink interact session \"cd /opt/other-project && ls\""
    [ "$status" -eq 0 ]
}

# ── A1: the exemption covers the SEGMENT, not the line ──

@test "A1: exempt segment does not exempt an '&&' sibling" {
    run run_hook "termlink ping && cat /opt/other-project/.env"
    assert_blocked_on "/opt/other-project/.env"
}

@test "A1: exempt segment does not exempt a ';' sibling" {
    run run_hook "termlink ping; cat /opt/other-project/.env"
    assert_blocked_on "/opt/other-project/.env"
}

@test "A1: exempt segment does not exempt a '||' sibling" {
    run run_hook "termlink ping || cat /opt/other-project/.env"
    assert_blocked_on "/opt/other-project/.env"
}

@test "A1: exempt segment does not exempt a pipeline sibling" {
    run run_hook "termlink ping | tee /opt/other-project/out.log"
    assert_blocked_on "/opt/other-project/out.log"
}

@test "A1: exempt segment does not exempt a background '&' sibling" {
    run run_hook "termlink ping & cat /opt/other-project/.env"
    assert_blocked_on "/opt/other-project/.env"
}

@test "A1: exempt segment does not exempt a newline sibling" {
    run run_hook "$(printf 'termlink ping\ncat /opt/other-project/.env\n')"
    assert_blocked_on "/opt/other-project/.env"
}

@test "A1: exempt segment does not exempt a 'cd' sibling" {
    run run_hook "termlink ping && cd /opt/other-project"
    assert_blocked_on "cd /opt/other-project"
}

@test "A1: the exempt segment itself is still not analysed (no false block)" {
    # The violating sibling is what blocks; if the exempt segment were also
    # analysed the reason would name /opt/other-project/deep instead.
    run run_hook "termlink pty inject w \"cd /opt/other-project/deep\" && cat /opt/other-project/.env"
    assert_blocked_on "/opt/other-project/.env"
}

# ── A2: command position only ──

@test "A2: 'termlink' in argument position is NOT exempt" {
    run run_hook "grep termlink /opt/other-project/config"
    assert_blocked_on "/opt/other-project/config"
}

@test "A2: 'echo termlink' does not exempt the rest of the line" {
    run run_hook "echo termlink; cat /opt/other-project/.env"
    assert_blocked_on "/opt/other-project/.env"
}

@test "A2: 'termlink' as a here-word argument is NOT exempt" {
    run run_hook "ls -la /opt/other-project/termlink"
    assert_blocked_on "/opt/other-project/termlink"
}

@test "A2: bare 'termlink' in command position IS exempt" {
    run run_hook "termlink pty inject worker --enter \"cd /opt/other-project && ls\""
    [ "$status" -eq 0 ]
}

@test "A2: 'bin/fw termlink' in command position IS exempt" {
    run run_hook "bin/fw termlink dispatch --project /opt/other-project --prompt \"cat README.md\""
    [ "$status" -eq 0 ]
}

@test "A2: 'fw termlink' in command position IS exempt" {
    run run_hook "fw termlink dispatch --name w --prompt \"cd /opt/other-project && build\""
    [ "$status" -eq 0 ]
}

@test "A2: wrapper 'sudo' before termlink IS exempt" {
    run run_hook "sudo termlink interact w \"cd /opt/other-project && ls\""
    [ "$status" -eq 0 ]
}

@test "A2: wrapper 'timeout N' before termlink IS exempt" {
    run run_hook "timeout 30 termlink interact w \"cd /opt/other-project && ls\""
    [ "$status" -eq 0 ]
}

@test "A2: wrapper 'env VAR=v' before termlink IS exempt" {
    run run_hook "env TL_DEBUG=1 termlink interact w \"cd /opt/other-project && ls\""
    [ "$status" -eq 0 ]
}

@test "A2: wrapper 'nohup' before termlink IS exempt" {
    run run_hook "nohup termlink dispatch --project /opt/other-project --prompt \"x\""
    [ "$status" -eq 0 ]
}

@test "A2: 'VAR=v termlink' assignment prefix IS exempt" {
    run run_hook "TL_HUB=local termlink interact w \"cd /opt/other-project && ls\""
    [ "$status" -eq 0 ]
}

@test "A2: another project's absolute fw path is NOT exempt even with 'termlink'" {
    # Pattern 2 exists to block exactly this; the exemption must not re-open it.
    run run_hook "/opt/other-project/.agentic-framework/bin/fw termlink status"
    [ "$status" -eq 2 ]
    echo "$output" | grep -q "Reason:.*/opt/other-project"
}

# ── A3: the behaviour the exemption was built for (T-679 / T-1075) ──

@test "A3 (T-679): termlink pty inject with a cd inside its quoted argument" {
    run run_hook "termlink pty inject sess --enter \"cd /opt/other-project && make\""
    [ "$status" -eq 0 ]
}

@test "A3 (T-679): termlink interact with a cd inside its quoted argument" {
    run run_hook "termlink interact session \"cd /opt/other-project && git status\" --json"
    [ "$status" -eq 0 ]
}

@test "A3 (T-1075): termlink inside a for-loop body" {
    run run_hook 'for n in a b; do termlink pty inject "$n" "cd /opt/$n && ./build.sh"; done'
    [ "$status" -eq 0 ]
}

@test "A3 (T-1075): termlink after a leading command and ';'" {
    run run_hook "echo start; termlink interact worker \"cd /opt/other-project && git status\" --json"
    [ "$status" -eq 0 ]
}

@test "A3 (T-1075): termlink after '&&'" {
    run run_hook "echo start && termlink pty inject worker \"cd /opt/other-project\" --enter"
    [ "$status" -eq 0 ]
}

@test "A3 (T-679): fw termlink dispatch --project on another project" {
    run run_hook "bin/fw termlink dispatch --project /opt/other-project --prompt \"cat README.md\""
    [ "$status" -eq 0 ]
}

# ── Fail-closed direction ──

@test "fail-closed: separators inside quotes do not split (no exemption leak)" {
    # The '&&' here is quoted, so this is ONE segment whose command position is
    # `cat` — not exempt, despite containing the word termlink downstream.
    run run_hook "cat \"/opt/other-project/x && termlink\""
    [ "$status" -eq 2 ]
}

@test "fail-closed: an unbalanced quote still reaches analysis" {
    run run_hook "cat /opt/other-project/.env \"unterminated"
    assert_blocked_on "/opt/other-project/.env"
}

@test "fail-closed: hook source has no line-scoped termlink short-circuit" {
    # Pins the removal itself: a regex-and-exit-0 in the bash gate would restore
    # the whole-line behaviour without failing any behavioural test that only
    # covers commands the segment splitter also handles.
    run grep -nE "termlink.*\\\\s'; then" "$FRAMEWORK_ROOT/agents/context/check-project-boundary.sh"
    [ "$status" -ne 0 ]
}
