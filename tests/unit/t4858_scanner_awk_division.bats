#!/usr/bin/env bats
#
# T-4858 (SECURITY): ring20-dashboard review of be.46 (msg 72cf84a0, finding 2).
# lib/shell_write_scan.py awk_program_risk decides whether `/` opens a regex literal
# (skipped as data) or divides (scanned as code). After a postfix `++`/`--` it saw the
# last `+`/`-` as a binary operator and opened a "regex", so in
#     awk 'BEGIN{x++ / 2; system("touch F"); y = 1 / 3}'
# the text `/ 2; system("touch F"); y = 1 /` was skipped as data while awk divides and
# RUNS system(). The read-only allowlist (safe-commands.sh, used by the task gate)
# reported that command SAFE. After `)`, `]`, an identifier, a number, a string or a
# regex the tokenizer already read `/` as division (measured; pinned below).
#
# Fix: `++` / `--` are one token that ends an operand, so `/` after it divides.
# Division is the fail-closed reading: the text after it stays scanned.
#
# The Human-AC tick guard does not use the tokenizer: its awk arm matches system(,
# print >/| and close( over the raw program text, regex literals included, so the
# division case was already refused there (pinned below, with the vector proven real).
#
# Classification only, except the tick-guard vector, which runs in a mktemp project.
# `! cmd` at statement position is inert in bats (L-628): use `if …; then false; fi`.

load helpers/known_cwd

setup() {
    ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    known_cwd_setup
    source "$ROOT/agents/context/lib/safe-commands.sh"
    HOOK_SH="$ROOT/agents/context/check-human-ac-tick.sh"
    TEST_ROOT="$(mktemp -d)"
    mkdir -p "$TEST_ROOT/.tasks/active" "$TEST_ROOT/.context/working" "$TEST_ROOT/.context/reviews"
    TASK_REL=".tasks/active/T-9999-test.md"
    printf '%s\n' '---' 'id: T-9999' '---' '### Human' '- [ ] [REVIEW] h' '## Verification' \
        > "$TEST_ROOT/$TASK_REL"
}

teardown() {
    known_cwd_teardown
    rm -rf "$TEST_ROOT" 2>/dev/null
}

_refused() {
    local c
    for c in "$@"; do
        if is_bash_safe_command "$c"; then echo "SAFE (expected gated): $c"; return 1; fi
    done
}

_safe() {
    local c
    for c in "$@"; do
        is_bash_safe_command "$c" || { echo "gated (expected SAFE): $c"; return 1; }
    done
}

_risk() {
    python3 -I -c 'import sys
sys.path.insert(0, sys.argv[1])
import shell_write_scan as s
want = sys.argv[2] == "risky"
bad = [p for p in sys.argv[3:] if bool(s.awk_program_risk(p)) != want]
print("\n".join(bad) if bad else "ok")' "$ROOT/lib" "$@"
}

_hook() {
    local input
    input=$(python3 -c 'import json, sys
print(json.dumps({"tool_name": "Bash", "tool_input": {"command": sys.argv[1]}, "cwd": sys.argv[2]}))' \
        "$1" "$TEST_ROOT")
    PROJECT_ROOT="$TEST_ROOT" CLAUDECODE=1 run bash "$HOOK_SH" <<< "$input"
}

@test "T-4858: awk really divides after x++ and runs the system() the scanner skipped" {
    run awk 'BEGIN{x++ / 2; system("echo RAN"); y = 1 / 3}'
    [ "$status" -eq 0 ]
    [ "$output" = RAN ]
}

@test "T-4858: / after postfix ++ or -- divides, so system() and a pipe are seen" {
    run _risk risky 'BEGIN{x++ / 2; system("touch F"); y = 1 / 3}' \
        '{n--/2; print | "sh"; m=1/3}' '{a[$1]++ / 2; system("x"); b = 1 / 3}' \
        '{$1++ / 2; "x" | getline; b = 1 / 3}' '{x-- /2; print |& "sh"; y=1/ 3}'
    [ "$output" = ok ]
}

@test "T-4858: / after ), ], identifier, number, string, regex already divided (pinned)" {
    run _risk risky '{print (1) / 2; system("x"); y = 1/3}' '{a[1] / 2; system("x"); b = 1 / 3}' \
        '{print x / 2; system("x"); y = 1/3}' '{print 4 / 2; system("x"); y = 1/3}' \
        '{print NF / 2; system("x"); y = 1/3}' '{print "s" / 2; system("x"); y = 1/3}' \
        '$0 ~ /a/ / 2 {system("x"); y = 1/3}'
    [ "$output" = ok ]
}

@test "T-4858: regex literals after operators, unary signs and newlines stay data" {
    run _risk clean '/a|b/' '{n++} /a|b/ {print}' '{x = 1 + /a|b/}' '{x = - /a|b/}' \
        '{x = - -/a|b/}' '{n++}
/a|b/ {print}' '/^### Human/,/^## /' '{x++; y = /a|b/}' '{print x++ / 2}' '{print ++x / 2}'
    [ "$output" = ok ]
}

@test "T-4858: the read-only allowlist gates the division vector, admits read-only awk" {
    _refused "awk 'BEGIN{x++ / 2; system(\"touch F\"); y = 1 / 3}'" \
        "awk '{n--/2; print | \"sh\"; m=1/3}' F"
    _safe "awk '/^### Human/,/^## /' F" "awk '{n++} /a|b/ {print}' F" "awk '{print x++ / 2}' F"
}

@test "T-4858: tick guard refuses the division vector writing a task file (vector real)" {
    c="awk 'BEGIN{x++ / 2; system(\"echo ticked >> $TASK_REL\"); y = 1 / 3}'"
    run bash -c "cd '$TEST_ROOT' && $c"
    [ "$status" -eq 0 ]
    grep -q '^ticked$' "$TEST_ROOT/$TASK_REL"
    _hook "$c"
    [ "$status" -eq 2 ]
    [[ "$output" == *"SHELL WRITE TO A TASK FILE BLOCKED"* ]]
    _hook "awk 'BEGIN{n--/2; print \"x\" > \"$TASK_REL\"; m=1/3}'"
    [ "$status" -eq 2 ]
}

@test "T-4858: tick guard admits read-only awk over a task file" {
    _hook "awk '/^### Human/,/^## /' $TASK_REL"
    [ "$status" -eq 0 ]
    _hook "awk '{n++} /^- \\[x\\]/ {print n / 2}' $TASK_REL"
    [ "$status" -eq 0 ]
}
