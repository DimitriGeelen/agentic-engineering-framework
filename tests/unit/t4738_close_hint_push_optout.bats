#!/usr/bin/env bats
# T-4738 (050 be.16, sidecar abf6d155): at 050 a push deploys production, so the
# close hint's `&& git push <remote> HEAD` (T-4719) was trimmed by hand. The
# registry key CLOSE_HINT_PUSH=0 drops the push clause from both printers:
# update-task.sh's `next:` line and check-active-task.sh's T-4707 commit-shape
# hint. 1 or unset keeps today's output.
#
# End to end: a real close in a throwaway project with a bare remote; the printed
# line is run verbatim and the remote is checked for whether anything arrived.

load ../test_helper
load ../git_fence

HOOK="$FRAMEWORK_ROOT/agents/context/check-active-task.sh"

setup() {
    unset FW_SESSION_SCOPED_FOCUS FW_FOCUS_SESSION_KEY FW_CLOSE_HINT_PUSH
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    export PROJECT_ROOT="$TEST_TEMP_DIR/proj"
    guard_project_root
    mkdir -p "$PROJECT_ROOT/.tasks/active" "$PROJECT_ROOT/.tasks/completed" \
             "$PROJECT_ROOT/.context/working" "$PROJECT_ROOT/.context/episodic"
    git -C "$PROJECT_ROOT" init -q -b main
    git -C "$PROJECT_ROOT" config user.email "test@test"
    git -C "$PROJECT_ROOT" config user.name "test"
    cat > "$PROJECT_ROOT/.tasks/active/T-9473-fixture.md" <<'EOF'
---
id: T-9473
name: "fixture"
status: started-work
workflow_type: build
owner: claude-code
horizon: now
tags: []
created: 2026-06-01T00:00:00Z
last_update: 2026-06-01T00:00:00Z
---

# T-9473: fixture

## Acceptance Criteria

### Agent
- [x] Done

## Verification
# verification: none — fixture for the T-4738 close-hint push opt-out test
EOF
    : > "$PROJECT_ROOT/README"
    git -C "$PROJECT_ROOT" add README .tasks/active/T-9473-fixture.md
    git -C "$PROJECT_ROOT" commit -qm "T-9473: init"
    printf 'current_task: T-9473\n' > "$PROJECT_ROOT/.context/working/focus.yaml"
    git init -q --bare "$TEST_TEMP_DIR/origin.git"
    git -C "$PROJECT_ROOT" remote add origin "$TEST_TEMP_DIR/origin.git"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

_set_key() {
    # fw config set refuses outside an AEF project; .framework.yaml marks one.
    [ -f "$PROJECT_ROOT/.framework.yaml" ] || printf 'project_name: fixture\n' > "$PROJECT_ROOT/.framework.yaml"
    (cd "$PROJECT_ROOT" && PROJECT_ROOT="$PROJECT_ROOT" "$FRAMEWORK_ROOT/bin/fw" config set CLOSE_HINT_PUSH "$1" >/dev/null 2>&1)
    grep -q "^CLOSE_HINT_PUSH: *[\"']\?$1" "$PROJECT_ROOT/.framework.yaml"
}

_close() {
    env PROJECT_ROOT="$PROJECT_ROOT" FRAMEWORK_ROOT="$FRAMEWORK_ROOT" \
        bash "$FRAMEWORK_ROOT/agents/task-create/update-task.sh" T-9473 \
        --status work-completed --skip-render-review "test fixture" 2>&1
}

_hint() {
    printf '%s\n' "$1" | sed -n 's/^.*next: \(git commit .*\)$/\1/p' | head -1
}

_run_hook() {
    python3 -c "import json,sys; print(json.dumps({'tool_name':'Bash','cwd':sys.argv[2],'tool_input':{'command':sys.argv[1]}}))" "$1" "$PROJECT_ROOT" \
    | CLAUDECODE=1 PROJECT_ROOT="$PROJECT_ROOT" CONTEXT_DIR="$PROJECT_ROOT/.context" \
      TASKS_DIR="$PROJECT_ROOT/.tasks" bash "$HOOK" 2>&1
}

# Close, run the printed hint verbatim; $1 = expect-push (1) or no-push (0).
_close_and_run() {
    local want="$1" out cmd
    out=$(_close)
    cmd=$(_hint "$out")
    echo "hint: $cmd"
    [ -n "$cmd" ]
    if [ "$want" = 1 ]; then
        [[ "$cmd" == *"&& git push origin HEAD" ]]
    else
        [[ "$cmd" != *"git push"* ]]
    fi
    run bash -c "cd '$PROJECT_ROOT' && $cmd"
    echo "$output"
    [ "$status" -eq 0 ]
    git -C "$PROJECT_ROOT" ls-tree --name-only HEAD -- .tasks/completed/T-9473-fixture.md | grep -q T-9473
    if [ "$want" = 1 ]; then
        [ "$(git -C "$PROJECT_ROOT" rev-parse HEAD)" = "$(git -C "$TEST_TEMP_DIR/origin.git" rev-parse refs/heads/main)" ]
    else
        run git -C "$TEST_TEMP_DIR/origin.git" rev-parse --verify -q refs/heads/main
        [ "$status" -ne 0 ]
    fi
}

# The T-4707 commit-shape hint; $1 = expect-push (1) or no-push (0).
_shape_hint() {
    local want="$1"
    run _run_hook "git commit -m 'T-9473: close ...' -- .tasks/completed/T-9473-fixture.md && bin/fw sidecar send --to x --body y"
    echo "$output"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Run the commit as the close printed it"* ]]
    if [ "$want" = 1 ]; then
        [[ "$output" == *"-- <paths> && git push <remote> HEAD"* ]]
    else
        [[ "$output" == *"-- <paths>"* ]]
        [[ "$output" != *"git push"* ]]
    fi
}

@test "T-4738: update-task hint — key unset keeps the push clause and pushes" {
    _close_and_run 1
}

@test "T-4738: update-task hint — key 1 via fw config set keeps the push clause and pushes" {
    _set_key 1
    _close_and_run 1
}

@test "T-4738: update-task hint — key 0 via fw config set drops the push clause; nothing pushed" {
    _set_key 0
    _close_and_run 0
}

@test "T-4738: update-task hint — FW_CLOSE_HINT_PUSH=0 drops the push clause; nothing pushed" {
    export FW_CLOSE_HINT_PUSH=0
    _close_and_run 0
}

@test "T-4738: update-task hint — FW_CLOSE_HINT_PUSH=1 overrides a project 0" {
    _set_key 0
    export FW_CLOSE_HINT_PUSH=1
    _close_and_run 1
}

@test "T-4738: commit-shape hint — key unset keeps the push clause" {
    : > "$PROJECT_ROOT/.context/working/focus.yaml"
    _shape_hint 1
}

@test "T-4738: commit-shape hint — key 1 via fw config set keeps the push clause" {
    _set_key 1
    : > "$PROJECT_ROOT/.context/working/focus.yaml"
    _shape_hint 1
}

@test "T-4738: commit-shape hint — key 0 via fw config set drops the push clause" {
    _set_key 0
    : > "$PROJECT_ROOT/.context/working/focus.yaml"
    _shape_hint 0
}

@test "T-4738: commit-shape hint — FW_CLOSE_HINT_PUSH=0 drops the push clause" {
    : > "$PROJECT_ROOT/.context/working/focus.yaml"
    export FW_CLOSE_HINT_PUSH=0
    _shape_hint 0
}
