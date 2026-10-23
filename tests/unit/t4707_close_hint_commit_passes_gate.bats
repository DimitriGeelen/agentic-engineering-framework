#!/usr/bin/env bats
# T-4707 (TermLink be.10, sidecar c896df19): `--status work-completed` clears
# focus and prints `next: git commit -m '<id>: close ...' -- <paths> && git push`.
# That exact command must pass the task gate (check-active-task.sh) with focus
# null — the hint is the framework's own prescription. A commit with no focus
# that names anything else must still be refused.
#
# End to end: a real close through update-task.sh in a throwaway project, the
# printed line extracted verbatim, judged by the real hook, then run.

load ../test_helper

HOOK="$FRAMEWORK_ROOT/agents/context/check-active-task.sh"

setup() {
    # Shared focus.yaml: a worker running this suite may carry session-scoped
    # focus (T-3432), which would point both sides at a file the fixture lacks.
    unset FW_SESSION_SCOPED_FOCUS FW_FOCUS_SESSION_KEY
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    export PROJECT_ROOT="$TEST_TEMP_DIR/proj"
    guard_project_root
    mkdir -p "$PROJECT_ROOT/.tasks/active" "$PROJECT_ROOT/.tasks/completed" \
             "$PROJECT_ROOT/.context/working" "$PROJECT_ROOT/.context/episodic"
    git init -q --bare "$TEST_TEMP_DIR/remote.git"
    git -C "$PROJECT_ROOT" init -q -b main
    git -C "$PROJECT_ROOT" config user.email "test@test"
    git -C "$PROJECT_ROOT" config user.name "test"
    git -C "$PROJECT_ROOT" remote add origin "$TEST_TEMP_DIR/remote.git"
    cat > "$PROJECT_ROOT/.tasks/active/T-9470-fixture.md" <<'EOF'
---
id: T-9470
name: "fixture"
status: started-work
workflow_type: build
owner: claude-code
horizon: now
tags: []
created: 2026-06-01T00:00:00Z
last_update: 2026-06-01T00:00:00Z
---

# T-9470: fixture

## Acceptance Criteria

### Agent
- [x] Done

## Verification
# verification: none — fixture for the T-4707 close-hint gate test
EOF
    : > "$PROJECT_ROOT/README"
    git -C "$PROJECT_ROOT" add README .tasks/active/T-9470-fixture.md
    git -C "$PROJECT_ROOT" commit -qm "T-9470: init"
    git -C "$PROJECT_ROOT" push -q -u origin main 2>/dev/null
    printf 'current_task: T-9470\n' > "$PROJECT_ROOT/.context/working/focus.yaml"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

_close() {
    env PROJECT_ROOT="$PROJECT_ROOT" FRAMEWORK_ROOT="$FRAMEWORK_ROOT" \
        bash "$FRAMEWORK_ROOT/agents/task-create/update-task.sh" T-9470 \
        --status work-completed --skip-render-review "test fixture" 2>&1
}

# The printed next step, verbatim, minus the arrow prefix.
_hint() {
    printf '%s\n' "$1" | sed -n 's/^.*next: \(git commit .*\)$/\1/p' | head -1
}

_run_hook() {
    python3 -c "import json,sys; print(json.dumps({'tool_name':'Bash','cwd':sys.argv[2],'tool_input':{'command':sys.argv[1]}}))" "$1" "$PROJECT_ROOT" \
    | CLAUDECODE=1 PROJECT_ROOT="$PROJECT_ROOT" CONTEXT_DIR="$PROJECT_ROOT/.context" \
      TASKS_DIR="$PROJECT_ROOT/.tasks" bash "$HOOK" 2>&1
}

@test "T-4707: printed close hint passes the task gate with focus cleared, and runs" {
    local out cmd
    out=$(_close)
    grep -q '^current_task: null' "$PROJECT_ROOT/.context/working/focus.yaml"
    cmd=$(_hint "$out")
    [ -n "$cmd" ]
    [[ "$cmd" == *".tasks/completed/T-9470-fixture.md"* ]]
    run _run_hook "$cmd"
    echo "$output"
    [ "$status" -eq 0 ]
    [[ "$output" != *"No active task"* ]]
    # And it does what it says: the commit lands and is pushed.
    run bash -c "cd '$PROJECT_ROOT' && $cmd"
    echo "$output"
    [ "$status" -eq 0 ]
    git -C "$PROJECT_ROOT" ls-tree --name-only HEAD -- .tasks/completed/T-9470-fixture.md | grep -q T-9470
    [ "$(git -C "$PROJECT_ROOT" rev-parse HEAD)" = "$(git -C "$TEST_TEMP_DIR/remote.git" rev-parse main)" ]
}

@test "T-4707: close commit chained with a non-read-only clause is still refused, and the block names that clause" {
    _close >/dev/null
    run _run_hook "git commit -m 'T-9470: close ...' -- .tasks/completed/T-9470-fixture.md && bin/fw sidecar send --to x --body y"
    echo "$output"
    [ "$status" -eq 2 ]
    [[ "$output" == *"No active task"* ]]
    [[ "$output" == *"would be allowed with no focus"* ]]
    [[ "$output" == *"not read-only: bin/fw sidecar send"* ]]
}

@test "T-4707: close commit with a redirect is still refused, and the block names the write pattern" {
    _close >/dev/null
    run _run_hook "git commit -q -m 'T-9470: close ...' -- .tasks/completed/T-9470-fixture.md > log.txt 2>&1"
    echo "$output"
    [ "$status" -eq 2 ]
    [[ "$output" == *"No active task"* ]]
    [[ "$output" == *"a write pattern"* ]]
}

@test "T-4707: control — a blocked line with no git commit gets no commit hint" {
    _close >/dev/null
    run _run_hook "bin/fw sidecar send --to x --body y"
    echo "$output"
    [ "$status" -eq 2 ]
    [[ "$output" == *"No active task"* ]]
    [[ "$output" != *"would be allowed with no focus"* ]]
}
