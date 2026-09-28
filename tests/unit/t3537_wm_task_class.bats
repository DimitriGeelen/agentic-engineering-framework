#!/usr/bin/env bats
# T-3537: the workflow-management (WM) task class, exercised through the REAL
# PreToolUse hook rather than through its predicate.
#
# WHY END-TO-END AND NOT UNIT
#
# Twice in one day this repo shipped a guard that no live path reached: one keyed
# on MERGE_HEAD during pre-merge-commit, where MERGE_HEAD does not exist; one
# sitting behind a gate that refused agents before the guard ran. Both had
# passing tests. L-573 is the lesson — *a gate can be green, tested, and
# structurally unreachable at the same time* — and the only defence is driving
# the path an agent actually takes. So every test here pipes real JSON into
# check-active-task.sh and asserts on its exit code.
#
# THE NEGATIVE CONTROLS ARE THE POINT
#
# The safety property is not "WM focus lets housekeeping through" — that is the
# easy half. It is "WM focus still refuses source writes". A standing task is a
# standing exemption unless fenced, so a suite that only proves things pass
# cannot tell a correct fence from one that permits everything. That is exactly
# the shape of OBS-560, where 34 green tests shipped a false green.

setup() {
    FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-$(cd "$BATS_TEST_DIRNAME/../.." && pwd)}"
    HOOK="$FRAMEWORK_ROOT/agents/context/check-active-task.sh"
    [ -f "$HOOK" ] || skip "hook script not found"

    FIX="$(mktemp -d)"
    mkdir -p "$FIX/.context/working" "$FIX/.tasks/active" "$FIX/.tasks/workflow"
    echo "session_id: S-test" > "$FIX/.context/working/session.yaml"
    echo "version: test" > "$FIX/.framework.yaml"
    echo "completed: 2026-01-01T00:00:00Z" > "$FIX/.context/working/.onboarding-complete"

    # Ship the real WM task files into the fixture — the gate requires the file
    # to exist, so copying them also asserts they are present in the repo.
    cp "$FRAMEWORK_ROOT"/.tasks/workflow/WM-*.md "$FIX/.tasks/workflow/"

    export PROJECT_ROOT="$FIX"
    export CLAUDECODE=1
}

teardown() { rm -rf "$FIX" 2>/dev/null; }

set_focus() {
    cat > "$FIX/.context/working/focus.yaml" <<YAML
current_task: $1
focus_session: S-test
priorities: []
YAML
}

create_task() {
    cat > "$FIX/.tasks/active/${1}-test.md" <<MD
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
- [ ] A real acceptance criterion with substance
- [ ] A second real acceptance criterion
MD
}

run_write() {   # $1 = absolute file path
    local input
    input=$(python3 -c "
import json,sys
print(json.dumps({'tool_name':'Write','tool_input':{'file_path':sys.argv[1],'content':'x'},'cwd':sys.argv[2]}))
" "$1" "$FIX")
    run bash "$HOOK" <<< "$input"
}

run_bash() {    # $1 = command
    local input
    input=$(python3 -c "
import json,sys
print(json.dumps({'tool_name':'Bash','tool_input':{'command':sys.argv[1]},'cwd':sys.argv[2]}))
" "$1" "$FIX")
    run bash "$HOOK" <<< "$input"
}

# ── the dead end this exists to close (OBS-250) ───────────────────────────────

@test "t3537: null focus still blocks — the rule is intact" {
    set_focus null
    run_bash 'bin/fw some-unlisted-verb'
    [ "$status" -eq 2 ]
    echo "$output" | grep -q "No active task"
}

@test "t3537: the null-focus block now NAMES the WM route out" {
    set_focus null
    run_bash 'bin/fw some-unlisted-verb'
    echo "$output" | grep -q "WM-001"
    echo "$output" | grep -q "WM-002"
}

@test "t3537: WM-001 focus satisfies the task gate for an otherwise-blocked command" {
    set_focus WM-001
    run_bash 'bin/fw some-unlisted-verb'
    [ "$status" -eq 0 ]
}

@test "t3537: WM-002 focus permits a .context/ write (close-out records there)" {
    set_focus WM-002
    run_write "$FIX/.context/working/scratch.yaml"
    [ "$status" -eq 0 ]
}

@test "t3537: WM-003 focus permits a .tasks/ write" {
    set_focus WM-003
    run_write "$FIX/.tasks/active/T-9001-test.md"
    [ "$status" -eq 0 ]
}

# ── THE FENCE — the negative controls that carry the safety property ──────────

@test "t3537 CONTROL: WM-001 focus REFUSES a source write" {
    set_focus WM-001
    run_write "$FIX/lib/some_source.py"
    [ "$status" -eq 2 ]
    echo "$output" | grep -q "cannot write source"
}

@test "t3537 CONTROL: WM-002 focus REFUSES a source write" {
    set_focus WM-002
    run_write "$FIX/agents/foo/bar.sh"
    [ "$status" -eq 2 ]
}

@test "t3537 CONTROL: WM-003 focus REFUSES a source write" {
    set_focus WM-003
    run_write "$FIX/web/app.py"
    [ "$status" -eq 2 ]
}

@test "t3537 CONTROL: the fence message names how to get a real task" {
    set_focus WM-001
    run_write "$FIX/lib/some_source.py"
    echo "$output" | grep -q "work-on"
}

@test "t3537 CONTROL: an invented WM id cannot mint itself a standing exemption" {
    set_focus WM-742
    run_bash 'bin/fw some-unlisted-verb'
    [ "$status" -eq 2 ]
    echo "$output" | grep -q "not a workflow-management task"
}

@test "t3537 CONTROL: a WM id whose file is absent is refused" {
    set_focus WM-003
    rm -f "$FIX/.tasks/workflow/WM-003-"*.md
    run_bash 'bin/fw some-unlisted-verb'
    [ "$status" -eq 2 ]
}

# ── nothing already working is narrowed ───────────────────────────────────────

@test "t3537: a normal T- task CAN still write source (no regression)" {
    set_focus T-9001
    create_task T-9001
    run_write "$FIX/lib/some_source.py"
    [ "$status" -eq 0 ]
}

@test "t3537: a normal T- task is unaffected by the WM branch on Bash" {
    set_focus T-9001
    create_task T-9001
    run_bash 'bin/fw doctor'
    [ "$status" -eq 0 ]
}
