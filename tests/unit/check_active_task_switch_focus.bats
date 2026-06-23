#!/usr/bin/env bats
# T-1890: focus-drift bypass mechanism contract.
#
# The check-active-task.sh PreToolUse hook (T-1730) detects when a Bash
# command targets a task ≠ the focused task and blocks under agent control.
# Two bypass mechanisms exist:
#   (a) --switch-focus flag in the command (for fw commands whose downstream
#       parsers consume the no-op token);
#   (b) FW_SWITCH_FOCUS=1 env-var prefix (universal — works for git commit
#       and any external tool that rejects unknown flags).
#
# This test pins the contract end-to-end: the hook recognises both
# mechanisms, logs each with its own `flag:` field, and the downstream
# consumer (update-task.sh) accepts --switch-focus without
# "Unknown option" exit.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    export CLAUDECODE=1  # Required for the hook to enforce (vs advisory)
    mkdir -p "$TEST_TEMP_DIR/.context/working" "$TEST_TEMP_DIR/.tasks/active"
    echo "framework_root: $FRAMEWORK_ROOT" > "$TEST_TEMP_DIR/.framework.yaml"

    # Focused task: T-1100. Active in .tasks/active/ with started-work status.
    cat > "$TEST_TEMP_DIR/.tasks/active/T-1100-focused.md" <<'EOF'
---
id: T-1100
status: started-work
---
# T-1100
EOF
    cat > "$TEST_TEMP_DIR/.context/working/focus.yaml" <<'EOF'
current_task: T-1100
focus_session: S-test-001
EOF

    # Target task in drift scenarios: T-1200. Also active.
    cat > "$TEST_TEMP_DIR/.tasks/active/T-1200-target.md" <<'EOF'
---
id: T-1200
status: started-work
---
# T-1200
EOF

    HOOK="$FRAMEWORK_ROOT/agents/context/check-active-task.sh"
    BYPASS_LOG="$TEST_TEMP_DIR/.context/working/.gate-bypass-log.yaml"
}

teardown() {
    rm -rf "$TEST_TEMP_DIR"
}

_run_hook_bash() {
    local cmd="$1"
    local json
    json=$(python3 -c "import json,sys; print(json.dumps({'tool_name':'Bash','tool_input':{'command': sys.argv[1]}}))" "$cmd")
    echo "$json" | bash "$HOOK"
}

@test "focus-drift: blocks fw task update on different task without bypass" {
    run _run_hook_bash "bin/fw task update T-1200 --status started-work"
    [ "$status" -eq 2 ]
    [[ "$output" =~ "FOCUS-DRIFT" ]] || [[ "${stderr:-}" =~ "FOCUS-DRIFT" ]]
}

@test "focus-drift: --switch-focus flag allows + logs" {
    run _run_hook_bash "bin/fw task update T-1200 --status started-work --switch-focus"
    [ "$status" -eq 0 ]
    [ -f "$BYPASS_LOG" ]
    grep -q "flag: '--switch-focus'" "$BYPASS_LOG"
    grep -q "target: 'T-1200'" "$BYPASS_LOG"
}

@test "focus-drift: FW_SWITCH_FOCUS=1 env-var prefix allows + logs (universal mechanism)" {
    run _run_hook_bash "FW_SWITCH_FOCUS=1 bin/fw task update T-1200 --status started-work"
    [ "$status" -eq 0 ]
    [ -f "$BYPASS_LOG" ]
    grep -q "flag: 'FW_SWITCH_FOCUS=1'" "$BYPASS_LOG"
    grep -q "target: 'T-1200'" "$BYPASS_LOG"
}

@test "focus-drift: FW_SWITCH_FOCUS=1 works for git commit (where --switch-focus flag cannot)" {
    # git rejects unknown flags, so the flag mechanism fundamentally can't
    # cover the git commit pattern. The env-var prefix path is the only
    # bypass mechanism that works universally.
    run _run_hook_bash "FW_SWITCH_FOCUS=1 git commit -m 'T-1200: drift commit'"
    [ "$status" -eq 0 ]
    [ -f "$BYPASS_LOG" ]
    grep -q "flag: 'FW_SWITCH_FOCUS=1'" "$BYPASS_LOG"
}

@test "block message names both bypass mechanisms" {
    run _run_hook_bash "bin/fw task update T-1200 --status started-work"
    [ "$status" -eq 2 ]
    # Combined stdout+stderr per BATS run convention
    [[ "$output" =~ "--switch-focus" ]]
    [[ "$output" =~ "FW_SWITCH_FOCUS=1" ]]
}

@test "downstream consumer: update-task.sh accepts --switch-focus without Unknown option" {
    # The --switch-focus token must not abort the option parser. Exercise
    # --help path so we don't depend on a real task being mutated.
    run bash "$FRAMEWORK_ROOT/agents/task-create/update-task.sh" --switch-focus --help
    [ "$status" -eq 0 ]
    ! [[ "$output" =~ "Unknown option" ]]
}

@test "downstream consumer: learning.sh accepts --switch-focus without Unknown option" {
    # Invoke with the switch-focus token but ALSO a missing learning text so
    # the script fails at validation, not at the option parser. The bug we're
    # guarding against is "Unknown option: --switch-focus" — a different exit
    # path than "Learning text required".
    run bash "$FRAMEWORK_ROOT/agents/context/lib/learning.sh" --task T-1100 --switch-focus
    # We don't care about the exit status — only that --switch-focus did not
    # trigger the Unknown-option branch.
    ! [[ "$output" =~ "Unknown option: --switch-focus" ]]
}

@test "downstream consumer: pattern.sh accepts --switch-focus without Unknown option" {
    run bash "$FRAMEWORK_ROOT/agents/context/lib/pattern.sh" --task T-1100 --switch-focus
    ! [[ "$output" =~ "Unknown option: --switch-focus" ]]
}

@test "downstream consumer: decision.sh accepts --switch-focus without Unknown option" {
    run bash "$FRAMEWORK_ROOT/agents/context/lib/decision.sh" --task T-1100 --switch-focus
    ! [[ "$output" =~ "Unknown option: --switch-focus" ]]
}
