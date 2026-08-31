#!/usr/bin/env bats
# T-2463 (OBS-080) — the check-active-task gate must resolve PROJECT_ROOT from the
# per-call `cwd` Claude Code passes on stdin, NOT from the hook's process cwd.
#
# Why: in a git-worktree session the gate runs as <main>/bin/fw hook, and with
# CLAUDE_PROJECT_DIR unset bin/fw resolves PROJECT_ROOT from the hook's process
# cwd (the main launch dir). So the gate read MAIN's focus.yaml while the tool
# actually ran in the worktree — worktree work blocked "No active task" whenever
# main focus was null (confirmed live 2026-06-23). The fix re-anchors PROJECT_ROOT
# + path vars to the project root that stdin `cwd` resolves to.
#
# Contract pinned (PROJECT_ROOT env simulates bin/fw resolving to the MAIN repo):
#   cwd=WTFIX  + WTFIX focus=active   → allowed (exit 0)  [re-anchored to worktree]
#   cwd=WTFIX  + WTFIX focus=null     → blocked (exit 2)  [reads worktree focus]
#   no cwd     + MAINFIX focus=null   → blocked (exit 2)  [regression: old behavior]
#   cwd=MAINFIX(==PROJECT_ROOT) active → allowed (exit 0) [no-op re-anchor]

setup() {
    # Hermetic: derive FRAMEWORK_ROOT from this test file's own location (L-490).
    FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-$(cd "$BATS_TEST_DIRNAME/../.." && pwd)}"
    HOOK="$FRAMEWORK_ROOT/agents/context/check-active-task.sh"
    [ -f "$HOOK" ] || skip "hook script not found"

    MAINFIX="$(mktemp -d)"
    WTFIX="$(mktemp -d)"
    _init_root "$MAINFIX"
    _init_root "$WTFIX"

    # Simulate bin/fw having resolved PROJECT_ROOT to the MAIN repo (the bug's
    # starting condition); the re-anchor must override this from stdin cwd.
    export PROJECT_ROOT="$MAINFIX"
    export CLAUDECODE=1
}

teardown() {
    rm -rf "$MAINFIX" "$WTFIX" 2>/dev/null
}

_init_root() {
    local r="$1"
    mkdir -p "$r/.context/working" "$r/.tasks/active"
    echo "session_id: S-test" > "$r/.context/working/session.yaml"
    echo "version: test" > "$r/.framework.yaml"
    echo "completed: 2026-01-01T00:00:00Z" > "$r/.context/working/.onboarding-complete"
}

set_focus_in() {  # $1=root  $2=task-id-or-null
    cat > "$1/.context/working/focus.yaml" <<YAML
current_task: $2
focus_session: S-test
priorities: []
YAML
}

create_task_in() {  # $1=root  $2=id
    cat > "$1/.tasks/active/${2}-test.md" <<MD
---
id: $2
name: "test"
status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
---
# $2
## Acceptance Criteria
### Agent
- [ ] Real AC one
- [ ] Real AC two
MD
}

# $1 = command, $2 = cwd ("" → omit the cwd key entirely, i.e. legacy stdin shape)
run_hook() {
    local input
    input=$(python3 -c "
import json, sys
payload = {'tool_name': 'Bash', 'tool_input': {'command': sys.argv[1]}}
if sys.argv[2]:
    payload['cwd'] = sys.argv[2]
print(json.dumps(payload))
" "$1" "$2")
    run bash "$HOOK" <<< "$input"
}

@test "T-2463: cwd=worktree with active worktree focus → allowed (re-anchored)" {
    set_focus_in "$MAINFIX" null            # main focus null (the normal state)
    set_focus_in "$WTFIX" T-9001
    create_task_in "$WTFIX" T-9001
    run_hook 'true && echo work' "$WTFIX"
    [ "$status" -eq 0 ]
}

@test "T-2463: cwd=worktree with null worktree focus → blocked (reads worktree focus)" {
    set_focus_in "$MAINFIX" T-8001          # main focus set — must NOT rescue it
    create_task_in "$MAINFIX" T-8001
    set_focus_in "$WTFIX" null
    run_hook 'true && echo work' "$WTFIX"
    [ "$status" -eq 2 ]
    echo "$output" | grep -q "No active task"
}

@test "T-2463: no cwd on stdin → falls back to PROJECT_ROOT (regression, old behavior)" {
    set_focus_in "$MAINFIX" null
    run_hook 'true && echo work' ""
    [ "$status" -eq 2 ]
    echo "$output" | grep -q "No active task"
}

@test "T-2463: cwd == PROJECT_ROOT → no-op re-anchor, uses that root's focus" {
    set_focus_in "$MAINFIX" T-7001
    create_task_in "$MAINFIX" T-7001
    run_hook 'true && echo work' "$MAINFIX"
    [ "$status" -eq 0 ]
}

@test "T-2463: cwd outside any project → no re-anchor, uses PROJECT_ROOT" {
    set_focus_in "$MAINFIX" T-6001
    create_task_in "$MAINFIX" T-6001
    # PREMISE: /tmp has no .framework.yaml/.tasks above it within the walk → no
    # override. That premise is HOST STATE, not something this file controls, and
    # it has been false on this host before: an `fw init` ran with cwd=/tmp on
    # 2026-08-31, /tmp became a project, and this leg went red reading exactly
    # like a code regression (OBS-358, T-3234). If it is red, run
    # tests/lint/no-project-markers-above-bats-tmpdir.bats first — that guard
    # names the offending directory and says whether the host or the code moved.
    run_hook 'true && echo work' "/tmp"
    [ "$status" -eq 0 ]
}
