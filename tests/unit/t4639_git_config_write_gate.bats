#!/usr/bin/env bats
# T-4639: check-active-task.sh exempted all of PROJECT_ROOT/.git/* from the
# Write/Edit task gate. .git/config, .git/info/attributes and .git/hooks/* are
# executable configuration: a write there can set diff.<x>.command, textconv,
# core.fsmonitor, core.pager or core.hooksPath, which a later allowlisted
# "read-only" git diff/status/log then runs. After the fix those paths need a
# task, and a write the gate allows is flagged (stderr WARNING + bypass-log row)
# when it newly sets an exec-capable key. Other .git/* paths stay exempt.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    mkdir -p "$TEST_TEMP_DIR/.context/working" "$TEST_TEMP_DIR/.tasks/active" \
             "$TEST_TEMP_DIR/.tasks/completed" "$TEST_TEMP_DIR/.git/info" "$TEST_TEMP_DIR/.git/hooks"
    echo "framework_root: $FRAMEWORK_ROOT" > "$TEST_TEMP_DIR/.framework.yaml"
    printf '[core]\n\trepositoryformatversion = 0\n\tbare = false\n' > "$TEST_TEMP_DIR/.git/config"
    cat > "$TEST_TEMP_DIR/.tasks/active/T-9001-focused.md" <<'EOF'
---
id: T-9001
name: focused
status: started-work
workflow_type: build
owner: agent
---
# T-9001

## Acceptance Criteria

### Agent
- [ ] The git config edit lands and parses
EOF
    HOOK="$FRAMEWORK_ROOT/agents/context/check-active-task.sh"
    BYPASS_LOG="$TEST_TEMP_DIR/.context/working/.gate-bypass-log.yaml"
    export CLAUDECODE=1
}

teardown() {
    rm -rf "$TEST_TEMP_DIR"
}

_no_task() { printf 'current_task: null\n' > "$TEST_TEMP_DIR/.context/working/focus.yaml"; }
_task()    { printf 'current_task: T-9001\n' > "$TEST_TEMP_DIR/.context/working/focus.yaml"; }

_write_json() {
    python3 -c "import json,sys; print(json.dumps({'tool_name':'Write','tool_input':{'file_path':sys.argv[1],'content':sys.argv[2]}}))" "$1" "$2"
}

_append_config() {
    # $1 = config text to append after the existing [core] block
    _write_json "$TEST_TEMP_DIR/.git/config" "$(cat "$TEST_TEMP_DIR/.git/config")
$1"
}

_run_hook() { echo "$1" | bash "$HOOK"; }

# ── no task: refused ──────────────────────────────────────────────────────────

@test "no task: Write .git/config is refused" {
    _no_task
    run _run_hook "$(_append_config '[core]
	fsmonitor = /tmp/x.sh')"
    [ "$status" -eq 2 ]
}

@test "no task: Edit .git/config is refused" {
    _no_task
    json=$(python3 -c "import json,sys; print(json.dumps({'tool_name':'Edit','tool_input':{'file_path':sys.argv[1],'old_string':'bare = false','new_string':'bare = false\n\tpager = /tmp/x.sh'}}))" "$TEST_TEMP_DIR/.git/config")
    run _run_hook "$json"
    [ "$status" -eq 2 ]
}

@test "no task: .git/info/attributes is refused" {
    _no_task
    run _run_hook "$(_write_json "$TEST_TEMP_DIR/.git/info/attributes" '* diff=evil')"
    [ "$status" -eq 2 ]
}

@test "no task: .git/hooks/pre-commit is refused" {
    _no_task
    run _run_hook "$(_write_json "$TEST_TEMP_DIR/.git/hooks/pre-commit" '#!/bin/sh')"
    [ "$status" -eq 2 ]
}

@test "no task: .git/config.worktree and worktrees/*/config.worktree are refused" {
    _no_task
    run _run_hook "$(_write_json "$TEST_TEMP_DIR/.git/config.worktree" '[core]')"
    [ "$status" -eq 2 ]
    run _run_hook "$(_write_json "$TEST_TEMP_DIR/.git/worktrees/w1/config.worktree" '[core]')"
    [ "$status" -eq 2 ]
}

@test "no task: non-normalised spellings of .git/config are refused" {
    _no_task
    run _run_hook "$(_write_json "$TEST_TEMP_DIR/.git//config" '[core]')"
    [ "$status" -eq 2 ]
    run _run_hook "$(_write_json "$TEST_TEMP_DIR/.git/hooks/../config" '[core]')"
    [ "$status" -eq 2 ]
    run _run_hook "$(_write_json "$TEST_TEMP_DIR/.git/./info/attributes" '* diff=x')"
    [ "$status" -eq 2 ]
}

@test "no task: other .git paths stay exempt (COMMIT_EDITMSG, info/exclude)" {
    _no_task
    run _run_hook "$(_write_json "$TEST_TEMP_DIR/.git/COMMIT_EDITMSG" 'T-9001: msg')"
    [ "$status" -eq 0 ]
    run _run_hook "$(_write_json "$TEST_TEMP_DIR/.git/info/exclude" 'scratch/')"
    [ "$status" -eq 0 ]
}

# ── with task: allowed, exec-capable keys flagged ────────────────────────────

_assert_flagged() {
    # $1 = expected substring of the flagged key
    [ "$status" -eq 0 ]
    [[ "$output" == *"WARNING (T-4639)"* ]]
    [[ "$output" == *"$1"* ]]
    grep -q "git-exec-config" "$BYPASS_LOG"
    grep -q "T-9001" "$BYPASS_LOG"
}

@test "task: diff.<x>.command is flagged" {
    _task
    run _run_hook "$(_append_config '[diff "evil"]
	command = /tmp/x.sh')"
    _assert_flagged "diff.evil.command"
}

@test "task: diff.<x>.textconv is flagged" {
    _task
    run _run_hook "$(_append_config '[diff "evil"]
	textconv = /tmp/x.sh')"
    _assert_flagged "diff.evil.textconv"
}

@test "task: core.fsmonitor is flagged" {
    _task
    run _run_hook "$(_append_config '[core]
	fsmonitor = /tmp/x.sh')"
    _assert_flagged "core.fsmonitor"
}

@test "task: core.pager is flagged" {
    _task
    run _run_hook "$(_append_config '[core]
	pager = /tmp/x.sh')"
    _assert_flagged "core.pager"
}

@test "task: core.hooksPath is flagged" {
    _task
    run _run_hook "$(_append_config '[core]
	hooksPath = /tmp/hooks')"
    _assert_flagged "core.hookspath"
}

@test "task: include.path is flagged" {
    _task
    run _run_hook "$(_append_config '[include]
	path = /tmp/other.gitconfig')"
    _assert_flagged "include.path"
}

@test "task: Edit adding core.fsmonitor is flagged" {
    _task
    json=$(python3 -c "import json,sys; print(json.dumps({'tool_name':'Edit','tool_input':{'file_path':sys.argv[1],'old_string':'bare = false','new_string':'bare = false\n\tfsmonitor = /tmp/x.sh'}}))" "$TEST_TEMP_DIR/.git/config")
    run _run_hook "$json"
    _assert_flagged "core.fsmonitor"
}

@test "task: info/attributes driver selection is flagged" {
    _task
    run _run_hook "$(_write_json "$TEST_TEMP_DIR/.git/info/attributes" '*.txt diff=evil')"
    _assert_flagged "diff=evil"
}

@test "task: .git/hooks/* write is flagged" {
    _task
    run _run_hook "$(_write_json "$TEST_TEMP_DIR/.git/hooks/pre-commit" '#!/bin/sh')"
    _assert_flagged "pre-commit"
}

@test "task: benign .git/config edit passes with no flag" {
    _task
    run _run_hook "$(_append_config '[user]
	name = Someone')"
    [ "$status" -eq 0 ]
    [[ "$output" != *"WARNING (T-4639)"* ]]
    [ ! -f "$BYPASS_LOG" ] || ! grep -q "git-exec-config" "$BYPASS_LOG" || false
}

@test "task: a key already present is not re-flagged" {
    printf '[core]\n\tpager = less\n' > "$TEST_TEMP_DIR/.git/config"
    _task
    run _run_hook "$(_append_config '[user]
	name = Someone')"
    [ "$status" -eq 0 ]
    [[ "$output" != *"WARNING (T-4639)"* ]]
}

# ── WM fence mirrors the gate ────────────────────────────────────────────────

@test "WM fence refuses executable git config, keeps other .git paths" {
    source "$FRAMEWORK_ROOT/lib/wm_tasks.sh"
    ! fw_wm_write_allowed "$TEST_TEMP_DIR/.git/config" "$TEST_TEMP_DIR" || false
    ! fw_wm_write_allowed "$TEST_TEMP_DIR/.git/info/attributes" "$TEST_TEMP_DIR" || false
    ! fw_wm_write_allowed "$TEST_TEMP_DIR/.git/hooks/pre-commit" "$TEST_TEMP_DIR" || false
    ! fw_wm_write_allowed "$TEST_TEMP_DIR/.git//config" "$TEST_TEMP_DIR" || false
    fw_wm_write_allowed "$TEST_TEMP_DIR/.git/COMMIT_EDITMSG" "$TEST_TEMP_DIR"
}
