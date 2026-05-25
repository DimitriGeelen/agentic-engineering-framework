#!/usr/bin/env bats
# T-2054 — post-completion commit deadlock: `git commit` must be allowed when
# focus is null, WITHOUT breaking the focus-drift gate (T-1730) when focus exists.
#
# Why the deadlock: `fw task update --status work-completed` nulls focus.yaml AND
# moves the task active/→completed/. The completion's own file-move + episodic
# must still be committed, but the no-active-task gate blocked git commit — and
# the just-completed task can't be re-focused (G-013). Deadlock.
#
# Why NOT a context-free allowlist entry: putting `git commit` in
# is_bash_safe_command would short-circuit check-active-task.sh BEFORE the
# focus-drift gate, so `git commit -m "T-OTHER:"` under focus=T-CURRENT would
# silently bypass T-1730. Instead the null-focus allow lives in
# check-active-task.sh and is focus-aware. This file tests the GATE end-to-end.
#
# Contract pinned:
#   - null focus    + git commit            → allowed (exit 0)   [deadlock closed]
#   - null focus    + git add               → allowed (exit 0)   [task-agnostic]
#   - null focus    + git commit --no-verify→ blocked (exit 2)   [preserves P-002]
#   - null focus    + git commit -n         → blocked (exit 2)
#   - focus=T-A     + git commit T-B:       → blocked (exit 2)   [focus-drift kept]
#   - focus=T-A     + git commit T-A:       → allowed (exit 0)
#   - is_bash_safe_command("git add")       → 0  (unit level)
#   - is_bash_safe_command("git commit")    → 1  (unit level — gate-handled)

setup() {
    FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-/opt/999-Agentic-Engineering-Framework}"
    HOOK="$FRAMEWORK_ROOT/agents/context/check-active-task.sh"
    [ -f "$HOOK" ] || skip "hook script not found"

    TEST_ROOT="$(mktemp -d)"
    mkdir -p "$TEST_ROOT/.context/working" "$TEST_ROOT/.tasks/active"
    echo "session_id: S-test" > "$TEST_ROOT/.context/working/session.yaml"
    echo "version: test" > "$TEST_ROOT/.framework.yaml"
    echo "completed: 2026-01-01T00:00:00Z" > "$TEST_ROOT/.context/working/.onboarding-complete"

    export PROJECT_ROOT="$TEST_ROOT"
    export CLAUDECODE=1
}

teardown() {
    rm -rf "$TEST_ROOT" 2>/dev/null
}

# --- helpers (mirrors focus_drift_gate.bats) ---

set_null_focus() {
    cat > "$TEST_ROOT/.context/working/focus.yaml" <<'YAML'
current_task: null
focus_session: S-test
priorities: []
YAML
}

set_focus() {
    cat > "$TEST_ROOT/.context/working/focus.yaml" <<YAML
current_task: $1
focus_session: S-test
priorities: []
YAML
}

create_task() {
    cat > "$TEST_ROOT/.tasks/active/${1}-test.md" <<MD
---
id: $1
name: "test"
status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
---
# $1
## Acceptance Criteria
### Agent
- [ ] Real AC one
- [ ] Real AC two
MD
}

run_hook() {
    local input
    input=$(python3 -c "import json,sys; print(json.dumps({'tool_name':'Bash','tool_input':{'command':sys.argv[1]}}))" "$1")
    run bash "$HOOK" <<< "$input"
}

# --- deadlock fix: null focus allows the completion checkpoint ---

@test "T-2054: null focus — git commit is allowed (deadlock closed)" {
    set_null_focus
    run_hook 'git commit -m "T-2053: work-completed metadata + episodic"'
    [ "$status" -eq 0 ]
}

@test "T-2054: null focus — git add is allowed" {
    set_null_focus
    run_hook 'git add -- .tasks/completed/T-2053-x.md'
    [ "$status" -eq 0 ]
}

@test "T-2054: null focus — git commit --no-verify is BLOCKED (preserves P-002)" {
    set_null_focus
    run_hook 'git commit --no-verify -m "T-2053: x"'
    [ "$status" -eq 2 ]
    echo "$output" | grep -q "No active task"
}

@test "T-2054: null focus — git commit -n (short no-verify) is BLOCKED" {
    set_null_focus
    run_hook 'git commit -n -m "T-2053: x"'
    [ "$status" -eq 2 ]
}

@test "T-2054: null focus — an unrelated write is still BLOCKED" {
    set_null_focus
    run_hook 'git push origin master'
    [ "$status" -eq 2 ]
    echo "$output" | grep -q "No active task"
}

# --- focus-drift gate (T-1730) must remain intact when focus IS set ---

@test "T-2054: focus=T-A — git commit T-B: still BLOCKS (focus-drift preserved)" {
    set_focus T-2054
    create_task T-2054
    run_hook 'git commit -m "T-1716: cherry-pick fix"'
    [ "$status" -eq 2 ]
    echo "$output" | grep -q "FOCUS-DRIFT"
}

@test "T-2054: focus=T-A — git commit T-A: passes" {
    set_focus T-2054
    create_task T-2054
    run_hook 'git commit -m "T-2054: legitimate work"'
    [ "$status" -eq 0 ]
}

# --- unit level: is_bash_safe_command classification ---

@test "T-2054: is_bash_safe_command — git add is safe" {
    source "$FRAMEWORK_ROOT/agents/context/lib/safe-commands.sh"
    run is_bash_safe_command "git add -A"
    [ "$status" -eq 0 ]
}

@test "T-2054: is_bash_safe_command — git commit is NOT safe (gate-handled)" {
    source "$FRAMEWORK_ROOT/agents/context/lib/safe-commands.sh"
    run is_bash_safe_command "git commit -m 'x'"
    [ "$status" -eq 1 ]
}
