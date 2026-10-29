#!/usr/bin/env bats
# T-4266 — `fw init`'s bootstrap RECOVERY advice (empty-tree / commit-failed
# warnings) hard-coded `git commit -m "T-000: ..."`. The command is run later by
# an agent in a Claude Code session, where the focus-drift gate
# (agents/context/check-active-task.sh) refuses a commit naming any task other
# than the focused one — so following init's own advice was refused (greenfield
# F-30). The advice now names the session's focused task, read from the same
# focus file the hook reads ($CLAUDE_PROJECT_DIR), and T-000 only when nothing
# is focused. The gate itself is unchanged: no T-000 exemption.

setup() {
    export FW_TEST_SKIP_TASK_CONTEXT_GATE=1  # T-4907: this file tests another gate; its fixture tasks carry no ## Context
    FRAMEWORK_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    HOOK="$FRAMEWORK_ROOT/agents/context/check-active-task.sh"
    TEST_ROOT="$(mktemp -d)"
    mkdir -p "$TEST_ROOT/.context/working" "$TEST_ROOT/.tasks/active"
    echo "session_id: S-test" > "$TEST_ROOT/.context/working/session.yaml"
    echo "version: test" > "$TEST_ROOT/.framework.yaml"
    echo "completed: 2026-01-01T00:00:00Z" > "$TEST_ROOT/.context/working/.onboarding-complete"
    cat > "$TEST_ROOT/.tasks/active/T-1730-test.md" <<'MD'
---
id: T-1730
name: "test"
status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
---
# T-1730

## Acceptance Criteria
### Agent
- [ ] Real AC one
MD
    # shellcheck source=/dev/null
    source "$FRAMEWORK_ROOT/lib/init.sh"
}

teardown() {
    rm -rf "$TEST_ROOT" 2>/dev/null
}

set_focus() {
    cat > "$TEST_ROOT/.context/working/focus.yaml" <<YAML
current_task: $1
focus_session: S-test
YAML
}

run_hook() {
    local input
    input=$(python3 -c "import json,sys; print(json.dumps({'tool_name':'Bash','tool_input':{'command':sys.argv[1]}}))" "$1")
    PROJECT_ROOT="$TEST_ROOT" CLAUDECODE=1 run bash "$HOOK" <<< "$input"
}

@test "focus set: helper returns the focused task" {
    set_focus T-1730
    run env CLAUDE_PROJECT_DIR="$TEST_ROOT" bash -c "source '$FRAMEWORK_ROOT/lib/init.sh'; fw_init_bootstrap_task_ref"
    [ "$status" -eq 0 ]
    [ "$output" = "T-1730" ]
}

@test "no focus file: helper returns T-000" {
    run env CLAUDE_PROJECT_DIR="$TEST_ROOT" bash -c "source '$FRAMEWORK_ROOT/lib/init.sh'; fw_init_bootstrap_task_ref"
    [ "$output" = "T-000" ]
}

@test "null focus / no session dir: helper returns T-000" {
    set_focus null
    run env CLAUDE_PROJECT_DIR="$TEST_ROOT" bash -c "source '$FRAMEWORK_ROOT/lib/init.sh'; fw_init_bootstrap_task_ref"
    [ "$output" = "T-000" ]
    run env -u CLAUDE_PROJECT_DIR bash -c "source '$FRAMEWORK_ROOT/lib/init.sh'; fw_init_bootstrap_task_ref"
    [ "$output" = "T-000" ]
}

@test "focus set: the advised recovery commit passes the focus-drift gate" {
    set_focus T-1730
    ref=$(CLAUDE_PROJECT_DIR="$TEST_ROOT" fw_init_bootstrap_task_ref)
    run_hook "cd /some/project && git add -A && git commit -m \"$ref: bootstrap\""
    [ "$status" -eq 0 ]
    [[ "$output" != *"FOCUS-DRIFT"* ]] || false
}

@test "control: the old hard-coded T-000 advice IS refused with focus set (gate unchanged)" {
    set_focus T-1730
    run_hook 'cd /some/project && git add -A && git commit -m "T-000: bootstrap"'
    [ "$status" -eq 2 ]
    [[ "$output" == *"FOCUS-DRIFT"* ]]
}

@test "init.sh advice lines use the helper, not a literal T-000" {
    run grep -n 'git commit -m \\"T-000:' "$FRAMEWORK_ROOT/lib/init.sh"
    [ "$status" -eq 1 ]
    run grep -c 'fw_init_bootstrap_task_ref' "$FRAMEWORK_ROOT/lib/init.sh"
    [ "$output" -ge 3 ]
}
