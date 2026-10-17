#!/usr/bin/env bats
# T-4281: under WM focus, the no-source-writes fence refused Write/Edit to the
# harness scratchpad (/tmp/claude-<uid>/<project>/<session>/scratchpad/*). That
# path is outside the repo and is not source, so the fence must let it through,
# while still refusing real source and still allowing .context/ housekeeping.
#
# Driven through the real PreToolUse hook (same harness as t3537), not through
# fw_wm_write_allowed alone, so the assertion is on the path an agent takes.

setup() {
    FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-$(cd "$BATS_TEST_DIRNAME/../.." && pwd)}"
    HOOK="$FRAMEWORK_ROOT/agents/context/check-active-task.sh"
    [ -f "$HOOK" ] || skip "hook script not found"

    FIX="$(mktemp -d)"
    mkdir -p "$FIX/.context/working" "$FIX/.tasks/active" "$FIX/.tasks/workflow"
    echo "session_id: S-test" > "$FIX/.context/working/session.yaml"
    echo "version: test" > "$FIX/.framework.yaml"
    echo "completed: 2026-01-01T00:00:00Z" > "$FIX/.context/working/.onboarding-complete"
    cp "$FRAMEWORK_ROOT"/.tasks/workflow/WM-*.md "$FIX/.tasks/workflow/"

    cat > "$FIX/.context/working/focus.yaml" <<YAML
current_task: WM-001
focus_session: S-test
priorities: []
YAML

    export PROJECT_ROOT="$FIX"
    export CLAUDECODE=1
    SCRATCH="/tmp/claude-$(id -u)/t4281-proj/sess-1/scratchpad"
}

teardown() { rm -rf "$FIX" 2>/dev/null; }

run_write() {   # $1 = absolute file path
    local input
    input=$(python3 -c "
import json,sys
print(json.dumps({'tool_name':'Write','tool_input':{'file_path':sys.argv[1],'content':'x'},'cwd':sys.argv[2]}))
" "$1" "$FIX")
    run bash "$HOOK" <<< "$input"
}

@test "T-4281: WM focus + scratchpad write passes (outside the repo, not source)" {
    run_write "$SCRATCH/selection.py"
    [ "$status" -eq 0 ]
}

@test "T-4281: WM focus + scratchpad markdown write passes" {
    run_write "$SCRATCH/worker-prompt.md"
    [ "$status" -eq 0 ]
}

@test "T-4281: WM focus + lib/x.sh write is still blocked (source stays fenced)" {
    run_write "$FIX/lib/x.sh"
    [ "$status" -eq 2 ]
    [[ "$output" == *"cannot write source"* ]]
}

@test "T-4281: WM focus + .context/working write still passes" {
    run_write "$FIX/.context/working/x.yaml"
    [ "$status" -eq 0 ]
}

@test "T-4281: WM focus + scratchpad path traversing back into the repo is still blocked" {
    run_write "$SCRATCH/../../../../../${FIX#/}/lib/x.sh"
    [ "$status" -eq 2 ]
}
