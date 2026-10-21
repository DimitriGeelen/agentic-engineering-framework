#!/usr/bin/env bats
#
# T-3838 — lib/shell_write_scan.py did not treat `truncate -s 0 <task file>` as a
# write (ring20-dashboard T-2460, msg 6b1ada91). `truncate` was known only to the
# T-4149 boundary mode (_ALL_OPERANDS); the default scan, which check-human-ac-tick
# runs, fell through and returned no hit, so the shell write was let through.
#
# Two claims, as in t3695: the command really empties the task file (VECTOR), and
# the hook refuses it under CLAUDECODE=1 (GUARD). Controls keep truncate of an
# unguarded path and the -s/-r value word from being mistaken for a target.
#
# `! cmd` at statement position is INERT in bats (L-628) — use `|| false`.

setup() {
    FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-$(cd "$BATS_TEST_DIRNAME/../.." && pwd)}"
    HOOK_SH="$FRAMEWORK_ROOT/agents/context/check-human-ac-tick.sh"
    TEST_ROOT="$(mktemp -d)"
    mkdir -p "$TEST_ROOT/.tasks/active" "$TEST_ROOT/.context/working"
    TASK_REL=".tasks/active/T-9999-test.md"
    printf -- '---\nid: T-9999\n---\n### Human\n- [ ] [REVIEW] x\n' > "$TEST_ROOT/$TASK_REL"
    export PROJECT_ROOT="$TEST_ROOT"
    export CLAUDECODE=1
    unset FW_ALLOW_HUMAN_AC_TICK AI_AGENT
}

teardown() { rm -rf "$TEST_ROOT" 2>/dev/null; return 0; }

run_hook_bash() {
    local input
    input=$(python3 -c '
import json, sys
print(json.dumps({"tool_name": "Bash", "tool_input": {"command": sys.argv[1]}, "cwd": sys.argv[2]}))
' "$1" "$TEST_ROOT")
    run bash "$HOOK_SH" <<< "$input"
}

assert_refused() {
    run_hook_bash "$1"
    [ "$status" -eq 2 ] || { echo "not refused (status $status): $1"; false; }
    [[ "$output" == *"SHELL WRITE TO A TASK FILE BLOCKED"* ]]
}

assert_allowed() {
    run_hook_bash "$1"
    [ "$status" -eq 0 ] || { echo "refused: $1"; echo "$output"; false; }
}

@test "T-3838 vector: truncate -s 0 really empties the task file" {
    [ -s "$TEST_ROOT/$TASK_REL" ]
    (cd "$TEST_ROOT" && truncate -s 0 "$TASK_REL")
    [ ! -s "$TEST_ROOT/$TASK_REL" ] || false
}

@test "T-3838 guard: truncate -s 0 <task file> is refused" {
    assert_refused "truncate -s 0 $TASK_REL"
}

@test "T-3838 guard: size/reference spellings and wrappers are refused" {
    for c in "truncate --size=0 $TASK_REL" "truncate -s0 $TASK_REL" "truncate --size 0 $TASK_REL" \
             "truncate --si 0 $TASK_REL" "truncate -cs 0 $TASK_REL" "truncate -r /dev/null $TASK_REL" \
             "truncate -s 0 -- $TASK_REL" "sudo truncate -s 0 $TASK_REL" \
             "cd .tasks/active && truncate -s 0 T-9999-test.md" "truncate -s 0 $TEST_ROOT/$TASK_REL"; do
        assert_refused "$c"
    done
}

@test "T-3838 control: truncate of an unguarded path is allowed" {
    assert_allowed "truncate -s 0 notes.txt"
    assert_allowed "truncate -r notes.txt other.txt"
}
