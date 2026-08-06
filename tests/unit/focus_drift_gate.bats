#!/usr/bin/env bats
# T-1730: Focus-target drift gate — unit tests
#
# Closes G1 (Bash matcher gap) + G3 (focus-target drift uninspected) from
# T-1729 meta-RCA. Tests the Bash branch of agents/context/check-active-task.sh.
#
# Tests are isolated: each one creates a temporary PROJECT_ROOT with a
# .context/working/focus.yaml so we can simulate any focus state without
# polluting the real project.

setup() {
    FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-/opt/999-Agentic-Engineering-Framework}"
    HOOK="$FRAMEWORK_ROOT/agents/context/check-active-task.sh"
    [ -f "$HOOK" ] || skip "hook script not found"

    # Per-test isolated project root
    TEST_ROOT="$(mktemp -d)"
    mkdir -p "$TEST_ROOT/.context/working" "$TEST_ROOT/.tasks/active"
    # session.yaml satisfies the session-stamp gate (focus_session must match)
    echo "session_id: S-test" > "$TEST_ROOT/.context/working/session.yaml"
    # .framework.yaml so the gate doesn't bootstrap-bypass
    echo "version: test" > "$TEST_ROOT/.framework.yaml"
    # mark onboarding complete so onboarding gate doesn't fire
    echo "completed: 2026-01-01T00:00:00Z" > "$TEST_ROOT/.context/working/.onboarding-complete"

    export PROJECT_ROOT="$TEST_ROOT"
    export CLAUDECODE=1
}

teardown() {
    rm -rf "$TEST_ROOT" 2>/dev/null
}

# Helpers --------------------------------------------------------------

set_focus() {
    local task_id="$1"
    cat > "$TEST_ROOT/.context/working/focus.yaml" <<YAML
current_task: $task_id
focus_session: S-test
priorities: []
blockers: []
YAML
}

create_task() {
    local task_id="$1"
    local status="${2:-started-work}"
    cat > "$TEST_ROOT/.tasks/active/${task_id}-test.md" <<MD
---
id: $task_id
name: "test"
status: $status
workflow_type: build
owner: agent
horizon: now
tags: []
---
# $task_id

## Acceptance Criteria
### Agent
- [ ] Real AC one
- [ ] Real AC two
MD
}

run_hook_with_bash_cmd() {
    local cmd="$1"
    local input
    input=$(python3 -c "import json,sys; print(json.dumps({'tool_name':'Bash','tool_input':{'command':sys.argv[1]}}))" "$cmd")
    run bash "$HOOK" <<< "$input"
}

# Tests ----------------------------------------------------------------

@test "Bash drift: fw task update T-OTHER while focus=T-CURRENT — blocks under CLAUDECODE=1" {
    set_focus T-1730
    create_task T-1730
    create_task T-1716
    run_hook_with_bash_cmd "bin/fw task update T-1716 --add-tag drift-test"
    [ "$status" -eq 2 ]
    echo "$output" | grep -q "FOCUS-DRIFT"
    echo "$output" | grep -q "T-1730"
    echo "$output" | grep -q "T-1716"
}

@test "Bash drift: same task — passes" {
    set_focus T-1730
    create_task T-1730
    run_hook_with_bash_cmd "bin/fw task update T-1730 --add-tag self-test"
    [ "$status" -eq 0 ]
}

@test "Bash drift: --switch-focus override — passes and logs to gate-bypass log" {
    set_focus T-1730
    create_task T-1730
    create_task T-1716
    run_hook_with_bash_cmd "bin/fw task update T-1716 --add-tag x --switch-focus"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "focus-drift override"
    [ -f "$TEST_ROOT/.context/working/.gate-bypass-log.yaml" ]
    grep -q "switch-focus" "$TEST_ROOT/.context/working/.gate-bypass-log.yaml"
    grep -q "T-1716" "$TEST_ROOT/.context/working/.gate-bypass-log.yaml"
}

@test "Bash drift: git commit -m T-OTHER while focus=T-CURRENT — blocks" {
    set_focus T-1730
    create_task T-1730
    run_hook_with_bash_cmd 'git commit -m "T-1716: cherry-pick fix"'
    [ "$status" -eq 2 ]
    echo "$output" | grep -q "FOCUS-DRIFT"
}

@test "Bash drift: git commit -m T-CURRENT — passes" {
    set_focus T-1730
    create_task T-1730
    run_hook_with_bash_cmd 'git commit -m "T-1730: legitimate work"'
    [ "$status" -eq 0 ]
}

@test "Bash drift: fw context add-learning --task T-OTHER — blocks" {
    set_focus T-1730
    create_task T-1730
    create_task T-1716
    run_hook_with_bash_cmd 'bin/fw context add-learning "x" --task T-1716'
    [ "$status" -eq 2 ]
    echo "$output" | grep -q "FOCUS-DRIFT"
    echo "$output" | grep -q "T-1716"
}

@test "Bash drift: fw context add-learning --task T-CURRENT — passes" {
    set_focus T-1730
    create_task T-1730
    run_hook_with_bash_cmd 'bin/fw context add-learning "x" --task T-1730'
    [ "$status" -eq 0 ]
}

@test "Bash drift: fw work-on T-OTHER — passes (legitimate focus switch)" {
    set_focus T-1730
    create_task T-1730
    create_task T-1716
    # fw work-on is in the safe-command allowlist — exits 0 BEFORE reaching drift check
    run_hook_with_bash_cmd "bin/fw work-on T-1716"
    [ "$status" -eq 0 ]
}

@test "Bash drift: fw context focus T-OTHER — passes (legitimate focus switch)" {
    set_focus T-1730
    create_task T-1730
    create_task T-1716
    run_hook_with_bash_cmd "bin/fw context focus T-1716"
    [ "$status" -eq 0 ]
}

@test "Bash drift: fw task review T-OTHER — passes (read-only / human handoff)" {
    set_focus T-1730
    create_task T-1730
    create_task T-1716
    run_hook_with_bash_cmd "bin/fw task review T-1716"
    [ "$status" -eq 0 ]
}

@test "Bash drift: no agent-control signal — advisory only, does not block" {
    set_focus T-1730
    create_task T-1730
    create_task T-1716
    # T-1739: multi-signal agent-control check now considers AI_AGENT too.
    # Unset both to drop into advisory-only mode.
    unset CLAUDECODE
    unset AI_AGENT
    run_hook_with_bash_cmd "bin/fw task update T-1716 --add-tag x"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "focus-drift detected"
}

@test "Bash drift: AI_AGENT set but CLAUDECODE empty — blocks (T-1739 multi-signal)" {
    set_focus T-1730
    create_task T-1730
    create_task T-1716
    unset CLAUDECODE
    export AI_AGENT="claude-code/2.1.126/agent"
    run_hook_with_bash_cmd "bin/fw task update T-1716 --add-tag x"
    [ "$status" -eq 2 ]
    echo "$output" | grep -q "FOCUS-DRIFT"
}

@test "Bash drift: bare bash with no T-X target — passes (no drift to detect)" {
    set_focus T-1730
    create_task T-1730
    run_hook_with_bash_cmd "echo hello"
    [ "$status" -eq 0 ]
}

@test "Bash drift: no focus set — does not crash, does not block on drift" {
    # No set_focus call — focus.yaml absent
    create_task T-1730
    run_hook_with_bash_cmd "bin/fw task update T-1716 --add-tag x"
    # Will block on "no active task" rather than focus-drift; check it didn't crash
    [ "$status" -eq 2 ]
    # Should NOT mention focus-drift since drift logic only fires when CURRENT_TASK is set
    ! echo "$output" | grep -q "FOCUS-DRIFT"
}

# Pin tests for settings.json wiring -----------------------------------

@test "settings.json: check-active-task matcher includes Bash (post-fix wiring pin)" {
    grep -q '"matcher": "Write|Edit|Bash"' "$FRAMEWORK_ROOT/.claude/settings.json"
    # Confirm it's the check-active-task block by checking nearby line
    python3 -c "
import json
data = json.load(open('$FRAMEWORK_ROOT/.claude/settings.json'))
for h in data['hooks']['PreToolUse']:
    for inner in h.get('hooks', []):
        if 'check-active-task' in inner.get('command', ''):
            assert 'Bash' in h['matcher'], f'check-active-task matcher missing Bash: {h[\"matcher\"]}'
            print('OK')
            break
"
}

@test "T-1858: null current_task + non-empty focus_session — emits 'No active task' (not session ID as task)" {
    # The bug: when focus.yaml has current_task: null + focus_session: <S-id>,
    # the python helper used to emit one space-separated line, which IFS-collapsed
    # in `read -r CURRENT_TASK FOCUS_SESSION`, shifting the session ID into the
    # task slot and producing the misleading "Task <S-id> is not active" message.
    cat > "$TEST_ROOT/.context/working/focus.yaml" <<YAML
current_task: null
focus_session: S-FAKE-SESSION-XYZ
priorities: []
YAML
    run_hook_with_bash_cmd "termlink inbox status"
    [ "$status" -eq 2 ]
    # Correct branch: "No active task"
    echo "$output" | grep -q "No active task"
    # Session ID MUST NOT appear as a task in the error
    ! echo "$output" | grep -q "Task S-FAKE-SESSION-XYZ is not active"
    ! echo "$output" | grep -q "S-FAKE-SESSION-XYZ is not active"
}

@test "T-1858: normal case — current_task=T-X + focus_session=S-test reads both correctly (no regression)" {
    set_focus T-1730
    create_task T-1730
    # No drift target in command — should allow (focus is set, task exists, status started-work)
    run_hook_with_bash_cmd "termlink inbox status"
    [ "$status" -eq 0 ]
}

# T-2833: Pattern 3 target-extraction regressions --------------------------
# Prior form was two independent regexes ANDed ("git commit" present anywhere
# AND a "T-N:" pattern present anywhere), so the extracted id needed not
# belong to the commit's own -m/--message value. Fixed by anchoring
# extraction to the flag's value. Both directions pinned below.

@test "T-2833: false negative fixed — prose naming focus ahead of a commit targeting a different task now blocks" {
    # Pre-fix: leftmost 'T-1730:' (in the echo prose) was read as the target,
    # which equals the focused task, so drift went undetected (fail-open) even
    # though the real -m value targets T-1716.
    set_focus T-1730
    create_task T-1730
    create_task T-1716
    run_hook_with_bash_cmd 'echo "See T-1730: prior context" && git commit -m "T-1716: actual fix"'
    [ "$status" -eq 2 ]
    echo "$output" | grep -q "FOCUS-DRIFT"
    echo "$output" | grep -q "T-1716"
}

@test "T-2833: false positive fixed — a grep pattern mentioning another task id no longer supplies TARGET_TASK" {
    # Pre-fix: leftmost 'T-1716:' (inside the grep pattern argument) was read
    # as the target even though the real commit's -m value targets the
    # focused task T-1730 — wrongly blocked.
    set_focus T-1730
    create_task T-1730
    run_hook_with_bash_cmd 'grep -rn "T-1716:" docs/ && git commit -m "T-1730: fix docs"'
    [ "$status" -eq 0 ]
}

@test "T-2833: true drift still blocked — -am combined flag" {
    set_focus T-1730
    create_task T-1730
    create_task T-1716
    run_hook_with_bash_cmd 'git commit -am "T-1716: cherry-pick fix"'
    [ "$status" -eq 2 ]
    echo "$output" | grep -q "FOCUS-DRIFT"
}

@test "T-2833: true drift still blocked — --message= long flag" {
    set_focus T-1730
    create_task T-1730
    create_task T-1716
    run_hook_with_bash_cmd 'git commit --message="T-1716: cherry-pick fix"'
    [ "$status" -eq 2 ]
    echo "$output" | grep -q "FOCUS-DRIFT"
}

@test "lib/init.sh: settings generator emits Bash in check-active-task matcher (source-of-truth)" {
    # Source-of-truth check: any future fw upgrade must propagate the fix
    python3 -c "
import re
src = open('$FRAMEWORK_ROOT/lib/init.sh').read()
# Find the check-active-task block in the JSON template
m = re.search(r'\"matcher\":\s*\"([^\"]+)\"\s*,\s*\"hooks\":\s*\[\s*\{\s*\"type\":\s*\"command\",\s*\"command\":\s*\"\\\$fw_prefix hook check-active-task\"', src)
assert m, 'check-active-task block not found in lib/init.sh template'
matcher = m.group(1)
assert 'Bash' in matcher, f'lib/init.sh matcher missing Bash: {matcher}'
print(f'OK: {matcher}')
"
}
