#!/usr/bin/env bats
# T-4763: a backtick inside single quotes is literal in bash. check-human-ac-tick's Bash
# leg refused `grep -n '```' .tasks/...` as "does not tokenise (unbalanced quote)" because
# lib/shell_write_scan.py:_substitutions paired those backticks into a fake body. Real
# substitutions (bare, in double quotes, $(...)) must still be scanned and refused.

setup() {
    FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-$(cd "$BATS_TEST_DIRNAME/../.." && pwd)}"
    HOOK_SH="$FRAMEWORK_ROOT/agents/context/check-human-ac-tick.sh"
    TEST_ROOT="$(mktemp -d)"
    mkdir -p "$TEST_ROOT/.tasks/active" "$TEST_ROOT/.context/working"
    TASK_REL=".tasks/active/T-9999-test.md"
    TASK_FILE="$TEST_ROOT/$TASK_REL"
    cat > "$TASK_FILE" <<'MD'
---
id: T-9999
name: "test"
status: started-work
workflow_type: build
---
# T-9999: test

```
fenced
```

### Human
- [ ] [REVIEW] Human AC one

## Verification

true
MD
    cp "$TASK_FILE" "$TEST_ROOT/pristine.md"
    export PROJECT_ROOT="$TEST_ROOT"
    export CLAUDECODE=1
    unset FW_ALLOW_HUMAN_AC_TICK AI_AGENT
}

teardown() {
    rm -rf "$TEST_ROOT" 2>/dev/null
}

S="'s/- \[ \] \[REVIEW\]/- [x] [REVIEW]/'"

human_ticked() {
    sed -n '/^### Human/,/^## /p' "$TASK_FILE" | grep -q '^- \[x\]'
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

# Run for real in the fixture: the command must tick the Human box (a genuine vector).
assert_vector_refused() {
    cp "$TEST_ROOT/pristine.md" "$TASK_FILE"
    run bash -c "cd '$TEST_ROOT' && $1"
    run human_ticked
    [ "$status" -eq 0 ]
    cp "$TEST_ROOT/pristine.md" "$TASK_FILE"
    assert_refused "$1"
}

@test "TermLink be.18 shape: grep with a single-quoted code fence over task files passes" {
    c="grep -n '\`\`\`' $TASK_REL"
    run bash -c "cd '$TEST_ROOT' && $c"
    [ "$status" -eq 0 ]
    [[ "$output" == *'```'* ]]
    assert_allowed "$c"
}

@test "single backtick and backtick pairs inside single quotes pass" {
    assert_allowed "grep -n '\`' $TASK_REL"
    assert_allowed "grep -rn '\`x\`' .tasks/"
    assert_allowed "grep -c '\`\`\`' .tasks/active/*.md"
}

@test "sidecar send whose single-quoted body quotes the example passes" {
    assert_allowed "fw sidecar send --to w1 --conversation c1 --body 'refused: grep -n '\"'\"'\`\`\`'\"'\"' $TASK_REL'"
    assert_allowed "fw sidecar send --to w1 --body 'see \`\`\` in $TASK_REL'"
}

@test "backticks in double quotes still execute: a tick inside them is refused" {
    assert_vector_refused "echo \"\`sed -i $S $TASK_REL\`\""
}

@test "bare backticks and \$(...) still refused" {
    assert_vector_refused "echo \`sed -i $S $TASK_REL\`"
    assert_vector_refused "echo \"\$(sed -i $S $TASK_REL)\""
}

@test "a literal backtick before a real substitution does not hide it" {
    # the old pairing matched the quoted backtick with the opening real one
    assert_vector_refused "grep -c '\`' $TASK_REL && echo \"\`sed -i $S $TASK_REL\`\""
}

@test "a real substitution body that does not tokenise is still refused" {
    assert_refused "echo \"\`cat '$TASK_REL\`\""
    assert_refused "grep -n 'x' \"$TASK_REL"
}
