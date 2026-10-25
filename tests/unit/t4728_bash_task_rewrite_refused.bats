#!/usr/bin/env bats
# T-4728: TermLink (their T-2957) reported that six task-file gates are wired
# Write|Edit only, so a Bash heredoc rewrite of a task file "skips" them. The five
# content validators need no Bash leg: check-human-ac-tick (T-3695) refuses EVERY
# shell write to .tasks/** under agent control, not only writes that tick a Human
# box. These tests pin that for the shape reported: a rewrite that adds an
# unresolvable arc_id / malformed inception_decisions and ticks nothing.
#
# Same two-claim shape as t3695: the command really rewrites the file (VECTOR),
# and the hook refuses that same command string (GUARD).

setup() {
    FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-$(cd "$BATS_TEST_DIRNAME/../.." && pwd)}"
    HOOK_SH="$FRAMEWORK_ROOT/agents/context/check-human-ac-tick.sh"
    TEST_ROOT="$(mktemp -d)"
    mkdir -p "$TEST_ROOT/.tasks/active" "$TEST_ROOT/.context/working"
    TASK_REL=".tasks/active/T-9998-test.md"
    TASK_FILE="$TEST_ROOT/$TASK_REL"
    cat > "$TASK_FILE" <<'MD'
---
id: T-9998
name: "test"
status: started-work
workflow_type: inception
---
# T-9998: test

### Human
- [ ] [REVIEW] Human AC one
MD
    cp "$TASK_FILE" "$TEST_ROOT/pristine.md"
    export PROJECT_ROOT="$TEST_ROOT"
    export CLAUDECODE=1
    unset FW_ALLOW_HUMAN_AC_TICK AI_AGENT
}

teardown() {
    rm -rf "$TEST_ROOT" 2>/dev/null
}

run_hook_bash() {
    local input
    input=$(python3 -c '
import json, sys
print(json.dumps({"tool_name": "Bash", "tool_input": {"command": sys.argv[1]}, "cwd": sys.argv[2]}))
' "$1" "$TEST_ROOT")
    run bash "$HOOK_SH" <<< "$input"
}

# The command really rewrites the file (and ticks nothing), then the hook refuses it.
assert_rewrite_refused() {
    local cmd="$1" marker="$2"
    cp "$TEST_ROOT/pristine.md" "$TASK_FILE"
    run bash -c "cd '$TEST_ROOT' && $cmd"
    [ "$status" -eq 0 ]
    grep -qF "$marker" "$TASK_FILE"
    ! grep -q '^- \[x\]' "$TASK_FILE" || false
    cp "$TEST_ROOT/pristine.md" "$TASK_FILE"
    run_hook_bash "$cmd"
    [ "$status" -eq 2 ]
    [[ "$output" == *"SHELL WRITE TO A TASK FILE BLOCKED"* ]]
}

BAD_ARC='---
id: T-9998
name: "test"
status: started-work
workflow_type: inception
arc_id: no-such-arc-t4728
---'

@test "heredoc (cat > file <<EOF) adding an unresolvable arc_id, no tick: refused" {
    assert_rewrite_refused "cat > $TASK_REL <<'EOF'
$BAD_ARC
EOF" "no-such-arc-t4728"
}

@test "python3 heredoc writing malformed inception_decisions, no tick: refused" {
    assert_rewrite_refused "python3 - <<'EOF'
p = '$TASK_REL'
s = open(p).read().replace('workflow_type: inception', 'workflow_type: inception\ninception_decisions: [{id: BAD ID}]')
open(p, 'w').write(s)
EOF" "BAD ID"
}

@test "tee rewrite adding an unresolvable arc_id, no tick: refused" {
    assert_rewrite_refused "printf '%s\n' 'arc_id: no-such-arc-t4728' | tee -a $TASK_REL" "no-such-arc-t4728"
}

@test "control: without agent control the Bash leg is advisory (exit 0)" {
    unset CLAUDECODE
    run_hook_bash "cat > $TASK_REL <<'EOF'
$BAD_ARC
EOF"
    [ "$status" -eq 0 ]
}

@test "control: reading the task file passes" {
    run_hook_bash "cat $TASK_REL && grep -n arc_id $TASK_REL"
    [ "$status" -eq 0 ]
}
