#!/usr/bin/env bats
# T-4182 (832 OBS-375, their T-1150) — the closure commit of a just-completed task.
#
# `--status work-completed` moves T-B to .tasks/completed/ and its closure files
# (the moved task file, episodic) still need a commit. When focus already sits on
# another active task T-A, `git commit -m "T-B: …"` tripped the focus-drift gate,
# and for a completed target the block offered only options 2/3 — both Tier-2
# bypasses. T-2054 covers null focus, T-3179 covers work-completed focus; neither
# covers "focus elsewhere". The fix is a narrow exemption: a plain commit
# checkpoint whose target finished inside a grace window passes with a NOTE.
#
# The legs pair each allow with a block that differs in ONE property, so a hook
# that simply stopped gating would fail the block legs.

load ../test_helper
export FW_TEST_SKIP_TASK_CONTEXT_GATE=1  # T-4907: this file tests another gate; its fixture tasks carry no ## Context

HOOK="$FRAMEWORK_ROOT/agents/context/check-active-task.sh"

# $1 suffix, $2 date_finished value for the completed T-9002 (empty = field absent)
_sandbox() {
    local root="$BATS_TEST_TMPDIR/proj$1"
    mkdir -p "$root/.tasks/active" "$root/.tasks/completed" "$root/.context/working"
    printf -- '---\nid: T-9001\nname: "focused"\nstatus: started-work\n---\n' \
        > "$root/.tasks/active/T-9001-focused.md"
    printf -- '---\nid: T-9003\nname: "other active"\nstatus: started-work\n---\n' \
        > "$root/.tasks/active/T-9003-other.md"
    {
        printf -- '---\nid: T-9002\nname: "closed"\nstatus: work-completed\n'
        [ -n "$2" ] && printf 'date_finished: %s\n' "$2"
        printf -- '---\n'
    } > "$root/.tasks/completed/T-9002-closed.md"
    printf 'current_task: T-9001\n' > "$root/.context/working/focus.yaml"
    echo "$root"
}

_now()  { date -u +%Y-%m-%dT%H:%M:%SZ; }
_old()  { date -u -d '-1 day' +%Y-%m-%dT%H:%M:%SZ; }

_run_hook() {
    local root="$1" cmd="$2"
    # T-4409: `cwd` as Claude Code sends it; a bare git commit is judged from it.
    python3 -c "import json,sys; print(json.dumps({'tool_name':'Bash','cwd':sys.argv[2],'tool_input':{'command':sys.argv[1]}}))" "$cmd" "$root" \
    | CLAUDECODE=1 PROJECT_ROOT="$root" CONTEXT_DIR="$root/.context" TASKS_DIR="$root/.tasks" \
      bash "$HOOK" 2>&1
}

@test "T-4182: closure commit of a just-completed task passes with a NOTE" {
    local root; root=$(_sandbox a "$(_now)")
    run _run_hook "$root" 'git commit -m "T-9002: close" -- .tasks/completed/T-9002-closed.md'
    [ "$status" -eq 0 ]
    [[ "$output" == *"T-4182"* ]]
    [[ "$output" != *"FOCUS-DRIFT"* ]]
}

@test "T-4182: quoted date_finished form is honoured too" {
    local root; root=$(_sandbox q "'$(_now)'")
    run _run_hook "$root" 'git commit -m "T-9002: close"'
    [ "$status" -eq 0 ]
}

@test "T-4182: no bypass-log entry is written (not a Tier-2 bypass)" {
    local root; root=$(_sandbox l "$(_now)")
    run _run_hook "$root" 'git commit -m "T-9002: close"'
    [ "$status" -eq 0 ]
    [ ! -f "$root/.context/working/.gate-bypass-log.yaml" ]
}

@test "T-4182: completed long ago — still blocked" {
    local root; root=$(_sandbox b "$(_old)")
    run _run_hook "$root" 'git commit -m "T-9002: close"'
    [ "$status" -eq 2 ]
    [[ "$output" == *"FOCUS-DRIFT"* ]]
}

@test "T-4182: no date_finished — still blocked" {
    local root; root=$(_sandbox c "")
    run _run_hook "$root" 'git commit -m "T-9002: close"'
    [ "$status" -eq 2 ]
    [[ "$output" == *"FOCUS-DRIFT"* ]]
}

@test "T-4182: --no-verify voids the exemption" {
    local root; root=$(_sandbox d "$(_now)")
    run _run_hook "$root" 'git commit --no-verify -m "T-9002: close"'
    [ "$status" -eq 2 ]
}

@test "T-4182: a chained write voids the exemption" {
    local root; root=$(_sandbox e "$(_now)")
    run _run_hook "$root" 'git commit -m "T-9002: close"; rm -rf src'
    [ "$status" -eq 2 ]
}

@test "T-4182: non-commit drift to the just-completed task is still blocked" {
    local root; root=$(_sandbox f "$(_now)")
    run _run_hook "$root" 'bin/fw task update T-9002 --status issues'
    [ "$status" -eq 2 ]
    [[ "$output" == *"FOCUS-DRIFT"* ]]
}

@test "T-4182: active-target commit drift is unchanged (blocks, offers focus)" {
    local root; root=$(_sandbox g "$(_now)")
    run _run_hook "$root" 'git commit -m "T-9003: x"'
    [ "$status" -eq 2 ]
    [[ "$output" == *"context focus T-9003"* ]]
}

@test "T-4182: block for an old completed target names the grace-window remedy" {
    local root; root=$(_sandbox h "$(_old)")
    run _run_hook "$root" 'git commit -m "T-9002: close"'
    [ "$status" -eq 2 ]
    [[ "$output" == *"T-4182"* ]]
}
