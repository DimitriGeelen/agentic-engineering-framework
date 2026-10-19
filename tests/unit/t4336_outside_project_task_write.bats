#!/usr/bin/env bats
# T-4336: the Human-AC tick guard's Bash leg refused a shell write to a `.tasks/` path that
# resolves OUTSIDE PROJECT_ROOT (e.g. `cp X /tmp/fixture/.tasks/active/T-1.md`). Such a write
# cannot tick THIS project's Human ACs, so a provably-outside target passes.
#
# Every outside case runs the write for real (VECTOR) and then asks the hook (GUARD).
# The inside, unresolvable and ambiguous cases are the controls: they must stay refused.

setup() {
    FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-$(cd "$BATS_TEST_DIRNAME/../.." && pwd)}"
    HOOK_SH="$FRAMEWORK_ROOT/agents/context/check-human-ac-tick.sh"
    TEST_ROOT="$(mktemp -d)"
    OUTSIDE="$(mktemp -d)"
    mkdir -p "$TEST_ROOT/.tasks/active" "$TEST_ROOT/.context/working" "$OUTSIDE/.tasks/active"
    TASK_REL=".tasks/active/T-9999-test.md"
    cat > "$TEST_ROOT/$TASK_REL" <<'MD'
---
id: T-9999
name: "test"
status: started-work
workflow_type: build
---
# T-9999: test

## Acceptance Criteria

### Agent
- [ ] Agent AC one

### Human
- [ ] [REVIEW] Human AC one

## Verification

true
MD
    cp "$TEST_ROOT/$TASK_REL" "$TEST_ROOT/pristine.md"
    sed 's/- \[ \] \[REVIEW\]/- [x] [REVIEW]/' "$TEST_ROOT/$TASK_REL" > "$TEST_ROOT/ticked.md"
    cp "$TEST_ROOT/pristine.md" "$OUTSIDE/.tasks/active/T-9999-test.md"
    # A symlink inside the outside dir that points back into the project.
    ln -s "$TEST_ROOT" "$OUTSIDE/link"
    export PROJECT_ROOT="$TEST_ROOT"
    export CLAUDECODE=1
    unset FW_ALLOW_HUMAN_AC_TICK AI_AGENT
}

teardown() {
    rm -rf "$TEST_ROOT" "$OUTSIDE" 2>/dev/null
}

run_hook_bash() {
    local input
    input=$(python3 -c '
import json, sys
print(json.dumps({"tool_name": "Bash", "tool_input": {"command": sys.argv[1]}, "cwd": sys.argv[2]}))
' "$1" "$TEST_ROOT")
    run bash "$HOOK_SH" <<< "$input"
}

assert_allowed() {
    run_hook_bash "$1"
    [ "$status" -eq 0 ]
}

assert_refused() {
    run_hook_bash "$1"
    [ "$status" -eq 2 ]
    [[ "$output" == *"SHELL WRITE TO A TASK FILE BLOCKED"* ]]
}

outside_ticked() {
    sed -n '/^### Human/,/^## /p' "$OUTSIDE/.tasks/active/T-9999-test.md" | grep -q '^- \[x\]'
}

# ── provably outside: the write really lands outside, and the hook allows it ──────

@test "cp to an absolute .tasks path outside PROJECT_ROOT: writes outside, allowed" {
    c="cp $TEST_ROOT/ticked.md $OUTSIDE/.tasks/active/T-9999-test.md"
    run bash -c "$c"
    [ "$status" -eq 0 ]
    outside_ticked
    assert_allowed "$c"
}

@test "redirect into an outside .tasks path: writes outside, allowed" {
    c="cat $TEST_ROOT/ticked.md > $OUTSIDE/.tasks/active/T-9999-test.md"
    run bash -c "$c"
    [ "$status" -eq 0 ]
    outside_ticked
    assert_allowed "$c"
}

@test "sed -i on an outside .tasks file: writes outside, allowed" {
    c="sed -i 's/- \[ \] \[REVIEW\]/- [x] [REVIEW]/' $OUTSIDE/.tasks/active/T-9999-test.md"
    run bash -c "$c"
    [ "$status" -eq 0 ]
    outside_ticked
    assert_allowed "$c"
}

# ── controls: anything not provably outside stays refused ────────────────────────

@test "cp to an absolute .tasks path INSIDE PROJECT_ROOT: refused" {
    assert_refused "cp $TEST_ROOT/ticked.md $TEST_ROOT/$TASK_REL"
}

@test "symlink under the outside dir that resolves into PROJECT_ROOT: refused" {
    assert_refused "cp $TEST_ROOT/ticked.md $OUTSIDE/link/$TASK_REL"
}

@test "'..' escape from the outside dir back into PROJECT_ROOT: refused" {
    base="$(basename "$TEST_ROOT")"
    assert_refused "cp $TEST_ROOT/ticked.md $OUTSIDE/../$base/$TASK_REL"
}

@test "unresolvable variable target naming .tasks: refused" {
    assert_refused "cp $TEST_ROOT/ticked.md \${T4336_UNSET}/.tasks/active/T-9999-test.md"
}

@test "glob under the outside dir with no match (unresolvable): refused" {
    assert_refused "cp $TEST_ROOT/ticked.md $OUTSIDE/.tasks/nomatch*/T-9999-test.md"
}

@test "human-ac-ticks.jsonl ledger written outside PROJECT_ROOT: refused" {
    assert_refused "cp $TEST_ROOT/ticked.md $OUTSIDE/human-ac-ticks.jsonl"
}

@test "one outside write plus one inside write in the same command: refused" {
    assert_refused "cp $TEST_ROOT/ticked.md $OUTSIDE/.tasks/active/a.md && cp $TEST_ROOT/ticked.md $TEST_ROOT/$TASK_REL"
}

@test "PROJECT_ROOT unset: an outside .tasks write is refused (fail closed)" {
    unset PROJECT_ROOT
    input=$(python3 -c '
import json, sys
print(json.dumps({"tool_name": "Bash", "tool_input": {"command": sys.argv[1]}, "cwd": sys.argv[2]}))
' "cp $TEST_ROOT/ticked.md $OUTSIDE/.tasks/active/T-9999-test.md" "$TEST_ROOT")
    run bash "$HOOK_SH" <<< "$input"
    [ "$status" -eq 2 ]
}
