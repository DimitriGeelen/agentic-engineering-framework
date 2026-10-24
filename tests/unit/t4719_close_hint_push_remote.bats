#!/usr/bin/env bats
# T-4719 (TermLink be.14, sidecar 9c448cb6): the close hint ended in a bare
# `&& git push`, which fails on a branch with no upstream ("has no upstream
# branch"). The hint now prints `git push <remote> HEAD`, where <remote> is the
# branch's upstream remote, else the only remote, else `origin` among several,
# else the first; with no remote the push clause is left out.
#
# End to end: a real close through update-task.sh in a throwaway project, the
# printed line extracted verbatim and run, and the bare remote checked.

load ../test_helper
load ../git_fence

HOOK="$FRAMEWORK_ROOT/agents/context/check-active-task.sh"

setup() {
    unset FW_SESSION_SCOPED_FOCUS FW_FOCUS_SESSION_KEY
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    export PROJECT_ROOT="$TEST_TEMP_DIR/proj"
    guard_project_root
    mkdir -p "$PROJECT_ROOT/.tasks/active" "$PROJECT_ROOT/.tasks/completed" \
             "$PROJECT_ROOT/.context/working" "$PROJECT_ROOT/.context/episodic"
    git -C "$PROJECT_ROOT" init -q -b main
    git -C "$PROJECT_ROOT" config user.email "test@test"
    git -C "$PROJECT_ROOT" config user.name "test"
    cat > "$PROJECT_ROOT/.tasks/active/T-9471-fixture.md" <<'EOF'
---
id: T-9471
name: "fixture"
status: started-work
workflow_type: build
owner: claude-code
horizon: now
tags: []
created: 2026-06-01T00:00:00Z
last_update: 2026-06-01T00:00:00Z
---

# T-9471: fixture

## Acceptance Criteria

### Agent
- [x] Done

## Verification
# verification: none — fixture for the T-4719 close-hint push test
EOF
    : > "$PROJECT_ROOT/README"
    git -C "$PROJECT_ROOT" add README .tasks/active/T-9471-fixture.md
    git -C "$PROJECT_ROOT" commit -qm "T-9471: init"
    printf 'current_task: T-9471\n' > "$PROJECT_ROOT/.context/working/focus.yaml"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

_bare() {
    git init -q --bare "$TEST_TEMP_DIR/$1.git"
    git -C "$PROJECT_ROOT" remote add "$1" "$TEST_TEMP_DIR/$1.git"
}

_close() {
    env PROJECT_ROOT="$PROJECT_ROOT" FRAMEWORK_ROOT="$FRAMEWORK_ROOT" \
        bash "$FRAMEWORK_ROOT/agents/task-create/update-task.sh" T-9471 \
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

# Close, run the printed hint verbatim, and assert it landed on $1 (remote) at
# refs/heads/$2 (branch). Also asserts the hint passes the null-focus task gate.
_close_and_push_to() {
    local remote="$1" branch="$2" out cmd
    out=$(_close)
    cmd=$(_hint "$out")
    echo "hint: $cmd"
    [ -n "$cmd" ]
    [[ "$cmd" == *"&& git push $remote HEAD" ]]
    run _run_hook "$cmd"
    echo "$output"
    [ "$status" -eq 0 ]
    run bash -c "cd '$PROJECT_ROOT' && $cmd"
    echo "$output"
    [ "$status" -eq 0 ]
    git -C "$PROJECT_ROOT" ls-tree --name-only HEAD -- .tasks/completed/T-9471-fixture.md | grep -q T-9471
    [ "$(git -C "$PROJECT_ROOT" rev-parse HEAD)" = "$(git -C "$TEST_TEMP_DIR/$remote.git" rev-parse "refs/heads/$branch")" ]
}

@test "T-4719: upstream set — push goes to the upstream remote, not origin" {
    _bare origin
    _bare up
    git -C "$PROJECT_ROOT" checkout -q -b feature
    git -C "$PROJECT_ROOT" push -q -u up feature 2>/dev/null
    _close_and_push_to up feature
}

@test "T-4719: no upstream, one remote — push goes to that remote (and a bare push would have failed)" {
    _bare mirror
    run git -C "$PROJECT_ROOT" push -q
    [ "$status" -ne 0 ]
    _close_and_push_to mirror main
}

@test "T-4719: no upstream, several remotes — origin is chosen when present" {
    _bare alpha
    _bare origin
    _close_and_push_to origin main
}

@test "T-4719: no upstream, several remotes without origin — the first in git remote order" {
    _bare zeta
    _bare beta
    local first
    first=$(git -C "$PROJECT_ROOT" remote | head -1)
    _close_and_push_to "$first" main
}

@test "T-4719: no remote — the push clause is left out and the commit still runs verbatim" {
    local out cmd
    out=$(_close)
    cmd=$(_hint "$out")
    echo "hint: $cmd"
    [ -n "$cmd" ]
    [[ "$cmd" != *"git push"* ]]
    run bash -c "cd '$PROJECT_ROOT' && $cmd"
    echo "$output"
    [ "$status" -eq 0 ]
    git -C "$PROJECT_ROOT" ls-tree --name-only HEAD -- .tasks/completed/T-9471-fixture.md | grep -q T-9471
}
