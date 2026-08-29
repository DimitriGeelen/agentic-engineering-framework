#!/usr/bin/env bats
# T-3210 — the handover's "Suggested First Action" named a task the session had
# never touched, in a document that printed the real focus three sections earlier.
#
# REPRODUCED before any edit: the shipped selector, extracted and run unmodified,
# printed `Continue T-1719: "Embeddings strategy V1 — ...` — byte-identical to
# LATEST.md — while focus.yaml said `current_task: T-3181`. 296 candidates, and
# T-1719 won on STRING ORDER: the sort key was the task id as text, so
# 'T-1062' < 'T-1719' < 'T-332' and the pool resolved on lexicographic accident.
#
# Every test below extracts the SHIPPED command-substitution out of
# agents/handover/handover.sh and runs it against a synthetic task tree. It does
# not restate the selection logic: a guard that reimplements the code it guards
# cannot detect that code being fixed (peer 832, chat-arc 689), and a test that
# fakes its data source cannot detect the source behaving differently (T-3209).

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
HANDOVER="$FRAMEWORK_ROOT/agents/handover/handover.sh"

setup() {
    T="$(mktemp -d)"
    mkdir -p "$T/tasks/active" "$T/context/working"
}
teardown() { rm -rf "$T"; }

# Carve the live `$(python3 -c "...")` block out of handover.sh and make it
# runnable with TASKS_DIR / CONTEXT_DIR pointed at the fixture tree.
_selector() {
    local s b e
    s=$(grep -n '^candidates = \[\]$' "$HANDOVER" | cut -d: -f1)
    [ -n "$s" ] || return 91
    b=$(awk -v s="$s" 'NR<s && /^\$\(python3 -c "$/{l=NR} END{print l}' "$HANDOVER")
    e=$(awk -v s="$s" 'NR>s && /^" 2>\/dev\/null \|\| echo "See active tasks"\)$/{print NR; exit}' "$HANDOVER")
    [ -n "$b" ] && [ -n "$e" ] || return 91
    sed -n "${b},${e}p" "$HANDOVER" > "$T/block.txt"
    { printf 'SFA='; cat "$T/block.txt"; printf '\nprintf %%s "$SFA"\n'; } > "$T/run.sh"
    TASKS_DIR="$T/tasks" CONTEXT_DIR="$T/context" bash "$T/run.sh"
}

_task() {
    # _task <id> <status> <horizon> <owner> <last_update> [name]
    cat > "$T/tasks/active/$1.md" <<EOF
---
id: $1
name: "${6:-task $1}"
status: $2
horizon: $3
owner: $4
last_update: $5
---
EOF
}

_focus() { printf 'current_task: %s\n' "$1" > "$T/context/working/focus.yaml"; }

@test "t3210: the focused task is chosen even when it sorts last" {
    _task T-9999 started-work now agent 2026-01-01T00:00:00Z
    _task T-1000 started-work now agent 2026-08-01T00:00:00Z
    _focus T-9999
    run _selector
    [ "$status" -eq 0 ]
    [[ "$output" == "Continue T-9999:"* ]]
}

@test "t3210: focus does NOT win when it names a task that is not a candidate" {
    # A completed / parked focus must not suppress the suggestion entirely.
    _task T-1000 started-work now agent 2026-08-01T00:00:00Z
    _focus T-4242
    run _selector
    [ "$status" -eq 0 ]
    [[ "$output" == "Continue T-1000:"* ]]
}

@test "t3210: with no focus, the MOST RECENT candidate wins, not the lowest id" {
    # THE regression. Under the old lexicographic key T-1000 won on string order
    # despite being seven months staler.
    _task T-1000 started-work now agent 2026-01-01T00:00:00Z
    _task T-8000 started-work now agent 2026-08-20T00:00:00Z
    run _selector
    [ "$status" -eq 0 ]
    [[ "$output" == "Continue T-8000:"* ]]
}

@test "t3210: recency wins where string order and NUMERIC order disagree" {
    # Written the wrong way round first, and the mutation cycle caught it: the
    # newest task originally had the lexicographically SMALLEST id, so the old
    # lexicographic key picked the same winner and M1 did not redden this test.
    # A test that passes under the mutation it exists to catch asserts nothing.
    # Inverted: 'T-1000' < 'T-999' as TEXT, so lexicographic picks the STALE
    # T-1000 while recency must pick T-999.
    _task T-1000 started-work now agent 2026-01-01T00:00:00Z
    _task T-999  started-work now agent 2026-08-20T00:00:00Z
    run _selector
    [ "$status" -eq 0 ]
    [[ "$output" == "Continue T-999:"* ]]
}

@test "t3210: agent-owned still outranks human-owned (CONTROL, preserved)" {
    _task T-1000 started-work now human 2026-08-25T00:00:00Z
    _task T-2000 started-work now agent 2026-01-01T00:00:00Z
    run _selector
    [ "$status" -eq 0 ]
    [[ "$output" == "Continue T-2000:"* ]]
}

@test "t3210: horizon now still outranks horizon next (CONTROL, preserved)" {
    _task T-1000 started-work next agent 2026-08-25T00:00:00Z
    _task T-2000 started-work now  agent 2026-01-01T00:00:00Z
    run _selector
    [ "$status" -eq 0 ]
    [[ "$output" == "Continue T-2000:"* ]]
}

@test "t3210: horizon later is still excluded (CONTROL, preserved)" {
    _task T-1000 started-work later agent 2026-08-25T00:00:00Z
    run _selector
    [ "$status" -eq 0 ]
    [ "$output" = "See active tasks" ]
}

@test "t3210: a DEFER-parked inception is still skipped (CONTROL, T-1724 preserved)" {
    _task T-1000 started-work now agent 2026-08-25T00:00:00Z
    printf '\n**Decision**: DEFER\n' >> "$T/tasks/active/T-1000.md"
    _task T-2000 started-work now agent 2026-01-01T00:00:00Z
    run _selector
    [ "$status" -eq 0 ]
    [[ "$output" == "Continue T-2000:"* ]]
}

@test "t3210: no candidates renders the fallback, never a blank line" {
    run _selector
    [ "$status" -eq 0 ]
    [ "$output" = "See active tasks" ]
}

@test "t3210: a missing focus.yaml is survivable, not a traceback" {
    _task T-1000 started-work now agent 2026-08-01T00:00:00Z
    rm -f "$T/context/working/focus.yaml"
    run _selector
    [ "$status" -eq 0 ]
    [[ "$output" == "Continue T-1000:"* ]]
}

@test "t3210: a candidate with no last_update still sorts and renders" {
    cat > "$T/tasks/active/T-1000.md" <<'EOF'
---
id: T-1000
name: "no last_update field"
status: started-work
horizon: now
owner: agent
---
EOF
    run _selector
    [ "$status" -eq 0 ]
    [[ "$output" == "Continue T-1000:"* ]]
}

@test "t3210: focus.yaml with a quoted id still matches" {
    _task T-9999 started-work now agent 2026-01-01T00:00:00Z
    _task T-1000 started-work now agent 2026-08-01T00:00:00Z
    printf 'current_task: "T-9999"\n' > "$T/context/working/focus.yaml"
    run _selector
    [ "$status" -eq 0 ]
    [[ "$output" == "Continue T-9999:"* ]]
}

@test "t3210: the selector block still EXECUTES — no unescaped quote in the python -c" {
    # bash -n does NOT catch this. An unescaped double quote inside the
    # `python3 -c "..."` block terminates the shell string early and leaves
    # syntactically VALID shell that means something else entirely — which is
    # exactly what happened while writing this fix. Only running it catches it.
    _task T-1000 started-work now agent 2026-08-01T00:00:00Z
    run _selector
    [ "$status" -eq 0 ]
    [[ "$output" != *"syntax error"* ]]
    [[ "$output" == Continue* ]]
}

@test "t3210: handover.sh passes shell syntax check" {
    run bash -n "$HANDOVER"
    [ "$status" -eq 0 ]
}
