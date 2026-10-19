#!/usr/bin/env bats
# T-4396 — a read-only for/while/until loop is safe only when its header and EVERY
# body command are allowlisted reads, with no write anywhere.
#
# Before this, `for t in T-1 T-2; do grep -m1 name .tasks/*/$t-*.md; done` split
# into `for t in T-1 T-2` / ` do grep …` / ` done`; the keywords `for`, `do` and
# `done` match no allowlist arm, so every loop gated, read-only or not. The
# writing direction is pinned as hard as the reading one: a loop body is just a
# place to hide a command, so each hidden-write shape below must stay unsafe.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export FRAMEWORK_ROOT
    source "$FRAMEWORK_ROOT/agents/context/lib/safe-commands.sh"
    # T-4409: git is judged against its effective cwd, which must lie in
    # PROJECT_ROOT; name both rather than inherit the caller's environment.
    export PROJECT_ROOT="$FRAMEWORK_ROOT" _FW_PAYLOAD_CWD="$FRAMEWORK_ROOT"
}

# The gate's own order (check-active-task.sh): a write pattern on the whole line
# wins, then the allowlist. A loop must pass both to skip the task gate.
gate_safe() {
    ! has_bash_write_pattern "$1" && is_bash_safe_command "$1"
}

# --- safe loops (were all blocked) ---

@test "for loop over task ids with grep body is safe (the reported shape)" {
    run gate_safe 'for t in T-1 T-2; do grep -m1 name .tasks/*/$t-*.md; done'
    [ "$status" -eq 0 ]
}

@test "for loop with several body commands, all reads, is safe" {
    run gate_safe 'for f in a b; do echo "$f"; head -1 "$f"; wc -l "$f"; done'
    [ "$status" -eq 0 ]
}

@test "multi-line for loop is safe" {
    run gate_safe $'for t in T-1 T-2\ndo\n  grep -c x "$t"\ndone'
    [ "$status" -eq 0 ]
}

@test "for loop with safe command substitution in the word list is safe" {
    run gate_safe 'for f in $(ls .tasks/active); do head -1 ".tasks/active/$f"; done'
    [ "$status" -eq 0 ]
}

@test "while read loop with input redirect from a file is safe" {
    run gate_safe 'while read -r f; do head -1 "$f"; done < list.txt'
    [ "$status" -eq 0 ]
}

@test "until loop with allowlisted condition is safe" {
    run gate_safe 'until test -f x; do ls; done'
    [ "$status" -eq 0 ]
}

@test "loop piped into a read and chained with a read is safe" {
    run gate_safe 'for t in a b; do grep -l x "$t"; done | sort; git status'
    [ "$status" -eq 0 ]
}

@test "loop with 2>/dev/null after done is safe" {
    run gate_safe 'for t in a b; do grep x "$t"; done 2>/dev/null'
    [ "$status" -eq 0 ]
}

@test "nested loops whose bodies are all reads are safe" {
    run gate_safe 'for a in x y; do for b in 1 2; do grep "$a" "$b"; done; done'
    [ "$status" -eq 0 ]
}

# --- loops hiding a write ---

@test "loop body redirect to a file is NOT safe" {
    run gate_safe 'for t in a b; do grep x "$t" > out.txt; done'
    [ "$status" -ne 0 ]
    run is_bash_safe_command 'for t in a b; do grep x "$t" > out.txt; done'
    [ "$status" -ne 0 ]
}

@test "redirect after done is NOT safe" {
    run is_bash_safe_command 'for t in a b; do grep x "$t"; done > out.txt'
    [ "$status" -ne 0 ]
}

@test "tee in loop body is NOT safe" {
    run is_bash_safe_command 'for t in a b; do grep x "$t" | tee -a out; done'
    [ "$status" -ne 0 ]
}

@test "sed -i in loop body is NOT safe" {
    run is_bash_safe_command 'for f in a b; do sed -i s/x/y/ "$f"; done'
    [ "$status" -ne 0 ]
}

@test "cp in loop body is NOT safe" {
    run is_bash_safe_command 'for f in a b; do cp "$f" /tmp/; done'
    [ "$status" -ne 0 ]
}

@test "write inside the word list's command substitution is NOT safe" {
    run is_bash_safe_command 'for f in $(cp a b); do ls; done'
    [ "$status" -ne 0 ]
    run is_bash_safe_command 'for f in $(git commit -m "T-1: x"); do ls; done'
    [ "$status" -ne 0 ]
}

@test "backtick substitution in the word list is NOT safe" {
    run is_bash_safe_command 'for f in `cp a b`; do ls; done'
    [ "$status" -ne 0 ]
}

@test "non-allowlisted body command is NOT safe" {
    run is_bash_safe_command 'for t in a b; do bin/fw task update "$t" --status work-completed; done'
    [ "$status" -ne 0 ]
}

@test "non-allowlisted while condition is NOT safe" {
    run is_bash_safe_command 'while git commit -m "T-1: x"; do ls; done'
    [ "$status" -ne 0 ]
}

@test "nested loop with an unsafe inner body is NOT safe" {
    run is_bash_safe_command 'for a in x; do for b in y; do mv "$a" "$b"; done; done'
    [ "$status" -ne 0 ]
}

@test "cd inside a loop body is NOT safe (cwd per iteration unknowable)" {
    run is_bash_safe_command 'for d in a b; do cd "$d"; git log -1; done'
    [ "$status" -ne 0 ]
}

# --- malformed / unknown shapes stay fail-closed ---

@test "loop without done is NOT safe" {
    run is_bash_safe_command 'for t in a b; do ls'
    [ "$status" -ne 0 ]
}

@test "stray done is NOT safe" {
    run is_bash_safe_command 'ls; done'
    [ "$status" -ne 0 ]
}

@test "for header without do is NOT safe" {
    run is_bash_safe_command 'for t in a b; ls; done'
    [ "$status" -ne 0 ]
}

@test "if inside a loop body is NOT safe (unknown construct)" {
    run is_bash_safe_command 'for t in a; do if test -f x; then ls; fi; done'
    [ "$status" -ne 0 ]
}

@test "C-style for loop is NOT safe" {
    run is_bash_safe_command 'for ((i=0; i<3; i++)); do ls; done'
    [ "$status" -ne 0 ]
}

@test "here-string after done is NOT safe (fail-closed)" {
    run is_bash_safe_command 'while read -r l; do echo "$l"; done <<< "a b"'
    [ "$status" -ne 0 ]
}

@test "process substitution after done is NOT safe (fail-closed)" {
    run is_bash_safe_command 'while read -r l; do echo "$l"; done < <(cp a b)'
    [ "$status" -ne 0 ]
}
